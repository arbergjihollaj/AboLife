import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
import {webcrypto} from 'node:crypto';
import {applyAction,emptyDocument} from '../state.mjs';
function client(){
 const elements=new Map(),storage=new Map();
 const element=key=>{if(!elements.has(key))elements.set(key,{hidden:true,textContent:'',innerHTML:'',open:false,disabled:false,children:[],value:'',elements:{},addEventListener(){},replaceChildren(){this.children=[];},append(value){this.children.push(value);},matches(){return false;},focus(){},setSelectionRange(){},showModal(){this.open=true;},close(){this.open=false;}});return elements.get(key);};
 let state={revision:0,document:emptyDocument(),plannerAvailable:false},calls=0;
 const network={offline:false};
 const context=vm.createContext({console,crypto:webcrypto,location:{hash:''},navigator:{},document:{hidden:false,activeElement:null,querySelector:element,querySelectorAll:()=>[],createElement:()=>element('new-'+Math.random()),createTextNode:text=>text,addEventListener(){}},localStorage:{getItem:k=>storage.get(k)??null,setItem:(k,v)=>storage.set(k,v),removeItem:k=>storage.delete(k)},window:{addEventListener(){}},setInterval(){},confirm:()=>true,network,transport:async(path,options={})=>{
  calls++;let body;
  if(path==='/api/state')body=state;
  else if(path==='/api/action'){const input=JSON.parse(options.body);if(input.revision!==state.revision)return{status:409,ok:false,json:async()=>({error:'Konflikt'})};state={revision:state.revision+1,document:applyAction(state.document,input.action)};body=state;}
  else if(path==='/api/news')body={articles:[],failed:[]};
  else body={ok:true};
  return{status:200,ok:true,json:async()=>structuredClone(body)};
 }});
 vm.runInContext("const fetch=async(...args)=>{if(network.offline)throw new TypeError('offline');return transport(...args)};",context);
 vm.runInContext(readFileSync(new URL('../public/app.js',import.meta.url),'utf8'),context);
 return{context,element,storage,network,run:code=>vm.runInContext(code,context),state:()=>state,calls:()=>calls};
}
test('client renders every mobile page with escaped user content and workout details',async()=>{const c=client();await c.run('refresh()');for(const route of ['heute','kalender','lernen','finanzen','training','review','news']){c.run(`location.hash='#${route}';render()`);assert.ok(c.element('#content').innerHTML.length>100,route);}assert.equal(c.run("esc('<img onerror=bad>')"),'&lt;img onerror=bad&gt;');});
test('offline expense persists before acknowledgement and drains exactly once',async()=>{const c=client();await c.run('refresh()');c.network.offline=true;await c.run("action({kind:'expense',title:'Unterwegs',amount:7.5})");assert.equal(c.run('pending.length'),1);assert.equal(JSON.parse(c.storage.get('abolife.outbox')).length,1);assert.equal(c.state().document.tables.finance_entries.length,0);c.network.offline=false;await c.run('drain()');await c.run('drain()');assert.equal(c.run('pending.length'),0);assert.equal(c.state().document.tables.finance_entries.length,1);});
test('offline repeated daily edits are blocked instead of silently overwriting queued increments',async()=>{const c=client();await c.run('refresh()');c.network.offline=true;await c.run("action({kind:'habit',key:'water',value:.25})");await assert.rejects(c.run("action({kind:'habit',key:'water',value:.25})"));assert.equal(c.run('pending.length'),1);});
test('offline logout clears personal snapshots and marks remote session for later revocation',async()=>{const c=client();await c.run('refresh()');assert.ok(c.storage.has('abolife.snapshot'));c.network.offline=true;await c.run('logout()');assert.equal(c.storage.has('abolife.snapshot'),false);assert.equal(c.storage.get('abolife.logoutPending'),'1');assert.equal(c.element('#login').hidden,false);});
test('calendar shows overnight events on both dates and honors exclusions',async()=>{const c=client();await c.run('refresh()');c.run("envelope.document.calendar.events=[{id:'night',title:'Nachttermin',start:Date.parse('2026-10-28T22:00:00Z')/1000-978307200,end:Date.parse('2026-10-29T02:00:00Z')/1000-978307200,weekly:false,timeZoneID:'Europe/Berlin',excludedDays:[]}]");assert.equal(c.run("occurrences('2026-10-28').length"),1);assert.equal(c.run("occurrences('2026-10-29').length"),1);c.run("envelope.document.calendar.events[0].excludedDays=['2026-10-28']");assert.equal(c.run("occurrences('2026-10-29').length"),0);});
test('mobile daily allowance decreases by the entire purchase amount',async()=>{const c=client();await c.run('refresh()');const before=c.run('finance().available');await c.run("action({kind:'expense',title:'Heute',amount:2})");assert.ok(Math.abs(c.run('finance().available')-(before-2))<.001);});
test('revision conflict refreshes displayed state while retaining unsaved form input',async()=>{const c=client();await c.run('refresh()');c.element('#entry-fields').innerHTML='Meine nicht gespeicherte Eingabe';c.state().revision++;await assert.rejects(c.run("action({kind:'expense',title:'Prüfen',amount:5})"));assert.equal(c.run('envelope.revision'),1);assert.equal(c.element('#entry-fields').innerHTML,'Meine nicht gespeicherte Eingabe');assert.equal(c.state().document.tables.finance_entries.length,0);});
