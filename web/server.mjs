import http from 'node:http';
import {createPlanner} from './planner.mjs';
import {backupDatabase} from './backup.mjs';
import {DatabaseSync} from 'node:sqlite';
import {randomBytes,scryptSync,timingSafeEqual} from 'node:crypto';
import {mkdirSync,readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname,join} from 'node:path';
import {validateDocument,applyAction} from './state.mjs';
import {fetchNews} from './news.mjs';
const ROOT=dirname(fileURLToPath(import.meta.url));
export function createAboLifeServer({password,dbPath=':memory:',publicURL=null,newsFetcher=fetchNews,planner=createPlanner(),backupDirectory=null}={}) {
 if(typeof password!=='string'||password.length<16)throw new Error('ABOLIFE_PASSWORD muss mindestens 16 Zeichen haben.');
 const salt=randomBytes(32),hash=scryptSync(password,salt,32),db=new DatabaseSync(dbPath);
 db.exec('PRAGMA journal_mode=WAL; CREATE TABLE IF NOT EXISTS state(id INTEGER PRIMARY KEY CHECK(id=1),revision INTEGER NOT NULL,payload TEXT); CREATE TABLE IF NOT EXISTS history(revision INTEGER PRIMARY KEY,payload TEXT,created_at TEXT NOT NULL); CREATE TABLE IF NOT EXISTS action_receipts(id TEXT PRIMARY KEY,created_at TEXT NOT NULL); CREATE TABLE IF NOT EXISTS cache(id TEXT PRIMARY KEY,payload TEXT NOT NULL); INSERT OR IGNORE INTO state(id,revision,payload) VALUES(1,0,NULL);');
 const sessions=new Map(),attempts=new Map();let newsPromise=null,planningIssues=[],disposed=false;
 function state(){const row=db.prepare('SELECT revision,payload FROM state WHERE id=1').get();return {revision:row.revision,document:row.payload?JSON.parse(row.payload):null,plannerAvailable:!!planner,planningIssues};}
 function save(revision,document,requestID=null){
  validateDocument(document);db.exec('BEGIN IMMEDIATE');
  try{
   const current=state();if(current.revision!==revision){db.exec('ROLLBACK');return null;}
   if(current.document)db.prepare('INSERT OR REPLACE INTO history VALUES(?,?,?)').run(current.revision,JSON.stringify(current.document),new Date().toISOString());
   db.prepare('UPDATE state SET revision=?,payload=? WHERE id=1').run(revision+1,JSON.stringify(document));
   if(requestID)db.prepare('INSERT INTO action_receipts VALUES(?,?)').run(requestID,new Date().toISOString());
   db.exec('DELETE FROM history WHERE revision NOT IN (SELECT revision FROM history ORDER BY revision DESC LIMIT 50); COMMIT');return {revision:revision+1,document,plannerAvailable:!!planner,planningIssues};
  }catch(e){if(db.isTransaction)db.exec('ROLLBACK');throw e;}
 }
 async function plan(document){
  if(!planner||!document)return document;
  validateDocument(document);
  const result=await planner(document.calendar);
  planningIssues=[...(result.issues??[]),...Object.values(result.unplaced??{})];
  return validateDocument({...document,calendar:result.calendar});
 }
 const files={'/':['index.html','text/html; charset=utf-8'],'/sw.js':['sw.js','text/javascript; charset=utf-8'],'/app.js':['app.js','text/javascript; charset=utf-8'],'/style.css':['style.css','text/css; charset=utf-8'],'/icon.png':['icon.png','image/png'],'/manifest.webmanifest':['manifest.webmanifest','application/manifest+json']};
 const server=http.createServer(async(req,res)=>{
  const json=(status,data)=>{res.writeHead(status,{'Content-Type':'application/json; charset=utf-8'});res.end(JSON.stringify(data));};
  res.setHeader('Cache-Control','no-store');res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Referrer-Policy','no-referrer');res.setHeader('X-Frame-Options','DENY');
  res.setHeader('Content-Security-Policy',"default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'");
  if(req.url==='/healthz'&&req.method==='GET'&&['127.0.0.1','::1','::ffff:127.0.0.1'].includes(req.socket.remoteAddress))return json(200,{ok:true});
  const expected=publicURL?new URL(publicURL):null;
  if(expected?req.headers.host!==expected.host:!/^((127\.0\.0\.1|localhost)(:\d+)?|\[::1\](:\d+)?)$/.test(req.headers.host??''))return json(403,{error:'Nicht erlaubter Host. ABOLIFE_PUBLIC_URL konfigurieren.'});
  const url=new URL(req.url,'http://localhost');
  const origin=expected?.origin??`http://${req.headers.host}`;
  if(req.headers.origin&&req.headers.origin!==origin)return json(403,{error:'Fremde Herkunft abgelehnt.'});
  const unsafe=!['GET','HEAD'].includes(req.method);
  if(unsafe&&!req.headers.authorization&&req.headers['x-abolife-request']!=='1')return json(403,{error:'Anfrage abgelehnt.'});
  const secure=expected?.protocol==='https:'||req.socket.encrypted;
  if(secure)res.setHeader('Strict-Transport-Security','max-age=31536000');
  async function body(){
   if(!(req.headers['content-type']??'').startsWith('application/json'))throw new Error('JSON erforderlich.');
   let size=0;const parts=[];for await(const part of req){size+=part.length;if(size>8_000_000)throw new Error('Anfrage zu groß.');parts.push(part);}return JSON.parse(Buffer.concat(parts).toString());
  }
  try {
   const now=Date.now();for(const [key,s] of sessions)if(s<now)sessions.delete(key);for(const [key,a]of attempts)if(a.until<now)attempts.delete(key);
   if(url.pathname==='/api/login'&&req.method==='POST'){
    const key=req.socket.remoteAddress??'local';const a=attempts.get(key)??{count:0,until:now+600000};if(a.count>=8)return json(429,{error:'Zu viele Versuche. Bitte später erneut anmelden.'});
    const value=await body();if(typeof value.password!=='string'||value.password.length>1024)return json(400,{error:'Ungültiges Passwort.'});
    const candidate=scryptSync(value.password,salt,32);
    if(!timingSafeEqual(candidate,hash)){a.count++;attempts.set(key,a);return json(401,{error:'Anmeldung fehlgeschlagen.'});}
    attempts.delete(key);if(sessions.size>10000)sessions.clear();const token=randomBytes(32).toString('base64url');sessions.set(token,now+7*86400000);
    res.setHeader('Set-Cookie',`abolife_session=${token}; Path=/; HttpOnly; SameSite=Strict; Max-Age=604800${secure?'; Secure':''}`);return json(200,{token});
   }
   if(url.pathname.startsWith('/api/')){
    const token=req.headers.authorization?.match(/^Bearer (.+)$/)?.[1]??req.headers.cookie?.match(/(?:^|;\s*)abolife_session=([^;]+)/)?.[1];
    if(!token||!sessions.has(token))return json(401,{error:'Bitte anmelden.'});
    if(url.pathname==='/api/logout'&&req.method==='POST'){sessions.delete(token);res.setHeader('Set-Cookie','abolife_session=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0');return json(200,{ok:true});}
    if(url.pathname==='/api/state'&&req.method==='GET')return json(200,{...state(),plannerAvailable:!!planner});
    if(url.pathname==='/api/replan'&&req.method==='POST'){
     const input=await body(),current=state();if(input.revision!==current.revision)return json(409,{error:'Daten wurden inzwischen geändert. Bitte neu laden.'});
     if(!planner||!current.document)return json(200,{...current,plannerAvailable:!!planner});
     const document=await plan(current.document);const saved=save(current.revision,document);return json(saved?200:409,saved?{...saved,plannerAvailable:true}:{error:'Versionskonflikt.'});
    }
    if(url.pathname==='/api/state'&&req.method==='PUT'){
     const input=await body();if(!Number.isSafeInteger(input.revision))return json(400,{error:'Version fehlt.'});
     const saved=save(input.revision,await plan(input.document));return json(saved?200:409,saved??{error:'Der Datenstand wurde inzwischen geändert. Bitte neu laden.'});
    }
    if(url.pathname==='/api/action'&&req.method==='POST'){
     const input=await body(),current=state();
     if(input.requestID!=null&&!/^[a-zA-Z0-9-]{16,100}$/.test(input.requestID))return json(400,{error:'Ungültige Anfragekennung.'});
     if(input.requestID&&db.prepare('SELECT id FROM action_receipts WHERE id=?').get(input.requestID))return json(200,current);
     if(input.revision!==current.revision)return json(409,{error:'Der Datenstand wurde inzwischen geändert. Deine Eingabe ist noch nicht gespeichert. Bitte neu laden und prüfen.'});
     let document=applyAction(current.document,input.action);if(['event','review'].includes(input.action.kind))document=await plan(document);const saved=save(input.revision,document,input.requestID);return json(saved?200:409,saved??{error:'Versionskonflikt.'});
    }
    if(url.pathname==='/api/history'&&req.method==='GET')return json(200,{versions:db.prepare('SELECT revision,created_at FROM history ORDER BY revision DESC').all()});
    if(url.pathname==='/api/export'&&req.method==='GET'){res.setHeader('Content-Disposition','attachment; filename="AboLife-Shared.json"');return json(200,state());}
    if(url.pathname==='/api/history/restore'&&req.method==='POST'){
     const input=await body();if(input.confirm!==true)return json(400,{error:'Bestätigung fehlt.'});
     const row=db.prepare('SELECT payload FROM history WHERE revision=?').get(input.restoreRevision);if(!row)return json(404,{error:'Version nicht gefunden.'});
     const saved=save(input.revision,JSON.parse(row.payload));return json(saved?200:409,saved??{error:'Versionskonflikt.'});
    }
    if(url.pathname==='/api/news'&&req.method==='GET'){
     const cached=db.prepare("SELECT payload FROM cache WHERE id='news'").get();const old=cached?JSON.parse(cached.payload):null;
     if(old&&Date.now()-Date.parse(old.updatedAt)<1800000)return json(200,old);
     newsPromise??=newsFetcher().then(result=>{
      if(!result.articles.length&&result.failed.length&&old)return {...old,failed:result.failed,stale:true};
      if(result.failed.length&&old)result.articles=[...result.articles,...old.articles.filter(a=>result.failed.includes(a.source))];
      db.prepare("INSERT INTO cache VALUES('news',?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload").run(JSON.stringify(result));return result;
     }).finally(()=>{newsPromise=null;});
     return json(200,await newsPromise);
    }
    return json(404,{error:'Nicht gefunden.'});
   }
   if(req.method==='GET'&&files[url.pathname]){const [file,type]=files[url.pathname];res.setHeader('Content-Type',type);res.end(readFileSync(join(ROOT,'public',file)));return;}
   json(404,{error:'Nicht gefunden.'});
  } catch(error) { if(!res.headersSent)json(400,{error:error.message==='Unexpected end of JSON input'?'Ungültige Anfrage.':error.message});else res.end(); }
 });
 let planning=false;
 function canonical(value,key=''){
  if(Array.isArray(value)){const entries=value.map(v=>canonical(v));if(entries.every(v=>v&&typeof v==='object'&&typeof v.id==='string'))entries.sort((a,b)=>a.id.localeCompare(b.id));else if(['weekdays','learningLocations','repeatWeekdays','excludedDays'].includes(key))entries.sort();return entries;}
  if(value&&typeof value==='object')return Object.fromEntries(Object.keys(value).sort().map(k=>[k,canonical(value[k],k)]));return value;
 }
 const planningTimer=planner?setInterval(async()=>{
  if(planning||disposed)return;planning=true;
  try{const current=state();if(current.document){const document=await plan(current.document);if(!disposed&&JSON.stringify(canonical(document))!==JSON.stringify(canonical(current.document)))save(current.revision,document);}}
  catch{console.warn('AboLife: periodische Lernplanung fehlgeschlagen; gespeicherte Daten bleiben erhalten.');}
  finally{planning=false;}
 },15*60000):null;
 planningTimer?.unref();
 let backingUp=false;
 const backupTimer=backupDirectory?setInterval(async()=>{
  if(backingUp||disposed)return;backingUp=true;
  try{await backupDatabase(db,backupDirectory);}catch{console.warn('AboLife: automatische Sicherung fehlgeschlagen. Datenvolume prüfen.');}finally{backingUp=false;}
 },24*60*60000):null;
 backupTimer?.unref();
 server.on('close',()=>{disposed=true;clearInterval(planningTimer);clearInterval(backupTimer);db.close();});return server;
}
if(process.argv[1]&&fileURLToPath(import.meta.url)===process.argv[1]){
 const folder=process.env.ABOLIFE_DATA_DIR??join(ROOT,'data');mkdirSync(folder,{recursive:true});
 const server=createAboLifeServer({password:process.env.ABOLIFE_PASSWORD,dbPath:join(folder,'AboLife-Shared.sqlite'),publicURL:process.env.ABOLIFE_PUBLIC_URL??null,backupDirectory:join(folder,'backups')});
 server.listen(Number(process.env.PORT??3055),process.env.ABOLIFE_HOST??'127.0.0.1',()=>console.log('AboLife Web läuft auf Port '+(process.env.PORT??3055)+'.'));
 for(const signal of ['SIGTERM','SIGINT'])process.on(signal,()=>server.close());
}
