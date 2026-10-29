import {DatabaseSync,backup} from 'node:sqlite';
import {mkdirSync,readdirSync,unlinkSync,chmodSync} from 'node:fs';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
export async function backupDatabase(db,destination){
 mkdirSync(destination,{recursive:true,mode:0o700});
 const file=join(destination,'AboLife-'+new Date().toISOString().replace(/[:.]/g,'-')+'.sqlite');
 await backup(db,file);chmodSync(file,0o600);
 const files=readdirSync(destination).filter(f=>/^AboLife-.*\.sqlite$/.test(f)).sort().reverse();
 for(const old of files.slice(30))unlinkSync(join(destination,old));
 return file;
}
if(process.argv[1]&&fileURLToPath(import.meta.url)===process.argv[1]){
 const root=process.env.ABOLIFE_DATA_DIR??'/app/data';
 const db=new DatabaseSync(join(root,'AboLife-Shared.sqlite'),{readOnly:true});
 try{console.log('Konsistente SQLite-Sicherung: '+await backupDatabase(db,join(root,'backups')));}finally{db.close();}
}
