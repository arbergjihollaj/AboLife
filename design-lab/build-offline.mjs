// Creates a dependency-free, directly openable gallery with real embedded prototypes.
import {readFile,writeFile} from 'node:fs/promises';
const dir=new URL('./',import.meta.url);
const read=file=>readFile(new URL(file,dir),'utf8');
const data=(await read('public/data.js')).replaceAll('export ','')+'\nconst h=escapeHTML;';
const preferences=(await read('public/preferences.js')).replaceAll('export ','');
const compositions=(await Promise.all('abcde'.split('').map(id=>read(`public/concepts/${id}.js`)))).join('\n').replaceAll('export ','');
let prototype=preferences+'\n'+compositions+'\n'+(await read('public/prototype.js')).replace(/^import .*;\n/gm,'').replace('new URLSearchParams(location.search)','new URLSearchParams(window.LAB_PARAMS)');
const css=[await read('public/prototype.css'),...await Promise.all('abcde'.split('').map(id=>read(`public/concepts/${id}.css`))),await read('public/personal.css'),await read('public/responsive.css')].join('\n');
const prototypeHTML=`<!doctype html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>${css}</style></head><body><div id="prototype"></div><dialog id="entry-dialog"></dialog><div id="toast" role="status" aria-live="polite"></div><script>window.LAB_PARAMS=__LAB_PARAMS__;</script><script type="module">${data}\n${prototype}</script></body></html>`;
const lab=(await read('public/lab.js')).replace(/^import .*;\n/,'');
const html=`<!doctype html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>UI Design Lab · AboLife · Offline</title><style>${await read('public/lab.css')}</style></head><body><a class="skip" href="#main">Zum Inhalt</a><div id="app"></div><div id="notice" role="status" aria-live="polite"></div><script>window.LAB_OFFLINE=true;window.LAB_PROTOTYPE=${JSON.stringify(prototypeHTML).replaceAll('<','\\u003c')};</script><script type="module">${data}\n${lab}</script></body></html>`;
await writeFile(new URL('UI-Design-Lab.html',dir),html);
console.log('Offline gallery built: design-lab/UI-Design-Lab.html');
