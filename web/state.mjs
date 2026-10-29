import { randomUUID } from 'node:crypto';
import {readFileSync} from 'node:fs';
const SCHEMA=JSON.parse(readFileSync(new URL('./schema.json',import.meta.url)));
export const TABLES = ['app_settings','finance_categories','finance_entries','finance_category_budgets','finance_fixed_costs','finance_savings_goals','habit_entries','weight_entries','body_metric_entries','workout_sessions','workout_exercises','workout_sets','weekly_reviews','news_state'];
export const swiftTime = (date = new Date()) => date.getTime()/1000 - 978307200;
export const sqlTime = (date = new Date()) => date.toISOString().replace('T',' ').replace('Z','');
export function dayKey(date = new Date()) { return new Intl.DateTimeFormat('sv-SE', {timeZone:'Europe/Berlin'}).format(date); }
export function emptyDocument() {
 return {schemaVersion:1,tables:Object.fromEntries(TABLES.map(t=>[t,[]])), calendar:{events:[],topics:[],sessions:[],importSources:[],preferences:{dayStartMinute:480,dayEndMinute:1260,weekdays:[2,3,4,5,6],dailyLimitMinutes:120,minimumBlockMinutes:25,breakMinutes:10,timeZoneID:'Europe/Berlin',travelMinutes:{'home>university':60,'home>gym':15},learningLocations:['home']}}};
}
const scalar = x => x === null || typeof x === 'string' || (typeof x === 'number' && Number.isFinite(x));
export function validateDocument(d) {
 if (!d || d.schemaVersion !== 1 || !d.tables || Object.keys(d.tables).sort().join() !== TABLES.toSorted().join()) throw new Error('Unbekanntes Datenformat.');
 for (const [name, rows] of Object.entries(d.tables)) {
  if (!Array.isArray(rows) || rows.length > 100000) throw new Error('Ungültige Tabelle.');
  const ids = new Set();
  for (const row of rows) {
   if (!row || typeof row.id !== 'string' || !row.id || ids.has(row.id) || Object.keys(row).some(k=>!/^\w+$/.test(k)) || Object.values(row).some(v=>!scalar(v))) throw new Error('Ungültige Zeile in '+name);
   const columns=SCHEMA[name];
   if(Object.keys(row).sort().join()!==columns.map(c=>c.name).sort().join())throw new Error('Spalten passen nicht zum Datenformat: '+name);
   for(const column of columns){const v=row[column.name];if(v===null){if(column.required)throw new Error('Pflichtfeld fehlt: '+column.name);continue;}
    if(/INT|BOOL/i.test(column.type)?!Number.isSafeInteger(v):/DOUBLE|REAL|FLOAT|NUMERIC/i.test(column.type)?typeof v!=='number':typeof v!=='string')throw new Error('Ungültiger Wert: '+column.name);
   }
   ids.add(row.id);
  }
 }
 for(const [child,key,parent] of [['workout_exercises','session_id','workout_sessions'],['workout_sets','exercise_id','workout_exercises']]){
  const ids=new Set(d.tables[parent].map(r=>r.id));if(d.tables[child].some(r=>!ids.has(r[key])))throw new Error('Unvollständige Trainingsdaten.');
 }
 for(const [table,columns] of [['habit_entries',['habit_key','date']],['weight_entries',['date']],['weekly_reviews',['week_start_date']],['finance_category_budgets',['month_key','category']],['finance_categories',['kind','normalized_key']]]){
  const keys=d.tables[table].map(row=>JSON.stringify(columns.map(k=>row[k])));if(new Set(keys).size!==keys.length)throw new Error('Doppelte Einträge in '+table);
 }
 const settings=d.tables.app_settings;
 if(settings.length>1||settings.some(r=>r.id!=='settings'||r.monthly_budget<0||r.weekly_workout_target<0))throw new Error('Ungültige Einstellungen.');
 const c=d.calendar;
 if (!c || !c.preferences || !Array.isArray(c.events) || !Array.isArray(c.topics) || !Array.isArray(c.sessions) || !Array.isArray(c.importSources)) throw new Error('Ungültiger Kalender.');
 const p=c.preferences;
 if (!Number.isInteger(p.dayStartMinute)||!Number.isInteger(p.dayEndMinute)||p.dayStartMinute<0||p.dayEndMinute>1439||p.dayEndMinute<=p.dayStartMinute||!Array.isArray(p.weekdays)||!p.weekdays.length||!p.weekdays.every(v=>Number.isInteger(v)&&v>=1&&v<=7)||!Array.isArray(p.learningLocations)||typeof p.timeZoneID!=='string') throw new Error('Ungültige Lernzeiten.');
 if(!Number.isInteger(p.dailyLimitMinutes)||p.dailyLimitMinutes<15||p.dailyLimitMinutes>480||!Number.isInteger(p.minimumBlockMinutes)||p.minimumBlockMinutes<5||p.minimumBlockMinutes>120||p.minimumBlockMinutes>p.dailyLimitMinutes||!Number.isInteger(p.breakMinutes)||p.breakMinutes<0||p.breakMinutes>60||!p.travelMinutes||Object.values(p.travelMinutes).some(v=>!Number.isInteger(v)||v<0||v>300))throw new Error('Ungültige Lernregeln.');
 try {new Intl.DateTimeFormat('de',{timeZone:p.timeZoneID});}catch {throw new Error('Ungültige Zeitzone.');}
 for (const list of [c.events,c.topics,c.sessions]) {
  if(list.length>100000||new Set(list.map(x=>x?.id)).size!==list.length||list.some(x=>!x||typeof x.id!=='string'))throw new Error('Ungültige Kalenderdaten.');
 }
 for (const e of c.events) {
  if(typeof e.location!=='string'||typeof e.timeZoneID!=='string'||typeof e.weekly!=='boolean'||typeof e.locallyModified!=='boolean'||typeof e.cancelled!=='boolean'||!Array.isArray(e.repeatWeekdays)||!Array.isArray(e.excludedDays))throw new Error('Ungültige Terminmetadaten.');
  try{new Intl.DateTimeFormat('de',{timeZone:e.timeZoneID});}catch{throw new Error('Ungültige Terminzeitzone.');}
 }
 for(const topic of c.topics){if(typeof topic.title!=='string'||typeof topic.course!=='string'||!Number.isFinite(topic.nextReview)||!Number.isInteger(topic.durationMinutes)||topic.durationMinutes<5||topic.durationMinutes>180||!Number.isFinite(topic.intervalDays)||!Number.isFinite(topic.ease)||!Number.isInteger(topic.reviewCount)||!Array.isArray(topic.actualDurations)||typeof topic.archived!=='boolean')throw new Error('Ungültiges Lernthema.');}
 for(const session of c.sessions){if(typeof session.topicID!=='string'||typeof session.location!=='string'||typeof session.pinned!=='boolean'||typeof session.reason!=='string')throw new Error('Ungültige Lernblock-Metadaten.');}
 for (const e of c.events) if (typeof e.title!=='string'||!['university','training','personal'].includes(e.kind)||!Number.isFinite(e.start)||!Number.isFinite(e.end)||e.end<=e.start) throw new Error('Ungültiger Termin.');
 for (const s of c.sessions) if(!Number.isFinite(s.start)||!Number.isFinite(s.end)||s.end<=s.start||!['planned','completed','skipped'].includes(s.status))throw new Error('Ungültiger Lernblock.');
 return d;
}
function text(value, max=500) { if(typeof value!=='string'||!value.trim()||value.trim().length>max)throw new Error('Bitte einen gültigen Text eingeben.'); return value.trim(); }
function number(value,min,max) { if(value===null||value===undefined||typeof value==='boolean'||(typeof value==='string'&&!value.trim()))throw new Error('Bitte einen Zahlenwert eingeben.');const v=Number(value);if(!Number.isFinite(v)||v<min||v>max)throw new Error('Bitte einen gültigen Zahlenwert eingeben.');return v; }
function date(value) { if(typeof value!=='string'||!value.trim())throw new Error('Ungültiges Datum.');const d=new Date(value);if(!Number.isFinite(+d))throw new Error('Ungültiges Datum.');return d; }
function validDay(key){if(typeof key!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(key))return false;const d=new Date(key+'T12:00:00Z');return Number.isFinite(+d)&&d.toISOString().slice(0,10)===key;}
export function applyAction(document, action, now=new Date()) {
 if(!action||typeof action!=='object')throw new Error('Aktion fehlt.');
 const d=structuredClone(document??emptyDocument());const t=d.tables;const stamp=sqlTime(now);
 switch(action.kind) {
  case 'expense': {
   const occurred = action.date ? date(action.date) : now;
   t.finance_entries.push({id:randomUUID(),occurred_at:sqlTime(occurred),title:text(action.title,200),amount:Math.round(number(action.amount,.01,1e8)*100)/100,currency:'EUR',category:text(action.category||'Sonstiges',100),note:action.note?text(action.note):null,created_at:stamp,updated_at:stamp});break;
  }
  case 'habit': {
   const defs={water:[3,'Liter'],learning:[60,'Min.'],sleep:[1,'']};const def=defs[action.key];if(!def)throw new Error('Unbekannte Gewohnheit.');
   const key=action.date||dayKey(now);if(!validDay(key))throw new Error('Ungültiger Tag.');
   const value=number(action.value,0,10000);const existing=t.habit_entries.find(x=>x.habit_key===action.key&&x.date===key);
   const row={id:existing?.id??randomUUID(),habit_key:action.key,date:key,is_completed:value>=def[0]?1:0,value,target_value:def[0],unit:def[1],note:existing?.note??null,created_at:existing?.created_at??stamp,updated_at:stamp};
   if(existing)Object.assign(existing,row);else t.habit_entries.push(row);break;
  }
  case 'weight': {
   const key=action.date||dayKey(now);if(!validDay(key))throw new Error('Ungültiger Tag.');
   const value=number(action.value,20,300);const row=t.weight_entries.find(x=>x.date===key);
   if(row){row.weight_kg=value;row.updated_at=stamp;}else t.weight_entries.push({id:randomUUID(),date:key,weight_kg:value,created_at:stamp,updated_at:stamp});break;
  }
  case 'workout':
   t.workout_sessions.push({id:randomUUID(),occurred_at:action.date?sqlTime(date(action.date)):stamp,workout_type:text(action.title,200),duration_min:Math.round(number(action.minutes,1,1440)),status:'done',note:null,created_at:stamp,updated_at:stamp,workout_intensity:null,pain_reported:0});break;
  case 'event': {
   const start=date(action.start),end=date(action.end);if(end<=start||end-start>7*86400000)throw new Error('Ungültiger Zeitraum.');
   d.calendar.events.push({id:randomUUID(),title:text(action.title,200),kind:['university','training','personal'].includes(action.eventKind)?action.eventKind:'personal',start:swiftTime(start),end:swiftTime(end),location:action.location?text(action.location,100):'home',timeZoneID:'Europe/Berlin',weekly:false,repeatWeekdays:[],excludedDays:[],locallyModified:false,cancelled:false});break;
  }
  case 'plannedWorkout': {
   const plan=d.workoutPlan?.find(p=>p.id===action.day),exercises=plan?.variants?.[action.intensity];
   if(!plan||!Array.isArray(exercises)||!['Minimum','Normal','Stark'].includes(action.intensity))throw new Error('Trainingsplan nicht verfügbar. Bitte zuerst den Mac synchronisieren.');
   if(!Array.isArray(action.completed)||!action.completed.length||action.completed.some(i=>!Number.isInteger(i)||i<0||i>=exercises.length))throw new Error('Mindestens eine absolvierte Übung auswählen.');
   const sessionID=randomUUID();
   t.workout_sessions.push({id:sessionID,occurred_at:action.date?sqlTime(date(action.date)):stamp,workout_type:plan.name,duration_min:{Minimum:15,Normal:30,Stark:45}[action.intensity],status:'done',note:'Mobiler Trainingsplan',created_at:stamp,updated_at:stamp,workout_intensity:action.intensity,pain_reported:0});
   for(const [index,e] of exercises.entries()){
    const id=randomUUID(),completed=action.completed.includes(index);
    t.workout_exercises.push({id,session_id:sessionID,exercise_name:text(e.name,200),sort_order:index,is_completed:completed?1:0,pain_reported:0,note:null,created_at:stamp,updated_at:stamp});
    if(!Number.isInteger(e.sets)||e.sets<1||e.sets>20)throw new Error('Ungültiger Übungsplan.');
    if(completed)for(let set=1;set<=e.sets;set++)t.workout_sets.push({id:randomUUID(),exercise_id:id,set_number:set,reps:e.reps??null,weight_kg:null,duration_sec:e.seconds??null,rpe:null,pain_reported:0,note:null,created_at:stamp,updated_at:stamp});
   }
   break;
  }
  case 'budget': {
   const settings=t.app_settings[0];if(!settings)throw new Error('Bitte zuerst die Mac-App verbinden, um die Grundeinstellungen zu übernehmen.');
   settings.monthly_budget=number(action.amount,0,100000);settings.updated_at=stamp;break;
  }
  case 'fixedCost': {
   const due=Math.round(number(action.day,1,31));
   t.finance_fixed_costs.push({id:randomUUID(),title:text(action.title,200),amount:number(action.amount,.01,1e8),currency:'EUR',category:text(action.category||'Sonstiges',100),due_day:due,is_active:1,note:null,created_at:stamp,updated_at:stamp});break;
  }
  case 'savingsGoal': {
   t.finance_savings_goals.push({id:randomUUID(),title:text(action.title,200),target_amount:number(action.target,.01,1e8),current_amount:number(action.current,0,1e8),currency:'EUR',target_date:null,is_active:1,note:null,created_at:stamp,updated_at:stamp});break;
  }
  case 'categoryBudget': {
   const category=text(action.category,100),month=dayKey(now).slice(0,7),amount=number(action.amount,0,100000);
   const row=t.finance_category_budgets.find(r=>r.month_key===month&&r.category===category);
   if(row){row.budget_amount=amount;row.updated_at=stamp;}else t.finance_category_budgets.push({id:randomUUID(),month_key:month,category,budget_amount:amount,currency:'EUR',created_at:stamp,updated_at:stamp});break;
  }
  case 'toggleFixedCost': {
   const row=t.finance_fixed_costs.find(r=>r.id===action.id);if(!row)throw new Error('Fixkosten nicht gefunden.');row.is_active=row.is_active?0:1;row.updated_at=stamp;break;
  }
  case 'review': {
   const session=d.calendar.sessions.find(s=>s.id===action.id&&s.status==='planned');
   const topic=d.calendar.topics.find(t=>t.id===session?.topicID);
   if(!session||!topic)throw new Error('Dieser Lernblock ist nicht mehr offen. Bitte aktualisieren.');
   if(!['again','hard','good','easy'].includes(action.rating))throw new Error('Ungültige Bewertung.');
   const minutes=number(action.minutes,5,180);if(!Number.isInteger(minutes))throw new Error('Ganze Minuten eingeben.');
   if(topic.automaticTask?.phase==='followUp'&&swiftTime(now)<topic.automaticTask.lastLesson)throw new Error('Nacharbeit erst nach den Uni-Veranstaltungen abschließen.');
   Object.assign(session,{status:'completed',rating:action.rating,actualMinutes:minutes,reviewedAt:swiftTime(now),start:swiftTime(now)-minutes*60,end:swiftTime(now),reason:'Unterwegs bewertet.'});
   if(topic.automaticTask)topic.archived=true;
   else {
    if(action.rating==='again'){topic.intervalDays=1;topic.ease=Math.max(1.3,topic.ease-.3);}
    if(action.rating==='hard'){topic.intervalDays=Math.max(1,topic.intervalDays*.8);topic.ease=Math.max(1.3,topic.ease-.15);}
    if(action.rating==='good')topic.intervalDays=topic.reviewCount===0?2:Math.max(1,topic.intervalDays*topic.ease);
    if(action.rating==='easy'){topic.intervalDays=topic.reviewCount===0?4:Math.max(3,topic.intervalDays*(topic.ease+.4));topic.ease=Math.min(3,topic.ease+.15);}
    topic.intervalDays=Math.min(topic.intervalDays,90);topic.reviewCount++;topic.actualDurations=[...topic.actualDurations,minutes].slice(-5);
    // Add calendar days, retaining local time across daylight-saving changes.
    const zone=d.calendar.preferences.timeZoneID;
    const parts=value=>Object.fromEntries(new Intl.DateTimeFormat('en-CA',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).formatToParts(value).filter(x=>x.type!=='literal').map(x=>[x.type,Number(x.value)]));
    const p=parts(now);const target=Date.UTC(p.year,p.month-1,p.day+Math.round(topic.intervalDays),p.hour,p.minute,p.second);let value=target;
    for(let i=0;i<3;i++){const q=parts(new Date(value));value+=target-Date.UTC(q.year,q.month-1,q.day,q.hour,q.minute,q.second);}
    topic.nextReview=swiftTime(new Date(value));
   }
   break;
  }
  case 'weeklyReview': {
   const key=action.week;if(!validDay(key))throw new Error('Ungültige Woche.');
   const row=t.weekly_reviews.find(r=>r.week_start_date===key);
   const optional=v=>v?text(v,5000):'';
   const next={id:row?.id??randomUUID(),week_start_date:key,wins_text:optional(action.wins),challenges_text:optional(action.challenges),next_week_focus_text:optional(action.focus),rating:Math.round(number(action.rating,1,5)),created_at:row?.created_at??stamp,updated_at:stamp};
   if(row)Object.assign(row,next);else t.weekly_reviews.push(next);break;
  }
  case 'newsPreferences': {
   const p=action.preferences;if(!p||!Array.isArray(p.enabledSources)||!p.enabledSources.every(x=>['world','tech','science','sport'].includes(x))||!Array.isArray(p.read)||!Array.isArray(p.saved)||[...p.read,...p.saved].some(x=>typeof x!=='string'||x.length>4096)||typeof p.excludedWords!=='string'||p.excludedWords.length>2000)throw new Error('Ungültige News-Filter.');
   const payload=JSON.stringify(p);if(payload.length>500000)throw new Error('Merkliste zu groß.');t.news_state=[{id:'main',payload}];break;
  }
  case 'deleteExpense':
   if(!t.finance_entries.some(x=>x.id===action.id))throw new Error('Eintrag nicht gefunden.');
   t.finance_entries=t.finance_entries.filter(x=>x.id!==action.id);break;
  default:throw new Error('Unbekannte Aktion.');
 }
 return validateDocument(d);
}
