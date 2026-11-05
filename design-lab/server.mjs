import http from 'node:http';
import { readFile, writeFile, mkdir, rename } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.dirname(fileURLToPath(import.meta.url));
const ids = ['a', 'b', 'c', 'd', 'e', 'f'];
const aspects = ['Farben', 'Navigation', 'Layout', 'Typografie', 'Animationen', 'Benutzerfreundlichkeit'];
const fields = ['likes', 'dislikes', 'keep', 'ideas'];
export function validateFeedback(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw Error('Ungültiges Feedback');
  const result = {};
  for (const id of ids) {
    const item = value[id] || {};
    const score = v => v === null || v === undefined ? null : Number.isInteger(v) && v >= 1 && v <= 10 ? v : (() => { throw Error('Bewertung muss zwischen 1 und 10 liegen'); })();
    result[id] = { score: score(item.score), aspects: {}, favorites: [] };
    for (const field of fields) {
      if (item[field] !== undefined && (typeof item[field] !== 'string' || item[field].length > 12000)) throw Error('Text ist zu lang oder ungültig');
      result[id][field] = item[field] || '';
    }
    for (const aspect of aspects) result[id].aspects[aspect] = score(item.aspects?.[aspect]);
    if (item.favorites !== undefined && (!Array.isArray(item.favorites) || item.favorites.some(x => ![...aspects, 'Dashboard'].includes(x)))) throw Error('Ungültige Favoriten');
    result[id].favorites = [...new Set(item.favorites || [])];
  }
  return result;
}
export function feedbackMarkdown(data) {
  return '# UI Design Lab – Design-Feedback\n\nStand: ' + new Date().toISOString() + '\n\nNur Konzeptbewertung. Keine Freigabe für eine Änderung der produktiven App.\n\n' + ids.map(id => {
    const f = data[id];
    return `## Design ${id.toUpperCase()}\n\nBewertung: ${f.score ?? 'Noch offen'}/10\n\n` + fields.map((key, i) => `### ${['Das gefällt mir', 'Das gefällt mir nicht', 'Diese Elemente möchte ich übernehmen', 'Meine Verbesserungsideen'][i]}\n\n${f[key] || 'Noch offen'}\n`).join('\n') + '\n' + aspects.map(a => `- ${a}: ${f.aspects[a] ?? 'offen'}/10`).join('\n') + '\n\nFavoriten: ' + (f.favorites.join(', ') || 'Noch keine') + '\n';
  }).join('\n');
}
export function createLabServer({ dataDir = path.join(root, '.local'), reportPath = path.join(root, 'DESIGN_FEEDBACK.md') } = {}) {
  let queue = Promise.resolve();
  const file = path.join(dataDir, 'feedback.json');
  async function load() {
    try { return validateFeedback(JSON.parse(await readFile(file, 'utf8'))); }
    catch (error) { if (error.code === 'ENOENT') return validateFeedback({}); throw error; }
  }
  async function save(data) {
    await mkdir(dataDir, { recursive: true });
    await writeFile(file + '.tmp', JSON.stringify(data, null, 2));
    await rename(file + '.tmp', file);
    await writeFile(reportPath + '.tmp', feedbackMarkdown(data));
    await rename(reportPath + '.tmp', reportPath);
  }
  return http.createServer(async (req, res) => {
    const send = (status, body, type = 'application/json') => { res.writeHead(status, { 'Content-Type': type + '; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', 'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; frame-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'self'" }); res.end(body); };
    try {
      const url = new URL(req.url, 'http://localhost');
      if (url.pathname === '/api/feedback') {
        if (req.method === 'GET') { await queue; return send(200, JSON.stringify(await load())); }
        if (req.method !== 'PUT') return send(405, '{}');
        // Browser mutations must originate from this loopback app, never another website.
        if (req.headers.origin !== `http://${req.headers.host}` || req.headers['content-type'] !== 'application/json') return send(403, '{}');
        let body = '';
        for await (const chunk of req) { body += chunk; if (Buffer.byteLength(body) > 280000) return send(413, '{}'); }
        let data;
        try { data = validateFeedback(JSON.parse(body)); } catch { return send(400, JSON.stringify({ error: 'Feedback ist ungültig.' })); }
        const task = queue.then(() => save(data));
        queue = task.catch(() => {});
        await task;
        return send(200, JSON.stringify({ saved: true }));
      }
      if (req.method !== 'GET') return send(405, '{}');
      const relative = decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname);
      const target = path.resolve(root, 'public', '.' + relative);
      if (!target.startsWith(path.join(root, 'public') + path.sep)) return send(404, '{}');
      const types = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.svg': 'image/svg+xml' };
      if (!types[path.extname(target)]) return send(404, '{}');
      try { return send(200, await readFile(target), types[path.extname(target)]); }
      catch (error) { if (error.code === 'ENOENT') return send(404, '{}'); throw error; }
    } catch { send(500, JSON.stringify({ error: 'Speichern oder Laden fehlgeschlagen. Bitte erneut versuchen.' })); }
  });
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const port = Number(process.env.LAB_PORT || 4177);
  const server = createLabServer();
  server.on('error', error => {
    console.error(`UI Design Lab konnte nicht starten (${error.code}). Bitte im eigenen Terminal starten oder UI-Design-Lab.html öffnen.`);
    process.exitCode = 1;
  });
  server.listen(port, '127.0.0.1', () => console.log(`UI Design Lab: http://127.0.0.1:${port}`));
}
