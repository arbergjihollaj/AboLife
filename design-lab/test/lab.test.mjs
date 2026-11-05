import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,readFile,rm} from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import vm from 'node:vm';
import {Readable} from 'node:stream';
import {createLabServer,validateFeedback,feedbackMarkdown} from '../server.mjs';
import {concepts,screens,initialDemo,escapeHTML} from '../public/data.js';
const source=file=>readFile(new URL('../'+file,import.meta.url),'utf8');
async function fixture(t){const dir=await mkdtemp(path.join(os.tmpdir(),'abolife-design-lab-'));t.after(()=>rm(dir,{recursive:true,force:true}));return {dataDir:path.join(dir,'data'),reportPath:path.join(dir,'DESIGN_FEEDBACK.md')};}
function request(server,{url='/api/feedback',method='GET',body='',origin='http://127.0.0.1:4177',contentType='application/json'}={}){
 return new Promise(resolve=>{
  const req=Readable.from(body?[Buffer.from(body)]:[]);Object.assign(req,{url,method,headers:{host:'127.0.0.1:4177',origin,'content-type':contentType}});
  const res={writeHead(status,headers){this.status=status;this.headers=headers;},end(body){resolve({status:this.status,headers:this.headers,body:Buffer.isBuffer(body)?body.toString():body});}};
  server.emit('request',req,res);
 });
}
test('feedback persists across server instances, including favorites and all text fields',async t=>{
 const config=await fixture(t),server=createLabServer(config);
 assert.equal((await request(server)).status,200);
 const data=validateFeedback({a:{score:8,likes:'Ruhe',dislikes:'Zu leer',keep:'Navigation',ideas:'Mehr Kontrast',favorites:['Navigation','Dashboard'],aspects:{Navigation:9}}});
 assert.equal((await request(server,{method:'PUT',body:JSON.stringify(data)})).status,200);
 const loaded=JSON.parse((await request(createLabServer(config))).body);
 assert.deepEqual(loaded,data);
 const report=await readFile(config.reportPath,'utf8');
 assert.match(report,/Ruhe/);assert.match(report,/Navigation: 9/);assert.match(report,/Favoriten: Navigation, Dashboard/);
});
test('invalid scores, malformed payloads and cross-origin writes cannot change feedback',async t=>{
 const config=await fixture(t),server=createLabServer(config);
 for(const body of ['{','null','[]',JSON.stringify({a:{score:11}}),JSON.stringify({a:{favorites:['unknown']}}),JSON.stringify({b:{likes:'x'.repeat(12001)}})])assert.equal((await request(server,{method:'PUT',body})).status,400);
 assert.equal((await request(server,{method:'PUT',body:'{}',origin:'https://other.example'})).status,403);
 assert.equal((await request(server,{method:'PUT',body:'{}',contentType:'text/plain'})).status,403);
 assert.equal((await request(server,{method:'POST'})).status,405);
 assert.equal(JSON.parse((await request(server)).body).a.score,null);
});
test('concurrent saves serialize and markdown follows the final saved snapshot',async t=>{
 const config=await fixture(t),server=createLabServer(config);
 const first=validateFeedback({a:{score:2}}),last=validateFeedback({a:{score:9,likes:'Finaler Stand'}});
 const results=await Promise.all([request(server,{method:'PUT',body:JSON.stringify(first)}),request(server,{method:'PUT',body:JSON.stringify(last)})]);
 assert.ok(results.every(x=>x.status===200));
 assert.equal(JSON.parse((await request(server)).body).a.score,9);
 assert.match(await readFile(config.reportPath,'utf8'),/Finaler Stand/);
});
test('static app serves all source assets and denies feedback files and directory traversal',async t=>{
 const server=createLabServer(await fixture(t));
 for(const url of ['/','/lab.js','/prototype.html','/prototype.js','/prototype.css','/lab.css','/data.js','/responsive.css','/personal.css','/preferences.js',...'abcde'.split('').flatMap(id=>[`/concepts/${id}.js`,`/concepts/${id}.css`])]){
  const res=await request(server,{url});assert.equal(res.status,200,url);assert.match(res.headers['Content-Security-Policy'],/default-src 'self'/);
 }
 for(const url of ['/server.mjs','/.local/feedback.json','/%2e%2e%2fserver.mjs','/missing.js'])assert.equal((await request(server,{url})).status,404,url);
});
test('unreadable feedback fails visibly rather than overwriting it with an empty state',async t=>{
 const config=await fixture(t);const {mkdir,writeFile}=await import('node:fs/promises');await mkdir(config.dataDir);await writeFile(path.join(config.dataDir,'feedback.json'),'{broken');
 assert.equal((await request(createLabServer(config))).status,500);
});
async function prototypeContext(design,storage=new Map()){
 const root={innerHTML:'',addEventListener(type,fn){this[type]=fn;}};
 const dialog={innerHTML:'',open:false,classList:{add(){},remove(){}},addEventListener(type,fn){this[type]=fn;},showModal(){this.open=true;},close(){this.open=false;}};
 const toast={textContent:'',classList:{add(){},remove(){}}};
 const handlers={},winHandlers={};
 const bodyClasses=new Set();
 const document={title:'',body:{dataset:{},style:{setProperty(){},removeProperty(){}},classList:{add(x){bodyClasses.add(x)},contains(x){return bodyClasses.has(x)},toggle(x,on){on?bodyClasses.add(x):bodyClasses.delete(x)}}},querySelector(sel){return {'#prototype':root,'#entry-dialog':dialog,'#toast':toast,'.app-content':{scrollTop:0}}[sel]},addEventListener(type,fn){handlers[type]=fn;}};
 const context=vm.createContext({document,localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)},URLSearchParams,location:{search:`?design=${design}`,origin:'http://localhost'},window:{addEventListener(type,fn){winHandlers[type]=fn;}},setTimeout(){return 1},clearTimeout(){},FormData:class{constructor(form){return new Map(Object.entries(form.values))}}});
 await vm.runInContext((await source('public/data.js')).replaceAll('export ','')+'\nconst h=escapeHTML;\n'+(await source('public/preferences.js')).replaceAll('export ','')+'\n'+(await Promise.all('abcde'.split('').map(id=>source(`public/concepts/${id}.js`)))).join('\n').replaceAll('export ','')+'\n'+(await source('public/prototype.js')).replace(/^import .*;\n/gm,''),context);
 return {context,root,dialog,toast,handlers,winHandlers,click(action){root.click({target:{closest(){return {dataset:{action}}}}})}};
}
test('all six concepts render all ten screens with their own navigation structures',async()=>{
 const shells=['native-sidebar','spatial-dock','swiss-index','bento-rail','journal-masthead','spatial-dock'];
 for(const [i,c] of concepts.entries()){
  const {root,winHandlers}=await prototypeContext(c.id);
  assert.match(root.innerHTML,new RegExp(shells[i]));
  for(const [screen,title] of screens){winHandlers.message({origin:'http://localhost',data:{type:'screen',screen}});assert.ok(root.innerHTML.includes(title)||screen==='dashboard',`${c.id}/${screen}`);assert.match(root.innerHTML,/FIKTIVE BEISPIELDATEN/);}
 }
});
test('demo mutations update budget, training, habits and reset without accessing production data',async()=>{
 const {context,root,click,handlers,winHandlers}=await prototypeContext('a');
 click('water');assert.equal(vm.runInContext('data.water',context),2);
 click('workout');assert.equal(vm.runInContext('data.trained',context),true);
 handlers.submit({target:{id:'entry-form',dataset:{kind:'expense'},values:{title:'Test <script>',amount:'7.50',category:'Alltag'}},preventDefault(){}});
 assert.equal(vm.runInContext('spent()',context),43.9);
 winHandlers.message({origin:'http://localhost',data:{type:'screen',screen:'finance'}});
 assert.match(root.innerHTML,/Test &lt;script&gt;/);assert.match(root.innerHTML,/256,10/);
 winHandlers.message({origin:'http://localhost',data:{type:'reset'}});
 assert.equal(vm.runInContext('data.trained',context),false);assert.equal(vm.runInContext('data.water',context),1.75);
});
test('review drafts survive navigation and news filters support bookmarks',async()=>{
 const {context,root,handlers,winHandlers,click}=await prototypeContext('e');
 root.input({target:{name:'wins',value:'Draft survives',closest(){return true}}});
 winHandlers.message({origin:'http://localhost',data:{type:'screen',screen:'finance'}});
 winHandlers.message({origin:'http://localhost',data:{type:'screen',screen:'review'}});
 assert.match(root.innerHTML,/Draft survives/);
 click('bookmark-1');assert.equal(vm.runInContext('data.bookmarks[0]',context),1);
});
test('offline gallery embeds six real prototypes, comparison and persisted feedback',async()=>{
 const html=await source('UI-Design-Lab.html');assert.match(html,/window.LAB_OFFLINE=true/);assert.match(html,/window.LAB_PROTOTYPE=/);
 const app={innerHTML:'',addEventListener(){}},storage=new Map();
 const context=vm.createContext({document:{querySelector:s=>s==='#app'?app:null,querySelectorAll:()=>[]},window:{LAB_OFFLINE:true,LAB_PROTOTYPE:'<html>__LAB_PARAMS__</html>',addEventListener(){}},location:{hash:'',origin:'null'},localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)},setTimeout(){},clearTimeout(){},console});
 const code=(await source('public/data.js')).replaceAll('export ','')+'\nconst h=escapeHTML;\n'+(await source('public/lab.js')).replace(/^import .*;\n/,'');
 vm.runInContext(code,context);await new Promise(r=>setImmediate(r));
 for(const c of concepts)assert.ok(app.innerHTML.includes(c.name));
 assert.equal((app.innerHTML.match(/srcdoc=/g)||[]).length,6);
 vm.runInContext("tab='compare';selected=['a','b','c','d','e'];render()",context);
 assert.equal((app.innerHTML.match(/class=\"compare-column\"/g)||[]).length,5);
 await vm.runInContext("feedback.a.score=9;feedback.a.likes='<b>test</b>';dirty=true;save()",context);
 assert.equal(JSON.parse([...storage.values()][0]).a.score,9);
 vm.runInContext("tab='favorites';render()",context);assert.match(app.innerHTML,/9\/10/);
});
test('feedback text is escaped and no personal database or external service is referenced by runtime',async()=>{
 assert.equal(escapeHTML('<img onerror="x">'),'&lt;img onerror=&quot;x&quot;&gt;');
 for(const file of ['public/lab.js','public/prototype.js','server.mjs']){const code=await source(file);assert.doesNotMatch(code,/Application Support|AboLife-Main|https:\/\//);}
 assert.equal(initialDemo().budget,300);assert.match(feedbackMarkdown(validateFeedback({})),/Noch offen/);
});
test('daily progress stays bounded after habits exceed their targets',async()=>{
 const {context}=await prototypeContext('a');
 vm.runInContext('data.water=5;data.learning=120;data.sleep=true;data.trained=true',context);
 assert.equal(vm.runInContext('progress()',context),100);
});
test('offline artifact contains syntactically valid gallery and prototype scripts',async()=>{
 const html=await source('UI-Design-Lab.html');
 const scripts=[...html.matchAll(/<script(?: type="module")?>([\s\S]*?)<\/script>/g)].map(m=>m[1]);
 assert.equal(scripts.length,2);
 for(const script of scripts)new vm.Script(script);
 const ctx=vm.createContext({window:{}});vm.runInContext(scripts[0],ctx);
 const prototype=ctx.window.LAB_PROTOTYPE.replace('__LAB_PARAMS__','"design=a"');
 const embedded=[...prototype.matchAll(/<script(?: type="module")?>([\s\S]*?)<\/script>/g)].map(m=>m[1]);
 assert.equal(embedded.length,2);
 for(const script of embedded)new vm.Script(script);
 assert.doesNotMatch(prototype,/<(?:link|script)[^>]+(?:src|href)=/);
});
test('F switches B, D and E without losing the active screen or demo entries and remembers its choice',async()=>{
 const storage=new Map();
 const {context,root,handlers,winHandlers}=await prototypeContext('f',storage);
 handlers.submit({target:{id:'entry-form',dataset:{kind:'expense'},values:{title:'Bleibt erhalten',amount:'10',category:'Alltag'}},preventDefault(){}});
 root.input({target:{name:'wins',value:'Mein Entwurf',closest(){return true}}});
 winHandlers.message({origin:'http://localhost',data:{type:'screen',screen:'settings'}});
 for(const theme of ['d','e','b']){
  root.change({target:{id:'design-theme',value:theme}});
  assert.equal(vm.runInContext('concept.id',context),theme);
  assert.equal(vm.runInContext('page',context),'settings');
  assert.equal(vm.runInContext('data.expenses[0].title',context),'Bleibt erhalten');
  assert.equal(vm.runInContext('data.review.wins',context),'Mein Entwurf');
 }
 root.change({target:{id:'design-theme',value:'e'}});
 root.change({target:{id:'design-accent',value:'blue'}});
 const reopened=await prototypeContext('f',storage);
 assert.equal(vm.runInContext('concept.id',reopened.context),'e');
 assert.equal(vm.runInContext('preferences.accent',reopened.context),'blue');
 assert.doesNotMatch([...storage.values()][0],/Bleibt erhalten|Mein Entwurf/);
 vm.runInContext("changeTheme('a')",context);
 assert.equal(vm.runInContext('concept.id',context),'e');
});
test('F handles denied preference storage without claiming a successful save',async()=>{
 const {context,toast}=await prototypeContext('f');
 vm.runInContext("localStorage.setItem=()=>{throw Error('blocked')};changeTheme('d')",context);
 assert.equal(vm.runInContext('concept.id',context),'d');
 assert.equal(vm.runInContext('preferenceError',context),true);
 assert.match(toast.textContent,/Speichern fehlgeschlagen/);
});
test('Bento widgets move in both directions, persist, and support real drop events',async()=>{
 const {moveWidget}=await import('../public/preferences.js');
 assert.deepEqual(moveWidget(['finance','training','habits','calendar'],'finance','training'),['training','finance','habits','calendar']);
 const storage=new Map(),{context,root}=await prototypeContext('f',storage);
 vm.runInContext("changeTheme('d');navigate('settings')",context);
 root.dragstart({target:{closest(){return {dataset:{widget:'calendar'}}}},dataTransfer:{setData(){}}});
 root.drop({preventDefault(){},target:{closest(){return {dataset:{widget:'finance'}}}}});
 assert.deepEqual(Array.from(vm.runInContext('data.widgets',context)),['calendar','finance','training','habits']);
 const reopened=await prototypeContext('f',storage);
 assert.deepEqual(Array.from(vm.runInContext('data.widgets',reopened.context)),['calendar','finance','training','habits']);
 vm.runInContext("navigate('dashboard')",reopened.context);
 assert.ok(reopened.root.innerHTML.indexOf('calendar-widget')<reopened.root.innerHTML.indexOf('finance-widget'));
});
test('legacy feedback survives adding F and F feedback is saved',async t=>{
 const config=await fixture(t),server=createLabServer(config);
 assert.equal((await request(server,{method:'PUT',body:JSON.stringify({b:{score:7,likes:'Bestehendes Feedback'},f:{score:9,keep:'Drei Erscheinungsbilder'}})})).status,200);
 const data=JSON.parse((await request(createLabServer(config))).body);
 assert.equal(data.b.likes,'Bestehendes Feedback');assert.equal(data.f.score,9);
 assert.match(await readFile(config.reportPath,'utf8'),/Drei Erscheinungsbilder/);
});
test('assistant is reachable in B, D and E on every screen and starts without data grants',async()=>{
 for(const id of ['b','d','e']){
  const {root,dialog,click,winHandlers,context}=await prototypeContext(id);
  for(const [screen] of screens){
   winHandlers.message({origin:'http://localhost',data:{type:'screen',screen}});
   assert.match(root.innerHTML,/aria-label="AboLife AI öffnen"/);
  }
  click('assistant');
  assert.equal(dialog.open,true);
  assert.match(dialog.innerHTML,/BonsaiBar nicht verbunden/);
  assert.match(dialog.innerHTML,/Keine Daten freigegeben/);
  assert.equal(vm.runInContext('assistant.grants.size',context),0);
 }
});
test('assistant respects explicit preview grants, preserves drafts across designs and never calls a model',async()=>{
 const {context,dialog,click,handlers}=await prototypeContext('f');
 click('assistant');
 dialog.input({target:{id:'assistant-draft',value:'Mein Entwurf <test>'}});
 dialog.change({target:{dataset:{aiScope:'finance'},checked:true}});
 assert.match(dialog.innerHTML,/Budget: 300,00/);
 assert.doesNotMatch(dialog.innerHTML,/Training: 2 von/);
 click('close');vm.runInContext("changeTheme('e')",context);click('assistant');
 assert.match(dialog.innerHTML,/Mein Entwurf &lt;test&gt;/);
 handlers.submit({target:{id:'assistant-form'},preventDefault(){}});
 assert.match(dialog.innerHTML,/keine Modellantwort/);
 assert.equal(vm.runInContext('assistant.turns.length',context),2);
 assert.equal(vm.runInContext('assistant.draft',context),'');
});
test('assistant action preview cannot mutate the demo review without grant and confirmation',async()=>{
 const {context,dialog,click}=await prototypeContext('d');
 click('assistant');click('ai-propose');click('ai-confirm');
 assert.equal(vm.runInContext('data.review.focus',context),'');
 dialog.change({target:{dataset:{aiScope:'review'},checked:true}});
 click('ai-propose');
 assert.match(dialog.innerHTML,/Änderung prüfen/);
 assert.equal(vm.runInContext('data.review.focus',context),'');
 click('ai-reject');click('ai-confirm');
 assert.equal(vm.runInContext('data.review.focus',context),'');
 click('ai-propose');click('ai-confirm');
 assert.equal(vm.runInContext('data.review.focus',context),'Nächste Woche kleine Routinen beibehalten.');
});
