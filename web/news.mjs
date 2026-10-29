export const SOURCES = [
 {id:'world',title:'tagesschau',category:'Welt',url:'https://www.tagesschau.de/index~rss2.xml'},
 {id:'tech',title:'heise',category:'Technik',url:'https://www.heise.de/rss/heise-atom.xml'},
 {id:'science',title:'tagesschau Wissen',category:'Wissen',url:'https://www.tagesschau.de/wissen/index~rss2.xml'},
 {id:'sport',title:'Sportschau',category:'Sport',url:'https://www.sportschau.de/index~rss2.xml'}
];
function decode(text) { return text.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g,'$1').replace(/<[^>]*>/g,'').replace(/&#(x[0-9a-f]+|\d+);/gi,(_,n)=>{const c=n[0].toLowerCase()==='x'?parseInt(n.slice(1),16):Number(n);return c<=0x10ffff?String.fromCodePoint(c):'';}).replace(/&(amp|lt|gt|quot|apos);/g,(_,n)=>({amp:'&',lt:'<',gt:'>',quot:'"',apos:"'"}[n])).trim(); }
export function parseFeed(xml,source) {
 if(Buffer.byteLength(xml)>2_000_000)throw new Error('Feed zu groß.');
 if(!/<(?:rss|feed|rdf:RDF)\b/i.test(xml))throw new Error('Kein RSS/Atom-Feed.');
 const items=[];
 for(const match of xml.matchAll(/<(item|entry)\b[^>]*>([\s\S]*?)<\/\1>/gi)) {
  const body=match[2];const field=name=>body.match(new RegExp(`<${name}\\b[^>]*>([\\s\\S]*?)<\\/${name}>`,'i'))?.[1]??'';
  const title=decode(field('title'));const raw=decode(field('link'))||body.match(/<link\b(?=[^>]*\bhref=["']([^"']+)["'])(?![^>]*\brel=["'](?:self|enclosure)["'])[^>]*>/i)?.[1];
  let url;try{url=new URL(raw);if(!['https:','http:'].includes(url.protocol))continue;}catch{continue;}
  const date=new Date(decode(field('pubDate')||field('published')||field('updated')||field('dc:date')));
  if(title)items.push({id:url.href,title,url:url.href,source:source.title,sourceID:source.id,category:source.category,publishedAt:Number.isFinite(+date)?date.toISOString():null});
 }
 return items;
}
export function deduplicate(items) { const ids=new Set(),titles=new Set();return items.toSorted((a,b)=>(Date.parse(b.publishedAt)||0)-(Date.parse(a.publishedAt)||0)).filter(a=>{const title=a.title.normalize('NFKC').toLocaleLowerCase('de');if(ids.has(a.id)||titles.has(title))return false;ids.add(a.id);titles.add(title);return true;}); }
export async function fetchNews(fetcher=fetch) {
 const results=await Promise.allSettled(SOURCES.map(async source=>{
  const response=await fetcher(source.url,{signal:AbortSignal.timeout(12000),headers:{'User-Agent':'AboLife/0.3 private RSS reader'}});
  if(!response.ok)throw new Error(source.title);
  const reader=response.body.getReader();let length=0;const chunks=[];
  try{while(true){const {done,value}=await reader.read();if(done)break;length+=value.length;if(length>2_000_000){await reader.cancel();throw new Error('Feed zu groß.');}chunks.push(value);}}finally{reader.releaseLock();}
  return parseFeed(Buffer.concat(chunks).toString('utf8'),source);
 }));
 return {articles:deduplicate(results.flatMap(r=>r.status==='fulfilled'?r.value:[])),failed:results.flatMap((r,i)=>r.status==='rejected'?[SOURCES[i].title]:[]),updatedAt:new Date().toISOString()};
}
