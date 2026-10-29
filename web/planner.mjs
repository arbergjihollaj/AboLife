import {spawn} from 'node:child_process';
export function createPlanner(binary=process.env.ABOLIFE_PLANNER_BINARY){
 if(!binary)return null;
 return calendar=>new Promise((resolve,reject)=>{
  const child=spawn(binary,[],{stdio:['pipe','pipe','pipe'],env:{...process.env,TZ:'Europe/Berlin'}});
  const chunks=[];let size=0,done=false;
  const timer=setTimeout(()=>{child.kill();finish(Error('Die Lernplanung hat zu lange gedauert.'));},10000);
  function finish(error,value){if(done)return;done=true;clearTimeout(timer);error?reject(error):resolve(value);}
  child.on('error',()=>finish(Error('Lernplaner nicht verfügbar. Serverkonfiguration prüfen.')));
  child.stdin.on('error',()=>{});child.stderr.resume();
  child.stdout.on('data',part=>{size+=part.length;if(size>8_000_000){child.kill();finish(Error('Lernplan zu groß.'));}else chunks.push(part);});
  child.on('close',code=>{if(code!==0)return finish(Error('Lernplanung fehlgeschlagen. Die Änderung wurde nicht gespeichert.'));try{const value=JSON.parse(Buffer.concat(chunks));if(!value.calendar)throw Error();finish(null,value);}catch{finish(Error('Lernplaner hat ungültige Daten geliefert.'));}});
  child.stdin.end(JSON.stringify({calendar}));
 });
}
