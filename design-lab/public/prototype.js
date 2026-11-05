import {preferenceKey, themeIds, normalizePreferences, readPreferences, moveWidget, paletteFor} from './preferences.js';
import {renderA} from './concepts/a.js';
import {renderB} from './concepts/b.js';
import {renderC} from './concepts/c.js';
import {renderD} from './concepts/d.js';
import {renderE} from './concepts/e.js';
import {concepts,screens,initialDemo,euro,escapeHTML as h} from './data.js';
const dashboardRenderers={a:renderA,b:renderB,c:renderC,d:renderD,e:renderE};
const params=new URLSearchParams(location.search);
const preview=params.has('preview');
const personal=params.get('design')==='f';
let preferences=normalizePreferences({});
let preferenceError=false;
if(personal&&!preview){
  try { preferences=readPreferences(localStorage); }
  catch { preferenceError=true; }
}
let concept=concepts.find(c=>c.id===(personal?preferences.theme:params.get('design')))||concepts[0];
let page=screens.some(s=>s[0]===params.get('screen'))?params.get('screen'):'dashboard';
let data=initialDemo(), filter='Alle', period='Woche', article=null, focusIndex=0;
const root=document.querySelector('#prototype');
const assistant={draft:'',grants:new Set(),turns:[],confirming:false,thinking:false};
if(personal){document.body.classList.add('personal-design');data.widgets=[...preferences.widgets];}
applyPalette();
if(preview) document.body.classList.add('preview');
const btn=(text,action,cls='')=>`<button class="${cls}" data-action="${action}" ${action==='assistant'?'aria-label="AboLife AI öffnen"':''}>${text}</button>`;
const go=(text,id,cls='')=>`<button class="${cls}" data-go="${id}">${text}</button>`;
const spent=()=>data.expenses.reduce((a,e)=>a+e.amount,0);
const metric=(label,value,detail='')=>`<div class="metric"><span class="eyebrow">${label}</span><strong>${value}</strong><small>${detail}</small></div>`;
const card=(title,body,cls='')=>`<section class="panel ${cls}"><div class="section-title"><h2>${title}</h2></div>${body}</section>`;
const ring=(value,label='Daily Core')=>`<div class="ring" style="--progress:${value}%" role="img" aria-label="${label}: ${value} Prozent"><div><strong>${value}<small>%</small></strong><span>${label}</span></div></div>`;
const progress=()=>Math.round(((Math.min(1,data.water/3)+Math.min(1,data.learning/60)+Number(data.sleep)+Number(data.trained))/4)*100);
const bars=()=>`<div class="bars" role="img" aria-label="Fiktive Aktivität: Montag 65, Dienstag 85, Mittwoch 45, Donnerstag 70, Freitag 35, Samstag 90, Sonntag 55 Prozent">${[65,85,45,70,35,90,55].map((v,i)=>`<div><i style="--bar:${v}%"></i><span>${['M','D','M','D','F','S','S'][i]}</span></div>`).join('')}</div>`;
const timeline=()=>`<div class="timeline">${data.events.map(e=>`<div class="event"><time>${h(e.time)}</time><div><b>${h(e.title)}</b><small>${h(e.detail)}</small></div></div>`).join('')}</div>`;
function nav(){return screens.map(([id,title,icon],i)=>`<button data-go="${id}" class="nav-item ${page===id?'selected':''}" ${page===id?'aria-current="page"':''}><span class="nav-icon">${concept.id==='c'?String(i+1).padStart(2,'0'):icon}</span><span>${title}</span></button>`).join('')+(concept.id==='b'?'':btn('<span class="nav-icon" aria-hidden="true">◇</span><span>AboLife AI</span>','assistant','nav-item ai-nav'));}
function financeWidget(){return `<div class="widget-number">${euro(data.budget-spent())}</div><p>übrig von ${euro(data.budget)} im November</p><div class="meter"><i style="width:${Math.min(100,spent()/data.budget*100)}%"></i></div><div class="split"><small>${euro(spent())} ausgegeben</small>${go('Finanzen öffnen ↗','finance','text-button')}</div>`;}
function trainingWidget(){return `<div class="split"><div class="widget-number">${data.trained?'3':'2'}<small> / 3</small></div><span class="symbol">↗</span></div><p>Einheiten diese Woche · aktuelles Ziel</p>${btn(data.trained?'✓ Einheit gespeichert':'Einheit abschließen','workout','primary')}`;}
function habitsWidget(){return `<div class="habit-row"><span>Wasser <small>${data.water.toFixed(2)} / 3 l</small></span>${btn('+ 250 ml','water','pill')}</div><div class="habit-row"><span>Lernen <small>${data.learning} / 60 Min.</small></span>${btn('+ 15 Min.','learn','pill')}</div><div class="habit-row"><span>Schlafroutine</span>${btn(data.sleep?'✓ Erledigt':'Abhaken','sleep','pill')}</div>`;}
function dashboard(){
 const parts={finance:card('Finanzen',financeWidget(),'finance-widget'),training:card('Training',trainingWidget(),'training-widget'),habits:card('Kleine Routinen',habitsWidget(),'habits-widget'),calendar:card('Heute steht an',timeline(),'calendar-widget')};
 const core=`<div class="core-copy"><span class="eyebrow">DONNERSTAG · 05. NOVEMBER</span><h1>${concept.id==='e'?'Mach Platz für<br>einen guten Tag.':concept.id==='c'?'Dein Tag.<br>Auf einen Blick.':'Guten Tag, Abo.'}</h1><p>Ein bisschen Bewegung. Ein klarer Kopf.<br>Die wichtigen Dinge im Blick.</p>${btn('+ Eintrag hinzufügen','add','primary')}</div>`;
 return dashboardRenderers[concept.id]({core,parts,card,financeWidget,trainingWidget,habitsWidget,timeline,ring,progress,btn,go,data,personal});
}
function finance(){const filtered=data.expenses.filter(e=>filter==='Alle'||e.category===filter);return `<div class="detail-grid">${card('Monatsbudget',`${ring(Math.min(100,Math.round(spent()/data.budget*100)),'Ausgegeben')}${metric('RESTBUDGET',euro(data.budget-spent()),'Aktuelles Monatsbudget: '+euro(data.budget))}`,'finance-summary')}${card('Deine Buchungen',`<div class="toolbar">${['Alle','Alltag','Mobilität'].map(f=>`<button data-filter="${f}" aria-pressed="${filter===f}">${f}</button>`).join('')}${btn('+ Ausgabe','expense','primary')}</div><div class="ledger">${filtered.length?filtered.map(e=>`<div class="ledger-row"><div><b>${h(e.title)}</b><small>${h(e.category)} · November, Demo</small></div><strong>−${euro(e.amount)}</strong></div>`).join(''):'<p>Keine Buchungen für diese Auswahl.</p>'}</div>`,'ledger-panel')}${card('Planung & Fixkosten',`<div class="ledger-row"><span>Musikabo <small>Fällig am 15. · Beispieldatum</small></span><strong>5,99 €</strong></div><p>Aktuelle Zielwerte sind keine historischen Budgets.</p>${btn('Budget anpassen','budget','secondary')}`)}</div>`;}
function training(){return `<div class="detail-grid">${card('Wochenfortschritt',metric('EINHEITEN',`${data.trained?3:2} / 3`,'Aktuelles Wochenziel')+bars())}${card('Heute: Ganzkörper',`<p>Dein Trainingsplan für zu Hause. Alle Werte sind fiktiv.</p><div class="exercise-list">${['Liegestütze · 3 × 12','Kniebeugen · 3 × 15','Plank · 3 × 30 Sekunden'].map((x,i)=>`<label><input type="checkbox" name="exercise-${i}"><span>${x}</span></label>`).join('')}</div>${btn(data.trained?'✓ Einheit gespeichert':'Training abschließen','workout','primary')}`)}${card('Letzte Einheiten',`<div class="ledger-row"><span>Mittwoch · Ganzkörper</span><b>35 Min.</b></div><div class="ledger-row"><span>Montag · Fußball</span><b>90 Min.</b></div><p>Beispielverlauf, keine persönlichen Ergebnisse.</p>`)}</div>`;}
function habits(){return `<div class="detail-grid">${card('Heute zählt',ring(progress(),'Tagesstatus')+habitsWidget())}${card('Deine Woche',bars()+'<p>Fiktiver Wochenverlauf · aktuelle Ziele: Wasser 3 l, Lernen 60 Min.</p>')}${card('Training wird übernommen',`<p>Der Trainings-Habit folgt deiner protokollierten Einheit.</p>${go(data.trained?'✓ Training erledigt':'Zum Training →','training','primary')}`)}</div>`;}
function calendar(){return `<div class="calendar-toolbar">${['Tag','Woche'].map(p=>`<button data-period="${p}" aria-pressed="${period===p}">${p}</button>`).join('')}${btn('+ Termin','event','primary')}</div><div class="calendar-layout ${period==='Tag'?'day-view':''}">${(period==='Tag'?['Do 05']:['Mo 02','Di 03','Mi 04','Do 05','Fr 06']).map((day,i)=>`<section class="day-column"><h2>${day}</h2><small>November 2026</small>${(day==='Do 05'?data.events:i%2===0?[{time:'10:00',title:'Projektarbeit',detail:'Beispieltermin'}]:[]).map(e=>`<div class="calendar-event"><time>${h(e.time)}</time><b>${h(e.title)}</b><small>${h(e.detail)}</small></div>`).join('')}</section>`).join('')}</div><p>Termine und Serien werden hier visuell erprobt. ICS-Import und Planungsengine bleiben in der echten App.</p>`;}
function weight(){const low=Math.min(...data.weights)-.1,high=Math.max(...data.weights)+.1;return `<div class="detail-grid">${card('Letzte Messung',metric('GEWICHT',data.weight.toFixed(1).replace('.',',')+' kg','Beispielmessung · aktuelles Ziel 84 kg')+btn('+ Messung','weight','primary'))}${card('Messpunkte',`<svg class="weight-chart" viewBox="0 0 400 160" role="img" aria-label="Vier fiktive Gewichtsmessungen, von 86,8 auf 86,2 Kilogramm"><path d="M20 20H380 M20 80H380 M20 140H380" stroke="currentColor" opacity=".12"/>${data.weights.map((n,i)=>`<circle cx="${30+i*90}" cy="${20+(high-n)/(high-low)*120}" r="6" fill="var(--accent)"/>`).join('')}</svg><p>Nur Messpunkte. Fehlende Tage werden nicht ergänzt.</p>`)}${card('Verlauf',data.weights.slice().reverse().map((n,i)=>`<div class="ledger-row"><span>Demo-Messung ${data.weights.length-i}</span><strong>${n.toFixed(1)} kg</strong></div>`).join(''))}</div>`;}
function statistics(){return `<div class="toolbar">${['Woche','Monat'].map(p=>`<button data-period="${p}" aria-pressed="${period===p}">${p}</button>`).join('')}</div><div class="stats-grid">${metric('TRAINING',period==='Monat'?'8':data.trained?'3':'2','Einheiten im Beispielzeitraum')}${metric('AUSGABEN',euro(spent()),'November · Beispieldaten')}${metric('GEWICHT',data.weight.toFixed(1)+' kg','Letzte fiktive Messung')}${metric('WASSER HEUTE',data.water.toFixed(2)+' l','Aktuelles Ziel: 3 Liter')}</div>${card(period==='Monat'?'Aktivität im Monatsbeispiel':'Aktivität der Woche',bars()+'<p>Die Ansicht zeigt fiktive Testwerte. Zielwerte entsprechen den aktuellen Demo-Einstellungen.</p>')}`;}
function review(){return `<div class="review-layout">${card('02.–08. November',`<h2>Was nimmst du mit?</h2><p>Ein kurzer Rückblick schafft Platz für die nächste Woche.</p>${bars()}`)}${card('Dein persönlicher Rückblick',`<form id="review-form">${[['wins','Was lief gut?'],['challenges','Was war schwierig?'],['focus','Fokus für nächste Woche']].map(([key,title])=>`<label>${title}<textarea name="${key}" rows="3">${h(data.review[key])}</textarea></label>`).join('')}<button class="primary">Review im Prototyp merken</button><p>Bleibt während dieses Prototypbesuchs erhalten.</p></form>`)}</div>`;}
const articles=[{title:'Kleine Routinen, große Wirkung',cat:'Alltag',body:'Dieser fiktive Artikel dient dazu, Lesefluss und Merkfunktion zu testen. Im echten AboLife werden Nachrichten aus deinen RSS-Quellen geladen.'},{title:'Lokale Software bewusst gestalten',cat:'Technologie',body:'Ein Beispielartikel über lokale Werkzeuge. Hier kannst du die Lesedarstellung und das Markieren ausprobieren.'},{title:'Bewegung in den Alltag bringen',cat:'Sport',body:'Beispieltext für die Designbewertung. Keine aktuelle Nachricht und keine persönliche Empfehlung.'}];
function news(){if(article!==null){const a=articles[article];return card('LESEANSICHT · FIKTIVER ARTIKEL',`${btn('← Alle Artikel','articles','text-button')}<h1>${a.title}</h1><p>${a.body}</p>${btn(data.bookmarks.includes(article)?'★ Gemerkt':'☆ Artikel merken','bookmark-'+article,'secondary')}`);}return `<div class="toolbar">${['Alle','Alltag','Technologie','Sport','Gemerkt'].map(f=>`<button data-filter="${f}" aria-pressed="${filter===f}">${f}</button>`).join('')}</div><div class="news-grid">${articles.map((a,i)=>({...a,i})).filter(a=>filter==='Alle'||filter===a.cat||filter==='Gemerkt'&&data.bookmarks.includes(a.i)).map(a=>card(a.cat,`<span class="eyebrow">DEMO-REDAKTION · FIKTIV</span><h2>${a.title}</h2><p>${data.read.includes(a.i)?'Bereits gelesen':'3 Minuten Lesezeit'}</p>${btn('Artikel lesen ↗','article-'+a.i,'text-button')}${btn(data.bookmarks.includes(a.i)?'★ Gemerkt':'☆ Merken','bookmark-'+a.i,'text-button')}`)).join('')||'<p>Noch keine gemerkten Artikel.</p>'}</div>`;}
function settings(){return `<div class="detail-grid">${personal?appearanceSettings():''}${card('Deine Ziele',`<div class="ledger-row"><span>Monatsbudget</span><strong>${euro(data.budget)}</strong></div><div class="ledger-row"><span>Training pro Woche</span><strong>3 Einheiten</strong></div>${btn('Budget anpassen','budget','secondary')}`)}${card('Darstellung',`<label class="habit-row">Bewegung reduzieren <input type="checkbox" id="reduce-motion" ${document.body.classList.contains('reduce-motion')?'checked':''}></label><p>Zusätzlich wird die Systemeinstellung „Bewegung reduzieren“ berücksichtigt.</p>`)}${card('Daten & Verbindung',`<p>Isolierte Beispieldaten. Kein Sync, keine echte Sicherung, kein Schlüsselbund und keine KI-Verbindung in diesem Lab.</p>${btn('Beispieldaten zurücksetzen','reset','secondary')}`)}</div>`;}
const views={dashboard,finance,training,habits,calendar,weight,statistics,review,news,settings};
function render(){
 const title=screens.find(s=>s[0]===page)[1];
 const brand=`<div class="brand"><span class="brand-mark">a.</span><b>AboLife</b>${concept.id==='e'?'<small>FIELDNOTES EDITION</small>':''}</div>`;
 const shellStart=concept.id==='a'?`<aside class="native-sidebar">${brand}<nav aria-label="Bereiche">${nav()}</nav><small class="workspace">● Lokaler Demo-Arbeitsbereich</small></aside>`:concept.id==='b'?`<header class="spatial-top">${brand}${personal?'':'<span class="eyebrow">PERSONAL SPACE / 2026</span>'}<div class="spatial-header-actions">${btn('<span aria-hidden="true">◇ </span><span class="ai-full">AboLife AI</span><span class="ai-short">AI</span>','assistant','ai-launch')}${btn('+ Erfassen','add','secondary')}</div></header><nav class="spatial-dock" aria-label="Bereiche">${nav()}</nav>`:concept.id==='c'?`<header class="swiss-masthead">${brand}<span>DEIN ALLTAG. KLAR GEORDNET.</span><span>VOL. 04 / 2026</span></header><nav class="swiss-index" aria-label="Bereiche">${nav()}</nav>`:concept.id==='d'?`<aside class="bento-rail">${brand}<nav aria-label="Bereiche">${nav()}</nav></aside>`:`<header class="journal-masthead">${brand}${btn('<span aria-hidden="true">◇ </span><span class="ai-full">AboLife AI</span><span class="ai-short">AI</span>','assistant','ai-launch journal-ai')}<label>Register öffnen <select id="journal-nav" aria-label="Lebensbereich">${screens.map(([id,t])=>`<option value="${id}" ${id===page?'selected':''}>${t}</option>`).join('')}</select></label></header><nav class="journal-tabs" aria-label="Kapitel">${screens.slice(0,5).map(([id,t],i)=>go(`${String(i+1).padStart(2,'0')} / ${t}`,id,page===id?'selected':'')).join('')}</nav>`;
 root.innerHTML=`<div class="app-shell">${shellStart}<main class="app-content"><div class="demo-line"><span>FIKTIVE BEISPIELDATEN · ${personal?'My Perfect Design · ':''}${concept.name}</span><span>Konzept ${personal?'F':concept.id.toUpperCase()}</span></div>${page!=='dashboard'?`<div class="page-heading"><div><span class="eyebrow">ABOLIFE / NOVEMBER 2026</span><h1>${title}</h1></div>${btn('+ Eintrag','add','primary')}</div>`:''}<div class="page-body" key="${page}">${views[page]()}</div><footer class="prototype-footer">Interaktiver Design-Prototyp · Eingaben gelten nur für diesen Besuch · Keine produktiven Daten</footer></main></div>`;
 document.title=`${title} · ${concept.name} · AboLife`;
}
function toast(text){const el=document.querySelector('#toast');el.textContent=text;el.classList.add('visible');clearTimeout(toast.timer);toast.timer=setTimeout(()=>el.classList.remove('visible'),2600);}
function navigate(target){page=target;filter='Alle';article=null;render();document.querySelector('.app-content').scrollTop=0;}
function openForm(kind){
 const dialog=document.querySelector('#entry-dialog');
 dialog.classList.remove('assistant-dialog');
 const config={expense:['Ausgabe erfassen',`<label>Bezeichnung<input name="title" required maxlength="80" placeholder="z. B. Mittagessen"></label><label>Betrag in Euro<input name="amount" type="number" min="0.01" max="100000" step="0.01" required></label><label>Kategorie<select name="category"><option>Alltag</option><option>Mobilität</option></select></label>`],weight:['Gewicht notieren',`<label>Gewicht in kg<input name="weight" type="number" min="30" max="300" step="0.1" value="${data.weight}" required></label>`],event:['Termin anlegen','<label>Titel<input name="title" required maxlength="80"></label><label>Uhrzeit<input type="time" name="time" value="16:00" required></label><label>Ort<input name="detail" maxlength="100" placeholder="Zuhause"></label>'],budget:['Monatsbudget anpassen',`<label>Budget in Euro<input name="budget" type="number" min="1" max="100000" step="1" value="${data.budget}" required></label>`]};
 if(kind==='add') dialog.innerHTML=`<div class="dialog-heading"><h2>Schnellerfassung</h2>${btn('Schließen','close','secondary')}</div><p>Nur für diesen Prototypbesuch.</p><div class="quick-choices">${btn('€ Ausgabe','expense')}${btn('↗ Training','workout')}${btn('∿ Gewicht','weight')}${btn('▦ Termin','event')}${btn('Wasser + 250 ml','water')}</div>`;
 else {const [title,fields]=config[kind];dialog.innerHTML=`<div class="dialog-heading"><h2>${title}</h2>${btn('Schließen','close','secondary')}</div><p>Fiktive Eingabe · keine Änderung der echten App</p><form id="entry-form" data-kind="${kind}">${fields}<button class="primary">Im Prototyp übernehmen</button></form>`;}
 if(!dialog.open)dialog.showModal();
}
root.addEventListener('click',handleClick);document.querySelector('#entry-dialog').addEventListener('click',handleClick);
function handleClick(event){
 const node=event.target.closest('button');if(!node)return;
 if(node.dataset.go){navigate(node.dataset.go);return;}
 if(node.dataset.filter){filter=node.dataset.filter;render();return;}
 if(node.dataset.period){period=node.dataset.period;render();return;}
 const action=node.dataset.action;
 if(node.dataset.move){
  const id=node.dataset.move,index=data.widgets.indexOf(id),target=data.widgets[index+Number(node.dataset.direction)];
  if(target)reorderWidget(id,target);
  return;
 }
 if(['add','expense','weight','event','budget'].includes(action)){openForm(action);return;}
 if(action==='assistant'){openAssistant();return;}
 if(action==='ai-prompt-finance'||action==='ai-prompt-review'){
  assistant.draft=action==='ai-prompt-finance'?'Wie steht es um mein Budget?':'Hilf mir beim Wochenrückblick.';
  openAssistant();return;
 }
 if(action==='ai-propose'){
  if(!assistant.grants.has('review')){toast('Bitte zuerst Wochenreview für den Demo-Vorschlag freigeben.');return;}
  assistant.confirming=true;openAssistant();return;
 }
 if(action==='ai-reject'){assistant.confirming=false;openAssistant();return;}
 if(action==='ai-confirm'){
  if(!assistant.confirming||!assistant.grants.has('review'))return;
  data.review.focus='Nächste Woche kleine Routinen beibehalten.';
  assistant.confirming=false;render();openAssistant();toast('Demo-Review nach Bestätigung ergänzt.');return;
 }
 if(action==='save-appearance'){persistPreferences();return;}
 if(action==='close'){document.querySelector('#entry-dialog').close();return;}
 if(action==='water'){data.water=Math.min(5,data.water+.25);toast('250 ml im Prototyp ergänzt.');}
 if(action==='learn'){data.learning+=15;toast('15 Minuten im Prototyp ergänzt.');}
 if(action==='sleep')data.sleep=!data.sleep;
 if(action==='workout'){data.trained=true;document.querySelector('#entry-dialog').close();toast('Demo-Einheit abgeschlossen.');}
 if(action==='reorder'){data.widgets.push(data.widgets.shift());toast('Widgets neu angeordnet. Erneut klicken für die nächste Reihenfolge.');}
 if(action==='reset'){data=initialDemo();if(personal)data.widgets=[...preferences.widgets];toast('Beispieldaten zurückgesetzt.');}
 if(action?.startsWith('article-')){article=Number(action.split('-')[1]);if(!data.read.includes(article))data.read.push(article);}
 if(action?.startsWith('bookmark-')){const id=Number(action.split('-')[1]);data.bookmarks=data.bookmarks.includes(id)?data.bookmarks.filter(x=>x!==id):[...data.bookmarks,id];toast(data.bookmarks.includes(id)?'Artikel gemerkt.':'Merker entfernt.');}
 if(action==='articles')article=null;
 render();
}
root.addEventListener('change',e=>{if(e.target.id==='design-theme'){changeTheme(e.target.value);return;}if(e.target.id==='design-accent'){preferences.accent=e.target.value;persistPreferences();applyPalette();return;}if(e.target.id==='journal-nav')navigate(e.target.value);if(e.target.id==='reduce-motion')document.body.classList.toggle('reduce-motion',e.target.checked);});
document.addEventListener('submit',e=>{
 if(e.target.id==='assistant-form'){
  e.preventDefault();
  const question=assistant.draft.trim();
  if(!question){toast('Bitte zuerst eine Frage eingeben.');return;}
  assistant.turns.push({role:'user',text:question},{role:'assistant',text:'Dies ist eine vorbereitete Demonstration des Gesprächsablaufs, keine Modellantwort. In deiner echten App übernimmt hier der bestehende lokale BonsaiBar-Assistent mit deinen ausgewählten Freigaben.'});
  assistant.draft='';openAssistant();return;
 }
 if(e.target.id==='entry-form'){
  e.preventDefault();const f=new FormData(e.target), kind=e.target.dataset.kind;
  if(kind==='expense')data.expenses.unshift({title:String(f.get('title')).trim(),amount:Number(f.get('amount')),category:String(f.get('category'))});
  if(kind==='weight'){data.weight=Number(f.get('weight'));data.weights.push(data.weight);data.weights=data.weights.slice(-4);}
  if(kind==='budget')data.budget=Number(f.get('budget'));
  if(kind==='event'){data.events.push({title:String(f.get('title')),time:String(f.get('time')),detail:String(f.get('detail')||'Demo-Termin')});data.events.sort((a,b)=>a.time.localeCompare(b.time));}
  document.querySelector('#entry-dialog').close();render();toast('Im Prototyp übernommen.');
 }
 if(e.target.id==='review-form'){e.preventDefault();const f=new FormData(e.target);data.review=Object.fromEntries(f);toast('Demo-Review für diesen Besuch gespeichert.');}
});
root.addEventListener('input',e=>{if(e.target.closest('#review-form'))data.review[e.target.name]=e.target.value;});
window.addEventListener('message',e=>{if(e.origin!==location.origin)return;if(e.data?.type==='screen'&&screens.some(s=>s[0]===e.data.screen))navigate(e.data.screen);if(e.data?.type==='replay'){const el=document.querySelector('.page-body');el.classList.remove('replay');void el.offsetWidth;el.classList.add('replay');}if(e.data?.type==='reset'){data=initialDemo();if(personal)data.widgets=[...preferences.widgets];render();}});
render();
if(preferenceError)toast('Darstellung konnte nicht geladen werden. Standarddesign ist aktiv; Einstellungen erneut speichern.');

function applyPalette() {
  document.body.dataset.design=concept.id;
  if(!personal)return;
  const palette=paletteFor(concept.id,preferences.accent);
  if(palette.accent)document.body.style.setProperty('--accent',palette.accent);
  else document.body.style.removeProperty('--accent');
  document.body.style.setProperty('--accent-ink',palette.ink);
}
function persistPreferences() {
  preferences.widgets=[...data.widgets];
  try {
    localStorage.setItem(preferenceKey,JSON.stringify(preferences));
    preferenceError=false;
    toast('Darstellung auf diesem Browser gespeichert.');
    return true;
  } catch {
    preferenceError=true;
    toast('Darstellung nur für diesen Besuch geändert. Speichern fehlgeschlagen; bitte erneut versuchen.');
    return false;
  }
}
function changeTheme(id) {
  if(!personal||!themeIds.includes(id))return;
  preferences.theme=id;
  concept=concepts.find(c=>c.id===id);
  persistPreferences();
  applyPalette();
  render();
  document.querySelector('#design-theme')?.focus();
}
function reorderWidget(from,to) {
  data.widgets=moveWidget(data.widgets,from,to);
  persistPreferences();
  render();
}
function appearanceSettings() {
  const names={finance:'Budget',training:'Training',habits:'Gewohnheiten',calendar:'Kalender'};
  return card('Dein Erscheinungsbild',`
    <label class="setting-field">Design
      <select id="design-theme">${themeIds.map(id=>`<option value="${id}" ${concept.id===id?'selected':''}>${concepts.find(c=>c.id===id).name}</option>`).join('')}</select>
    </label>
    <p>Wechselt Navigation, Layout und Typografie. Deine Eingaben bleiben beim Wechsel erhalten.</p>
    <label class="setting-field">Akzentfarbe
      <select id="design-accent">${[['default','Original'],['blue','Blau'],['violet','Violett'],['amber','Bernstein']].map(([id,name])=>`<option value="${id}" ${preferences.accent===id?'selected':''}>${name}</option>`).join('')}</select>
    </label>
    <p>Design, Farbe und Widgetreihenfolge bleiben in diesem Browser gespeichert. Die drei Designs teilen dieselben Demo-Eingaben.</p>
    ${btn('Darstellung speichern','save-appearance','secondary')}
    ${concept.id==='d'?`<h2 class="widget-editor-heading">Dashboard anordnen</h2><p>Ziehe die Widgets an die gewünschte Stelle. Alternativ mit „Nach oben“ / „Nach unten“ verschieben. Die übrigen Module rücken nach.</p><ol class="widget-editor">${data.widgets.map((id,i)=>`<li draggable="true" data-widget="${id}"><span aria-hidden="true">⠿</span><b>${names[id]}</b><button data-action="move-widget" data-move="${id}" data-direction="-1" aria-label="${names[id]} nach oben" ${i===0?'disabled':''}>↑</button><button data-action="move-widget" data-move="${id}" data-direction="1" aria-label="${names[id]} nach unten" ${i===data.widgets.length-1?'disabled':''}>↓</button></li>`).join('')}</ol>${go('Dashboard ansehen →','dashboard','primary')}`:''}
    ${preferenceError?'<p role="status">Speichern noch nicht bestätigt. Bitte erneut speichern.</p>':''}
  `,'appearance-settings');
}
let draggedWidget=null;
root.addEventListener('dragstart',event=>{
  const row=event.target.closest('[data-widget]');
  if(!personal||concept.id!=='d'||!row)return;
  draggedWidget=row.dataset.widget;
  event.dataTransfer.setData('text/plain',draggedWidget);
  event.dataTransfer.effectAllowed='move';
});
root.addEventListener('dragover',event=>{
  if(draggedWidget&&event.target.closest('[data-widget]'))event.preventDefault();
});
root.addEventListener('drop',event=>{
  const row=event.target.closest('[data-widget]');
  if(!draggedWidget||!row)return;
  event.preventDefault();
  reorderWidget(draggedWidget,row.dataset.widget);
  draggedWidget=null;
});
root.addEventListener('dragend',()=>{draggedWidget=null;});

function assistantContext() {
  const facts=[];
  if(assistant.grants.has('finance'))facts.push(`Budget: ${euro(data.budget)}; Ausgaben: ${euro(spent())}; Rest: ${euro(data.budget-spent())}.`);
  if(assistant.grants.has('training'))facts.push(`Training: ${data.trained?3:2} von 3 Einheiten im fiktiven Wochenbeispiel.`);
  if(assistant.grants.has('habits'))facts.push(`Gewohnheiten: ${data.water.toFixed(2)} l Wasser, ${data.learning} Minuten Lernen; Schlafroutine ${data.sleep?'erledigt':'offen'}.`);
  if(assistant.grants.has('calendar'))facts.push(`Kalender: ${data.events.map(event=>event.title+' um '+event.time).join('; ')}.`);
  if(assistant.grants.has('review'))facts.push(`Review: ${data.review.wins||'Noch kein Rückblick'}; Fokus: ${data.review.focus||'noch offen'}.`);
  if(assistant.grants.has('news'))facts.push('Nachrichten: ausschließlich fiktive Testartikel, keine aktuellen RSS-Daten.');
  return facts;
}
function openAssistant() {
  const dialog=document.querySelector('#entry-dialog');
  const title=screens.find(screen=>screen[0]===page)[1];
  const scopeNames=[['finance','Finanzen'],['training','Training'],['habits','Gewohnheiten'],['calendar','Kalender'],['review','Wochenreview'],['news','Nachrichten']];
  dialog.classList.add('assistant-dialog');
  dialog.innerHTML=`
    <div class="dialog-heading"><div><span class="eyebrow">${h(concept.name)} / ${h(title)}</span><h2>AboLife AI</h2></div>${btn('Assistent schließen','close','secondary')}</div>
    <div class="assistant-demo-note" role="status">Designvorschau · BonsaiBar nicht verbunden. Keine echte KI-Anfrage.</div>
    <div class="assistant-layout">
      <aside class="assistant-context">
        <h3>Kontext für deine Frage</h3><p>Nur ausdrücklich ausgewählte Beispieldaten erscheinen in der Kontextvorschau.</p>
        <fieldset><legend>Für diese Anfrage freigeben</legend>${scopeNames.map(([id,name])=>`<label class="assistant-grant"><input type="checkbox" data-ai-scope="${id}" ${assistant.grants.has(id)?'checked':''}>${name}</label>`).join('')}</fieldset>
        <details class="assistant-context-preview"><summary>Kontext vor dem Senden ansehen</summary>${assistantContext().length?assistantContext().map(fact=>`<p>${h(fact)}</p>`).join(''):'<p>Keine Daten freigegeben.</p>'}</details>
        <p class="assistant-connection">In der echten App: lokal über BonsaiBar. Verbindung und Freigaben bleiben unter deiner Kontrolle.</p>
      </aside>
      <section class="assistant-conversation" aria-label="KI-Gesprächsvorschau">
        <div class="assistant-chat" aria-live="polite">${assistant.turns.length?assistant.turns.map(turn=>`<article class="assistant-bubble ${turn.role}"><strong>${turn.role==='user'?'Du':'AboLife AI · Demo'}</strong><p>${h(turn.text)}</p></article>`).join(''):`<div class="assistant-empty"><span aria-hidden="true">◇</span><h3>Was möchtest du klären?</h3><p>Dein Assistent ist aus jedem Bereich erreichbar.</p>${btn('Wie steht es um mein Budget?','ai-prompt-finance','secondary')}${btn('Hilf mir beim Wochenrückblick.','ai-prompt-review','secondary')}</div>`}</div>
        ${assistant.confirming?`<section class="assistant-confirm"><h3>Änderung prüfen · Demo</h3><p>Im fiktiven Wochenreview wird der Fokus „Nächste Woche kleine Routinen beibehalten.“ ergänzt. Es werden keine persönlichen Daten geändert.</p><div class="toolbar">${btn('Ablehnen','ai-reject','secondary')}${btn('Im Prototyp übernehmen','ai-confirm','primary')}</div></section>`:''}
        <form id="assistant-form"><label>Frage an AboLife AI<textarea id="assistant-draft" name="question" maxlength="4000" rows="3" placeholder="Was möchtest du besprechen?">${h(assistant.draft)}</textarea></label><div class="assistant-compose-actions"><label><input id="assistant-thinking" type="checkbox" ${assistant.thinking?'checked':''}>Denken · Vorschau</label><button class="primary">Ablauf testen</button></div></form>
        <div class="assistant-action-bar">${btn('Aktionsvorschlag prüfen','ai-propose','secondary')}<small>Änderungen nur nach Bestätigung. Demo-Vorschlag benötigt die Review-Freigabe.</small></div>
      </section>
    </div>`;
  if(!dialog.open)dialog.showModal();
}

const assistantDialog=document.querySelector('#entry-dialog');
assistantDialog.addEventListener('input',event=>{
  if(event.target.id==='assistant-draft')assistant.draft=event.target.value;
});
assistantDialog.addEventListener('change',event=>{
  if(event.target.dataset.aiScope){
    const scope=event.target.dataset.aiScope;
    if(event.target.checked)assistant.grants.add(scope);else assistant.grants.delete(scope);
    assistant.confirming=false;openAssistant();
  }
  if(event.target.id==='assistant-thinking')assistant.thinking=event.target.checked;
});
