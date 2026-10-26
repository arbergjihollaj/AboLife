#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');

const root = path.resolve(__dirname, '..');
const docsDir = path.join(root, 'docs');

const dotPath = path.join(docsDir, 'AboLife_File_Node_Graph.dot');
const svgPath = path.join(docsDir, 'AboLife_File_Node_Graph.svg');
const htmlPath = path.join(docsDir, 'AboLife_File_Node_Graph_Interactive.html');
const reportPath = path.join(docsDir, 'AboLife_File_Node_Graph_Audit.md');

const generatedFiles = new Set([
  'docs/AboLife_File_Node_Graph.dot',
  'docs/AboLife_File_Node_Graph.svg',
  'docs/AboLife_File_Node_Graph_Interactive.html',
  'docs/AboLife_File_Node_Graph_Audit.md'
]);

const textExtensions = new Set([
  '.swift',
  '.md',
  '.txt',
  '.html',
  '.xml',
  '.plist',
  '.pbxproj',
  '.xcworkspacedata',
  '.resolved',
  '.json'
]);

const groupColors = {
  Features: '#2f8f5f',
  Persistence: '#c94f4f',
  Telegram: '#2878b8',
  ExternalInput: '#8757c7',
  DesignSystem: '#d9822b',
  Charts: '#1f9bb4',
  Shared: '#4b6f95',
  Tests: '#72a84f',
  Docs: '#8a8a8a',
  XcodeProject: '#b8b8b8',
  ProjectFiles: '#6f6f6f',
  Design: '#ad5fb8',
  Sonstiges: '#555555'
};

const distortingGroups = new Set(['Docs', 'ProjectFiles', 'XcodeProject', 'Tests']);
const expectedWatchList = [
  'AppDatabase.swift',
  'DashboardStore.swift',
  'DateIntervals.swift',
  'HtmlSnapshotExportService.swift',
  'BackupService.swift',
  'DailySummaryService.swift',
  'ExternalInputService.swift',
  'AppRouter.swift',
  'TelegramPollingController.swift'
];
const dailyLogicTerms = [
  'daySummary',
  'DateIntervals.day',
  'DateIntervals.week',
  'daily',
  'Daily',
  'today',
  'Today',
  'selectedDate',
  'weekInterval',
  'Calendar'
];
const dailyRiskPathTerms = [
  'Dashboard',
  'DailySummary',
  'HtmlSnapshot',
  'Backup',
  'WeeklyReview',
  'DateIntervals',
  'AppDatabase'
];

function run(command, args) {
  return childProcess.execFileSync(command, args, {
    cwd: root,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe']
  });
}

function listFiles() {
  return run('rg', ['--files'])
    .trim()
    .split(/\n/)
    .filter(Boolean)
    .filter(file => !generatedFiles.has(file))
    .sort((a, b) => a.localeCompare(b));
}

function isTextFile(file) {
  const ext = path.extname(file);
  return textExtensions.has(ext) || file.endsWith('project.pbxproj') || file.endsWith('.xcscheme');
}

function readText(file) {
  if (!isTextFile(file)) return '';
  try {
    return fs.readFileSync(path.join(root, file), 'utf8');
  } catch {
    return '';
  }
}

function groupForFile(file) {
  if (file.startsWith('AboLife/Features/')) return 'Features';
  if (file.startsWith('AboLife/Persistence/')) return 'Persistence';
  if (file.startsWith('AboLife/Telegram/')) return 'Telegram';
  if (file.startsWith('AboLife/ExternalInput/')) return 'ExternalInput';
  if (file.startsWith('AboLife/DesignSystem/')) return 'DesignSystem';
  if (file.startsWith('AboLife/Charts/')) return 'Charts';
  if (file.startsWith('AboLife/PreviewSupport/')) return 'Shared';
  if (file.startsWith('AboLifeTests/')) return 'Tests';
  if (file.startsWith('docs/') || file.startsWith('plan/')) return 'Docs';
  if (file.startsWith('Design/')) return 'Design';
  if (file.startsWith('AboLife.xcodeproj/')) return 'XcodeProject';
  if (['README.md', 'TODO.md', 'CHANGELOG.md', '.gitignore'].includes(file)) return 'ProjectFiles';
  return 'Sonstiges';
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function dotQuote(value) {
  return `"${String(value)
    .replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n')}"`;
}

function htmlEscape(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function extractSymbols(file, text) {
  if (!file.endsWith('.swift')) return [];
  const symbols = [];
  const re = /\b(?:final\s+)?(?:class|struct|enum|protocol|actor)\s+([A-Z_][A-Za-z0-9_]*)/g;
  let match;
  while ((match = re.exec(text))) {
    if (!['View', 'CodingKeys'].includes(match[1])) {
      symbols.push(match[1]);
    }
  }
  return symbols;
}

function lineCount(text) {
  if (!text) return 0;
  return text.split(/\r?\n/).length;
}

function addEdge(edges, source, target, reason, direction = 'symbol') {
  if (!source || !target || source === target) return;
  const key = `${source}\u0000${target}`;
  if (!edges.has(key)) {
    edges.set(key, { source, target, reasons: new Set(), direction });
  }
  edges.get(key).reasons.add(reason);
}

function buildGraph() {
  const files = listFiles();
  const contents = new Map(files.map(file => [file, readText(file)]));
  const symbolOwner = new Map();
  const symbolsByFile = new Map();

  for (const file of files) {
    const symbols = extractSymbols(file, contents.get(file) || '');
    symbolsByFile.set(file, symbols);
    for (const symbol of symbols) {
      if (!symbolOwner.has(symbol)) symbolOwner.set(symbol, file);
    }
  }

  const edges = new Map();
  for (const file of files) {
    const text = contents.get(file) || '';
    if (!text) continue;

    if (file.endsWith('.swift')) {
      for (const [symbol, owner] of symbolOwner) {
        if (owner === file) continue;
        if (new RegExp(`\\b${escapeRegExp(symbol)}\\b`).test(text)) {
          addEdge(edges, file, owner, symbol);
        }
      }
    }

    if (/\.(md|html|pbxproj|xcscheme|plist|resolved|xcworkspacedata)$/.test(file) || ['README.md', 'TODO.md'].includes(file)) {
      for (const target of files) {
        if (target === file) continue;
        const base = path.basename(target);
        const stem = base.replace(/\.[^.]+$/, '');
        if (text.includes(base) || (stem.length > 5 && new RegExp(`\\b${escapeRegExp(stem)}\\b`).test(text))) {
          addEdge(edges, file, target, 'mentions file', 'mention');
        }
      }
    }
  }

  const nodeMap = new Map();
  for (const file of files) {
    const text = contents.get(file) || '';
    nodeMap.set(file, {
      id: file,
      label: path.basename(file),
      path: file,
      group: groupForFile(file),
      symbols: symbolsByFile.get(file) || [],
      lineCount: lineCount(text),
      isText: Boolean(text),
      isProjectFile: groupForFile(file) === 'ProjectFiles' || groupForFile(file) === 'XcodeProject',
      isDoc: groupForFile(file) === 'Docs',
      isTest: groupForFile(file) === 'Tests',
      outgoing: 0,
      incoming: 0,
      degree: 0,
      neighbors: [],
      warnings: []
    });
  }

  const edgeList = Array.from(edges.values()).map(edge => ({
    source: edge.source,
    target: edge.target,
    reasons: Array.from(edge.reasons).sort(),
    direction: edge.direction
  }));

  for (const edge of edgeList) {
    const source = nodeMap.get(edge.source);
    const target = nodeMap.get(edge.target);
    if (!source || !target) continue;
    source.outgoing += 1;
    target.incoming += 1;
    source.neighbors.push(edge.target);
    target.neighbors.push(edge.source);
  }

  for (const node of nodeMap.values()) {
    node.neighbors = Array.from(new Set(node.neighbors)).sort();
    node.degree = node.incoming + node.outgoing;
  }

  const nodes = Array.from(nodeMap.values()).sort((a, b) => a.path.localeCompare(b.path));
  const stats = buildStats(nodes, edgeList);
  const audits = buildAudits(nodes, edgeList, contents);

  return { nodes, edges: edgeList, stats, audits };
}

function top(nodes, key, count = 20) {
  return [...nodes]
    .sort((a, b) => b[key] - a[key] || a.path.localeCompare(b.path))
    .slice(0, count);
}

function buildStats(nodes, edges) {
  const groupCounts = {};
  for (const node of nodes) {
    groupCounts[node.group] = (groupCounts[node.group] || 0) + 1;
  }
  return {
    totalFiles: nodes.length,
    totalConnections: edges.length,
    groupCounts,
    central: top(nodes, 'degree'),
    outgoing: top(nodes, 'outgoing'),
    incoming: top(nodes, 'incoming'),
    isolated: nodes.filter(node => node.degree === 0),
    possibleGodFiles: nodes
      .filter(node => !distortingGroups.has(node.group))
      .filter(node => node.lineCount >= 450 || node.degree >= 35)
      .sort((a, b) => b.degree - a.degree || b.lineCount - a.lineCount)
  };
}

function buildAudits(nodes, edges, contents) {
  const audits = [];
  const centralThreshold = Math.max(18, Math.ceil(percentile(nodes.map(node => node.degree), 0.9)));
  const outgoingThreshold = Math.max(12, Math.ceil(percentile(nodes.map(node => node.outgoing), 0.9)));
  const incomingThreshold = Math.max(12, Math.ceil(percentile(nodes.map(node => node.incoming), 0.9)));

  for (const node of nodes) {
    const isDistorting = distortingGroups.has(node.group);
    const basename = path.basename(node.path);
    if (!isDistorting && (node.degree >= centralThreshold || expectedWatchList.includes(basename))) {
      addAudit(audits, node, 'Zentrale Datei beobachten', 'warning',
        `${basename} hat ${node.degree} Verbindungen (${node.outgoing} ausgehend, ${node.incoming} eingehend).`);
    }
    if (!isDistorting && (node.lineCount >= 450 || (node.degree >= centralThreshold && node.lineCount >= 250))) {
      addAudit(audits, node, 'Potentielles God-File', 'warning',
        `${basename} kombiniert ${node.lineCount} Zeilen mit ${node.degree} Verbindungen. Verantwortlichkeiten prüfen.`);
    }
    if (!isDistorting && node.path.endsWith('View.swift') && node.degree >= Math.max(14, outgoingThreshold)) {
      addAudit(audits, node, 'UI-Datei mit vielen Abhängigkeiten', 'warning',
        `${basename} ist eine View mit ${node.degree} direkten Verbindungen. UI-Logik und Datenzugriff trennen prüfen.`);
    }
    if (!isDistorting && /Service\.swift$/.test(node.path) && node.degree >= Math.max(12, outgoingThreshold)) {
      addAudit(audits, node, 'Service verbindet viele Bereiche', 'warning',
        `${basename} ist ein Service mit ${node.degree} Verbindungen. Fachliche Verantwortlichkeiten abgrenzen prüfen.`);
    }
    if (!isDistorting && node.incoming >= incomingThreshold && !['DesignSystem', 'Charts', 'Persistence'].includes(node.group)) {
      addAudit(audits, node, 'Hohe eingehende Kopplung', 'info',
        `${basename} wird von vielen Dateien referenziert (${node.incoming} eingehend). API-Stabilität beachten.`);
    }
  }

  const dailyCandidates = nodes.filter(node => {
    const text = contents.get(node.path) || '';
    const basename = path.basename(node.path);
    return dailyRiskPathTerms.some(term => node.path.includes(term) || basename.includes(term))
      && dailyLogicTerms.some(term => text.includes(term));
  });

  if (dailyCandidates.length >= 4) {
    audits.push({
      severity: 'warning',
      title: 'Doppelte Tageslogik möglich',
      node: null,
      message: `${dailyCandidates.length} Dateien berechnen oder aggregieren wahrscheinlich Tages-/Statuslogik. Eine read-only Snapshot-Schicht wie TodaySnapshotService oder DailyOverviewService sollte geprüft werden.`,
      files: dailyCandidates.map(node => node.path).sort()
    });
  }

  const crossAreaServices = nodes.filter(node => /Service\.swift$/.test(node.path)).map(node => {
    const neighborGroups = new Set(node.neighbors.map(path => nodes.find(candidate => candidate.path === path)?.group).filter(Boolean));
    return { node, neighborGroups };
  }).filter(item => item.neighborGroups.size >= 3);

  for (const item of crossAreaServices) {
    addAudit(audits, item.node, 'Service koppelt mehrere Bereiche', 'info',
      `${path.basename(item.node.path)} verbindet ${item.neighborGroups.size} Bereiche: ${Array.from(item.neighborGroups).sort().join(', ')}.`);
  }

  const auditByPath = new Map();
  for (const audit of audits) {
    if (!audit.node) continue;
    const node = nodes.find(candidate => candidate.path === audit.node);
    if (!node) continue;
    if (!auditByPath.has(node.path)) auditByPath.set(node.path, []);
    auditByPath.get(node.path).push(`${audit.title}: ${audit.message}`);
  }
  for (const node of nodes) {
    node.warnings = auditByPath.get(node.path) || [];
  }

  return audits.sort((a, b) => severityRank(b.severity) - severityRank(a.severity) || a.title.localeCompare(b.title));
}

function addAudit(audits, node, title, severity, message) {
  audits.push({ severity, title, node: node.path, message, files: [node.path] });
}

function severityRank(severity) {
  return { info: 1, warning: 2, critical: 3 }[severity] || 0;
}

function percentile(values, p) {
  const sorted = values.filter(Number.isFinite).sort((a, b) => a - b);
  if (sorted.length === 0) return 0;
  const index = Math.min(sorted.length - 1, Math.floor(sorted.length * p));
  return sorted[index];
}

function writeDot(graph) {
  let dot = `graph G {\n`;
  dot += `  graph [layout=sfdp, overlap=false, splines=true, bgcolor="#fbfaf7", pad=0.35, outputorder=edgesfirst, label="AboLife Datei-Node-Graph - generiert am 2026-06-16\\nNodes: ${graph.nodes.length} Dateien, Kanten: ${graph.edges.length} erkannte Verbindungen", labelloc=t, fontsize=24, fontname="Helvetica"];\n`;
  dot += `  node [shape=box, style="rounded,filled", penwidth=1.2, color="#404040", fontname="Helvetica", fontsize=10, margin=0.08];\n`;
  dot += `  edge [color="#6f6f6f55", penwidth=0.8];\n`;
  for (const node of graph.nodes) {
    const id = dotNodeId(node.path);
    const font = ['Docs', 'XcodeProject', 'ProjectFiles', 'Tests'].includes(node.group) ? '#111111' : '#ffffff';
    const label = node.label.length > 24 ? `${node.label.slice(0, 21)}...` : node.label;
    const tooltip = `${node.path}${node.symbols.length ? `\nDefines: ${node.symbols.slice(0, 12).join(', ')}` : ''}`;
    dot += `  ${id} [label=${dotQuote(label)}, fillcolor=${dotQuote(groupColors[node.group] || groupColors.Sonstiges)}, fontcolor=${dotQuote(font)}, tooltip=${dotQuote(tooltip)}, href=${dotQuote(node.path)}];\n`;
  }
  for (const edge of graph.edges) {
    dot += `  ${dotNodeId(edge.source)} -- ${dotNodeId(edge.target)} [tooltip=${dotQuote(edge.reasons.slice(0, 6).join(', '))}];\n`;
  }
  Object.entries(groupColors).forEach(([group, color], index) => {
    const font = ['Docs', 'XcodeProject', 'ProjectFiles', 'Tests'].includes(group) ? '#111111' : '#ffffff';
    dot += `  legend_${index} [label=${dotQuote(group)}, fillcolor=${dotQuote(color)}, fontcolor=${dotQuote(font)}, shape=box, style="rounded,filled", tooltip=${dotQuote(`Legende: ${group}`)}];\n`;
    if (index > 0) dot += `  legend_${index - 1} -- legend_${index} [style=invis];\n`;
  });
  dot += `}\n`;
  fs.writeFileSync(dotPath, dot, 'utf8');
}

function dotNodeId(value) {
  return `n${Buffer.from(value).toString('base64').replace(/[^A-Za-z0-9_]/g, '_')}`;
}

function writeSvg() {
  try {
    childProcess.execFileSync('sfdp', ['-Tsvg', dotPath, '-o', svgPath], { cwd: root, stdio: 'pipe' });
  } catch (error) {
    console.warn('Graphviz sfdp nicht verfügbar oder fehlgeschlagen; SVG wurde nicht neu gerendert.');
  }
}

function writeHtml(graph) {
  const data = {
    generatedAt: '2026-06-16',
    groups: groupColors,
    distortingGroups: Array.from(distortingGroups),
    nodes: graph.nodes,
    edges: graph.edges,
    stats: graph.stats,
    audits: graph.audits
  };
  const embeddedData = JSON.stringify(data).replace(/</g, '\\u003c');
  const html = `<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AboLife Architektur Node-Graph</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f7f6f2;
      --panel: #ffffff;
      --line: #d8d5cc;
      --text: #242424;
      --muted: #696969;
      --accent: #2457a6;
      --warning: #a35d00;
    }
    * { box-sizing: border-box; }
    html { height: 100%; }
    body { margin: 0; height: 100vh; overflow: hidden; background: var(--bg); color: var(--text); font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    header { display: grid; grid-template-columns: 1fr auto; gap: 16px; align-items: end; padding: 18px 22px 12px; border-bottom: 1px solid var(--line); background: #fbfaf7; }
    h1 { margin: 0; font-size: 22px; line-height: 1.2; letter-spacing: 0; }
    .subtitle { margin-top: 4px; color: var(--muted); font-size: 13px; }
    .layout { display: grid; grid-template-columns: minmax(300px, 390px) 1fr minmax(300px, 380px); height: calc(100vh - 76px); min-height: 0; }
    aside { overflow: auto; border-right: 1px solid var(--line); background: var(--panel); }
    aside.right { border-right: 0; border-left: 1px solid var(--line); }
    main { position: relative; min-width: 0; min-height: 0; height: 100%; overflow: hidden; }
    section { padding: 14px 16px; border-bottom: 1px solid var(--line); }
    h2 { margin: 0 0 10px; font-size: 13px; text-transform: uppercase; letter-spacing: .06em; color: #4f4f4f; }
    .stats-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px; }
    .metric { padding: 9px; border: 1px solid var(--line); border-radius: 8px; background: #fbfaf7; }
    .metric strong { display: block; font-size: 20px; }
    .metric span { color: var(--muted); font-size: 12px; }
    label { display: flex; align-items: center; gap: 8px; margin: 7px 0; font-size: 13px; }
    input[type="search"] { width: 100%; padding: 9px 10px; border: 1px solid var(--line); border-radius: 8px; font-size: 14px; }
    button { border: 1px solid var(--line); background: #fff; border-radius: 8px; padding: 7px 10px; color: var(--text); cursor: pointer; }
    button:hover { border-color: #9d9a91; }
    .legend-row, .list-row, .audit-row { display: grid; grid-template-columns: auto 1fr auto; gap: 8px; align-items: center; padding: 5px 0; font-size: 12px; }
    .dot { width: 11px; height: 11px; border-radius: 50%; border: 1px solid rgba(0,0,0,.25); }
    .list-row { grid-template-columns: 1fr auto; border-bottom: 1px solid #ece9e0; cursor: pointer; }
    .list-row:hover { color: var(--accent); }
    .audit-row { grid-template-columns: 1fr; border-bottom: 1px solid #ece9e0; align-items: start; }
    .audit-title { font-weight: 700; font-size: 12px; }
    .audit-message { color: var(--muted); font-size: 12px; line-height: 1.35; }
    .warn { color: var(--warning); }
    #graph { width: 100%; height: 100%; display: block; background: #fbfaf7; cursor: grab; }
    #graph:active { cursor: grabbing; }
    .edge { stroke: rgba(70,70,70,.14); stroke-width: 1; }
    .edge.highlight { stroke: rgba(36,87,166,.85); stroke-width: 2.4; }
    .node circle { stroke: rgba(0,0,0,.3); stroke-width: 1.2; }
    .node text { font-size: 10px; fill: #222; paint-order: stroke; stroke: rgba(251,250,247,.92); stroke-width: 3px; stroke-linejoin: round; pointer-events: none; }
    .group-node text { font-size: 14px; font-weight: 700; }
    .node.dim { opacity: .16; }
    .edge.dim { opacity: .08; }
    .node.selected circle { stroke: #111; stroke-width: 3; }
    .node.search-hit circle { stroke: #f2c94c; stroke-width: 4; }
    .graph-toolbar { position: absolute; top: 12px; left: 12px; display: flex; flex-wrap: wrap; gap: 6px; max-width: calc(100% - 24px); padding: 6px; background: rgba(255,255,255,.92); border: 1px solid var(--line); border-radius: 8px; }
    .graph-toolbar button.active { background: #242424; color: #fff; border-color: #242424; }
    .details-path { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px; word-break: break-all; }
    .neighbors { max-height: 220px; overflow: auto; border: 1px solid var(--line); border-radius: 8px; padding: 6px; }
    .neighbor { display: block; width: 100%; text-align: left; border: 0; border-radius: 4px; padding: 4px; font-size: 12px; background: transparent; }
    .neighbor:hover { background: #f1efe8; }
    @media (max-width: 1100px) {
      .layout { grid-template-columns: 320px 1fr; }
      body { overflow: auto; }
      .layout { grid-template-columns: 320px 1fr; height: auto; min-height: calc(100vh - 76px); }
      main { min-height: 520px; }
      aside.right { grid-column: 1 / -1; min-height: 360px; border-left: 0; border-top: 1px solid var(--line); }
    }
  </style>
</head>
<body>
  <header>
    <div>
      <h1>AboLife Architektur Node-Graph</h1>
      <div class="subtitle">Interaktiver Struktur-Export mit Suche, Filtern, Node-Details und Audit-Hinweisen. Enthält nur Pfade, Dateinamen und Architektur-Metadaten.</div>
    </div>
    <button id="resetView">Ansicht zurücksetzen</button>
  </header>
  <div class="layout">
    <aside>
      <section>
        <h2>Suche</h2>
        <input id="search" type="search" placeholder="Dateiname oder Pfad suchen">
      </section>
      <section>
        <h2>Filter</h2>
        <label><input id="showProject" type="checkbox"> Projektdateien anzeigen</label>
        <label><input id="showDocs" type="checkbox"> Docs anzeigen</label>
        <label><input id="showTests" type="checkbox"> Tests anzeigen</label>
        <div id="groupFilters"></div>
      </section>
      <section>
        <h2>Statistik</h2>
        <div class="stats-grid">
          <div class="metric"><strong id="fileCount"></strong><span>Dateien sichtbar</span></div>
          <div class="metric"><strong id="edgeCount"></strong><span>Verbindungen sichtbar</span></div>
          <div class="metric"><strong>${graph.stats.totalFiles}</strong><span>Dateien gesamt</span></div>
          <div class="metric"><strong>${graph.stats.totalConnections}</strong><span>Verbindungen gesamt</span></div>
        </div>
      </section>
      <section>
        <h2>Legende</h2>
        <div id="legend"></div>
      </section>
      <section>
        <h2>Top Zentral</h2>
        <div id="centralList"></div>
      </section>
    </aside>
    <main>
      <div class="graph-toolbar">
        <button id="modeGroups" class="active">Bereiche</button>
        <button id="modeFiles">Dateien</button>
        <button id="zoomIn">+</button>
        <button id="zoomOut">-</button>
        <button id="fitView">Fit</button>
        <button id="toggleLabels">Labels</button>
        <button id="toggleEdges" class="active">Kanten</button>
      </div>
      <svg id="graph" role="img" aria-label="AboLife Datei Node Graph"></svg>
    </main>
    <aside class="right">
      <section>
        <h2>Node Details</h2>
        <div id="details">Wähle einen Node aus.</div>
      </section>
      <section>
        <h2>Audit</h2>
        <div id="audit"></div>
      </section>
      <section>
        <h2>Weitere Listen</h2>
        <h2>Top Ausgehend</h2>
        <div id="outgoingList"></div>
        <h2 style="margin-top:14px">Top Eingehend</h2>
        <div id="incomingList"></div>
        <h2 style="margin-top:14px">Isoliert</h2>
        <div id="isolatedList"></div>
      </section>
    </aside>
  </div>
  <script id="graph-data" type="application/json">${embeddedData}</script>
  <script>
    const data = JSON.parse(document.getElementById('graph-data').textContent);
    const svg = document.getElementById('graph');
    const state = {
      scale: 1,
      tx: 0,
      ty: 0,
      selected: null,
      selectedGroup: null,
      search: '',
      mode: 'groups',
      showLabels: false,
      showEdges: true,
      filters: new Set(Object.keys(data.groups)),
      showProject: false,
      showDocs: false,
      showTests: false
    };
    const nodeById = new Map(data.nodes.map(node => [node.id, { ...node }]));
    const links = data.edges.map(edge => ({ ...edge, sourceNode: nodeById.get(edge.source), targetNode: nodeById.get(edge.target) }));
    const visibleGroups = new Set(Object.keys(data.groups));
    const groupGraph = buildGroupGraph();
    const width = () => svg.clientWidth || 900;
    const height = () => svg.clientHeight || 700;

    function buildGroupGraph() {
      const groups = Object.keys(data.groups).map(group => ({
        id: group,
        label: group,
        group,
        degree: 0,
        count: data.stats.groupCounts[group] || 0,
        topFiles: data.nodes.filter(node => node.group === group).sort((a, b) => b.degree - a.degree || a.path.localeCompare(b.path)).slice(0, 10)
      }));
      const byId = new Map(groups.map(group => [group.id, group]));
      const edgeMap = new Map();
      for (const edge of data.edges) {
        const source = nodeById.get(edge.source);
        const target = nodeById.get(edge.target);
        if (!source || !target || source.group === target.group) continue;
        const key = [source.group, target.group].sort().join('::');
        edgeMap.set(key, (edgeMap.get(key) || 0) + 1);
      }
      const groupEdges = Array.from(edgeMap.entries()).map(([key, count]) => {
        const [source, target] = key.split('::');
        byId.get(source).degree += count;
        byId.get(target).degree += count;
        return { source, target, count, sourceNode: byId.get(source), targetNode: byId.get(target) };
      });
      return { nodes: groups, edges: groupEdges, byId };
    }

    function initPositions() {
      const groups = Object.keys(data.groups);
      data.nodes.forEach((node, index) => {
        const angle = (groups.indexOf(node.group) / Math.max(1, groups.length)) * Math.PI * 2;
        const ring = 140 + (index % 17) * 16;
        const item = nodeById.get(node.id);
        item.x = width() / 2 + Math.cos(angle) * ring + ((index % 5) - 2) * 24;
        item.y = height() / 2 + Math.sin(angle) * ring + ((index % 7) - 3) * 18;
        item.vx = 0;
        item.vy = 0;
      });
    }

    function simulate(iterations = 280) {
      const nodes = Array.from(nodeById.values());
      const groups = Object.keys(data.groups);
      for (let step = 0; step < iterations; step += 1) {
        for (let i = 0; i < nodes.length; i += 1) {
          for (let j = i + 1; j < nodes.length; j += 1) {
            const a = nodes[i], b = nodes[j];
            let dx = a.x - b.x, dy = a.y - b.y;
            let d2 = dx * dx + dy * dy || 1;
            const force = 720 / d2;
            a.vx += dx * force; a.vy += dy * force;
            b.vx -= dx * force; b.vy -= dy * force;
          }
        }
        for (const link of links) {
          const a = link.sourceNode, b = link.targetNode;
          if (!a || !b) continue;
          const dx = b.x - a.x, dy = b.y - a.y;
          const d = Math.sqrt(dx * dx + dy * dy) || 1;
          const desired = 95 + Math.min(70, (a.degree + b.degree) * 1.2);
          const force = (d - desired) * 0.012;
          const fx = dx / d * force, fy = dy / d * force;
          a.vx += fx; a.vy += fy; b.vx -= fx; b.vy -= fy;
        }
        for (const node of nodes) {
          const groupIndex = groups.indexOf(node.group);
          const angle = (groupIndex / Math.max(1, groups.length)) * Math.PI * 2;
          const gx = width() / 2 + Math.cos(angle) * Math.min(width(), height()) * 0.28;
          const gy = height() / 2 + Math.sin(angle) * Math.min(width(), height()) * 0.28;
          node.vx += (gx - node.x) * 0.002;
          node.vy += (gy - node.y) * 0.002;
          node.x += node.vx;
          node.y += node.vy;
          node.vx *= 0.82;
          node.vy *= 0.82;
        }
      }
    }

    function normalizeLayout() {
      const nodes = Array.from(nodeById.values());
      const minX = Math.min(...nodes.map(node => node.x));
      const maxX = Math.max(...nodes.map(node => node.x));
      const minY = Math.min(...nodes.map(node => node.y));
      const maxY = Math.max(...nodes.map(node => node.y));
      const currentWidth = Math.max(1, maxX - minX);
      const currentHeight = Math.max(1, maxY - minY);
      const targetWidth = Math.max(760, width() * 1.35);
      const targetHeight = Math.max(620, height() * 1.15);
      const scale = Math.min(targetWidth / currentWidth, targetHeight / currentHeight);
      const centerX = (minX + maxX) / 2;
      const centerY = (minY + maxY) / 2;
      for (const node of nodes) {
        node.x = (node.x - centerX) * scale + width() / 2;
        node.y = (node.y - centerY) * scale + height() / 2;
        node.vx = 0;
        node.vy = 0;
      }
    }

    function shouldShow(node) {
      if (!visibleGroups.has(node.group)) return false;
      if (!state.showProject && (node.group === 'ProjectFiles' || node.group === 'XcodeProject')) return false;
      if (!state.showDocs && node.group === 'Docs') return false;
      if (!state.showTests && node.group === 'Tests') return false;
      return true;
    }

    function render() {
      syncToolbar();
      if (state.mode === 'groups') {
        renderGroupGraph();
        return;
      }
      const visibleNodes = Array.from(nodeById.values()).filter(shouldShow);
      const visibleNodeIds = new Set(visibleNodes.map(node => node.id));
      const visibleLinks = links.filter(link => visibleNodeIds.has(link.source) && visibleNodeIds.has(link.target));
      document.getElementById('fileCount').textContent = visibleNodes.length;
      document.getElementById('edgeCount').textContent = visibleLinks.length;

      svg.setAttribute('viewBox', \`0 0 \${width()} \${height()}\`);
      svg.innerHTML = '';
      const viewport = makeSvg('g', { transform: \`translate(\${state.tx} \${state.ty}) scale(\${state.scale})\` });
      svg.appendChild(viewport);

      const selected = state.selected ? nodeById.get(state.selected) : null;
      const selectedNeighbors = selected ? new Set(selected.neighbors) : new Set();
      const search = state.search.toLowerCase().trim();
      if (state.showEdges) {
        for (const link of visibleLinks) {
          const isRelated = selected && (link.source === selected.id || link.target === selected.id);
          const line = makeSvg('line', {
            x1: link.sourceNode.x, y1: link.sourceNode.y,
            x2: link.targetNode.x, y2: link.targetNode.y,
            class: \`edge \${selected && !isRelated ? 'dim' : ''} \${isRelated ? 'highlight' : ''}\`
          });
          viewport.appendChild(line);
        }
      }

      for (const node of visibleNodes) {
        const isSelected = selected && selected.id === node.id;
        const isNeighbor = selectedNeighbors.has(node.id);
        const isDim = selected && !isSelected && !isNeighbor;
        const isSearchHit = search && node.path.toLowerCase().includes(search);
        const g = makeSvg('g', {
          class: \`node \${isSelected ? 'selected' : ''} \${isDim ? 'dim' : ''} \${isSearchHit ? 'search-hit' : ''}\`,
          transform: \`translate(\${node.x} \${node.y})\`,
          tabindex: '0'
        });
        const radius = 5 + Math.min(18, Math.sqrt(Math.max(1, node.degree)) * 2.2);
        g.appendChild(makeSvg('circle', { r: radius, fill: data.groups[node.group] || '#555' }));
        const label = makeSvg('text', { x: radius + 4, y: 4 });
        label.textContent = node.label;
        label.style.display = state.showLabels || state.scale >= 1.05 || isSelected || isSearchHit ? 'block' : 'none';
        g.appendChild(label);
        g.addEventListener('click', event => {
          event.stopPropagation();
          selectNode(node.id);
        });
        viewport.appendChild(g);
      }
    }

    function renderGroupGraph() {
      const visibleGroupNodes = groupGraph.nodes.filter(group => shouldShowGroup(group.id));
      const visibleGroupIds = new Set(visibleGroupNodes.map(group => group.id));
      const visibleGroupEdges = groupGraph.edges.filter(edge => visibleGroupIds.has(edge.source) && visibleGroupIds.has(edge.target));
      document.getElementById('fileCount').textContent = visibleGroupNodes.reduce((sum, group) => sum + group.count, 0);
      document.getElementById('edgeCount').textContent = visibleGroupEdges.reduce((sum, edge) => sum + edge.count, 0);

      const cx = width() / 2;
      const cy = height() / 2;
      const radius = Math.max(150, Math.min(width(), height()) * 0.35);
      visibleGroupNodes.forEach((group, index) => {
        const angle = -Math.PI / 2 + (index / Math.max(1, visibleGroupNodes.length)) * Math.PI * 2;
        group.x = cx + Math.cos(angle) * radius;
        group.y = cy + Math.sin(angle) * radius;
      });

      svg.setAttribute('viewBox', \`0 0 \${width()} \${height()}\`);
      svg.innerHTML = '';
      const viewport = makeSvg('g', { transform: \`translate(\${state.tx} \${state.ty}) scale(\${state.scale})\` });
      svg.appendChild(viewport);

      if (state.showEdges) {
        for (const edge of visibleGroupEdges) {
          const line = makeSvg('line', {
            x1: edge.sourceNode.x, y1: edge.sourceNode.y,
            x2: edge.targetNode.x, y2: edge.targetNode.y,
            class: \`edge \${state.selectedGroup && edge.source !== state.selectedGroup && edge.target !== state.selectedGroup ? 'dim' : ''}\`,
            'stroke-width': Math.min(8, 1 + Math.sqrt(edge.count))
          });
          viewport.appendChild(line);
        }
      }

      for (const group of visibleGroupNodes) {
        const isSelected = state.selectedGroup === group.id;
        const g = makeSvg('g', {
          class: \`node group-node \${isSelected ? 'selected' : ''}\`,
          transform: \`translate(\${group.x} \${group.y})\`,
          tabindex: '0'
        });
        const r = 18 + Math.min(34, Math.sqrt(group.count) * 5);
        g.appendChild(makeSvg('circle', { r, fill: data.groups[group.id] || '#555' }));
        const label = makeSvg('text', { x: r + 8, y: -2 });
        label.textContent = group.label;
        g.appendChild(label);
        const sub = makeSvg('text', { x: r + 8, y: 15 });
        sub.textContent = \`\${group.count} Dateien\`;
        sub.setAttribute('style', 'font-size:11px;font-weight:500;');
        g.appendChild(sub);
        g.addEventListener('click', event => {
          event.stopPropagation();
          selectGroup(group.id);
        });
        viewport.appendChild(g);
      }
    }

    function shouldShowGroup(group) {
      if (!visibleGroups.has(group)) return false;
      if (!state.showProject && (group === 'ProjectFiles' || group === 'XcodeProject')) return false;
      if (!state.showDocs && group === 'Docs') return false;
      if (!state.showTests && group === 'Tests') return false;
      return true;
    }

    function makeSvg(tag, attrs) {
      const el = document.createElementNS('http://www.w3.org/2000/svg', tag);
      for (const [key, value] of Object.entries(attrs || {})) {
        el.setAttribute(key, value);
      }
      return el;
    }

    function selectNode(id) {
      state.mode = 'files';
      state.selected = id;
      state.selectedGroup = null;
      renderDetails();
      render();
    }

    function selectGroup(id) {
      state.selectedGroup = id;
      state.selected = null;
      renderGroupDetails(id);
      render();
    }

    function renderDetails() {
      const panel = document.getElementById('details');
      if (state.mode === 'groups' && state.selectedGroup) {
        renderGroupDetails(state.selectedGroup);
        return;
      }
      if (!state.selected) {
        panel.innerHTML = state.mode === 'groups' ? 'Wähle einen Bereich aus.' : 'Wähle einen Node aus.';
        return;
      }
      const node = nodeById.get(state.selected);
      const warnings = node.warnings.length ? node.warnings.map(w => \`<li>\${escapeHtml(w)}</li>\`).join('') : '<li>Keine Warnhinweise.</li>';
      const neighbors = node.neighbors.map(id => nodeById.get(id)).filter(Boolean)
        .sort((a, b) => b.degree - a.degree || a.path.localeCompare(b.path))
        .map(neighbor => \`<button class="neighbor" data-id="\${escapeHtml(neighbor.id)}">\${escapeHtml(neighbor.path)} <strong>\${neighbor.degree}</strong></button>\`).join('');
      panel.innerHTML = \`
        <div class="details-path">\${escapeHtml(node.path)}</div>
        <p><strong>Gruppe:</strong> \${escapeHtml(node.group)}</p>
        <p><strong>Verbindungen:</strong> \${node.degree} gesamt, \${node.outgoing} ausgehend, \${node.incoming} eingehend</p>
        <p><strong>Zeilen:</strong> \${node.lineCount || 'n/a'}</p>
        <p><strong>Symbole:</strong> \${escapeHtml(node.symbols.slice(0, 12).join(', ') || 'keine erkannt')}</p>
        <p><strong>Warnhinweise:</strong></p>
        <ul>\${warnings}</ul>
        <p><strong>Direkte Nachbarn:</strong></p>
        <div class="neighbors">\${neighbors || 'Keine Nachbarn.'}</div>
      \`;
      panel.querySelectorAll('.neighbor').forEach(button => {
        button.addEventListener('click', () => selectNode(button.dataset.id));
      });
    }

    function renderGroupDetails(id) {
      const panel = document.getElementById('details');
      const group = groupGraph.byId.get(id);
      if (!group) return;
      const topFiles = group.topFiles.map(file => \`
        <button class="neighbor" data-id="\${escapeHtml(file.id)}">\${escapeHtml(file.path)} <strong>\${file.degree}</strong></button>
      \`).join('');
      const relatedAudits = data.audits.filter(item => item.files?.some(file => nodeById.get(file)?.group === id)).slice(0, 8);
      panel.innerHTML = \`
        <p><strong>Bereich:</strong> \${escapeHtml(group.label)}</p>
        <p><strong>Dateien:</strong> \${group.count}</p>
        <p><strong>Bereichsverbindungen:</strong> \${group.degree}</p>
        <p><strong>Zentrale Dateien:</strong></p>
        <div class="neighbors">\${topFiles || 'Keine Dateien.'}</div>
        <p><strong>Audit-Hinweise:</strong></p>
        <ul>\${relatedAudits.length ? relatedAudits.map(item => \`<li>\${escapeHtml(item.title)}</li>\`).join('') : '<li>Keine Hinweise für diesen Bereich.</li>'}</ul>
      \`;
      panel.querySelectorAll('.neighbor').forEach(button => {
        button.addEventListener('click', () => selectNode(button.dataset.id));
      });
    }

    function renderLists() {
      renderList('centralList', data.stats.central, 'degree');
      renderList('outgoingList', data.stats.outgoing, 'outgoing');
      renderList('incomingList', data.stats.incoming, 'incoming');
      renderList('isolatedList', data.stats.isolated.slice(0, 30), 'degree');
      const legend = document.getElementById('legend');
      legend.innerHTML = Object.entries(data.groups).map(([group, color]) => \`
        <div class="legend-row"><span class="dot" style="background:\${color}"></span><span>\${escapeHtml(group)}</span><strong>\${data.stats.groupCounts[group] || 0}</strong></div>
      \`).join('');
      const groupFilters = document.getElementById('groupFilters');
      groupFilters.innerHTML = Object.keys(data.groups).map(group => \`
        <label><input type="checkbox" data-group="\${escapeHtml(group)}" checked> \${escapeHtml(group)}</label>
      \`).join('');
      groupFilters.querySelectorAll('input').forEach(input => {
        input.addEventListener('change', () => {
          if (input.checked) visibleGroups.add(input.dataset.group);
          else visibleGroups.delete(input.dataset.group);
          render();
        });
      });
      const audit = document.getElementById('audit');
      audit.innerHTML = data.audits.map(item => \`
        <div class="audit-row">
          <div class="audit-title \${item.severity === 'warning' ? 'warn' : ''}">\${escapeHtml(item.title)}</div>
          <div class="audit-message">\${escapeHtml(item.message)}</div>
          \${item.node ? \`<button data-id="\${escapeHtml(item.node)}">\${escapeHtml(item.node)}</button>\` : ''}
        </div>
      \`).join('');
      audit.querySelectorAll('button[data-id]').forEach(button => {
        button.addEventListener('click', () => selectNode(button.dataset.id));
      });
    }

    function renderList(id, items, key) {
      const el = document.getElementById(id);
      el.innerHTML = items.map(node => \`
        <div class="list-row" data-id="\${escapeHtml(node.id)}"><span>\${escapeHtml(node.path)}</span><strong>\${node[key]}</strong></div>
      \`).join('');
      el.querySelectorAll('[data-id]').forEach(row => {
        row.addEventListener('click', () => selectNode(row.dataset.id));
      });
    }

    function escapeHtml(value) {
      return String(value).replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' }[char]));
    }

    function fitView() {
      if (state.mode === 'groups') {
        state.scale = 1;
        state.tx = 0;
        state.ty = 0;
        render();
        return;
      }
      const nodes = state.mode === 'groups'
        ? groupGraph.nodes.filter(group => shouldShowGroup(group.id))
        : Array.from(nodeById.values()).filter(shouldShow);
      if (!nodes.length) return;
      const minX = Math.min(...nodes.map(node => node.x));
      const maxX = Math.max(...nodes.map(node => node.x));
      const minY = Math.min(...nodes.map(node => node.y));
      const maxY = Math.max(...nodes.map(node => node.y));
      const pad = 70;
      const sx = width() / Math.max(1, maxX - minX + pad * 2);
      const sy = height() / Math.max(1, maxY - minY + pad * 2);
      state.scale = Math.min(1.6, Math.max(0.08, Math.min(sx, sy)));
      state.tx = width() / 2 - ((minX + maxX) / 2) * state.scale;
      state.ty = height() / 2 - ((minY + maxY) / 2) * state.scale;
      render();
    }

    function syncToolbar() {
      document.getElementById('modeGroups').classList.toggle('active', state.mode === 'groups');
      document.getElementById('modeFiles').classList.toggle('active', state.mode === 'files');
      document.getElementById('toggleLabels').classList.toggle('active', state.showLabels);
      document.getElementById('toggleEdges').classList.toggle('active', state.showEdges);
    }

    let dragging = false;
    let last = null;
    svg.addEventListener('pointerdown', event => { dragging = true; last = { x: event.clientX, y: event.clientY }; svg.setPointerCapture(event.pointerId); });
    svg.addEventListener('pointermove', event => {
      if (!dragging || !last) return;
      state.tx += event.clientX - last.x;
      state.ty += event.clientY - last.y;
      last = { x: event.clientX, y: event.clientY };
      render();
    });
    svg.addEventListener('pointerup', () => { dragging = false; last = null; });
    svg.addEventListener('click', () => { state.selected = null; renderDetails(); render(); });
    svg.addEventListener('wheel', event => {
      event.preventDefault();
      const oldScale = state.scale;
      const factor = event.deltaY < 0 ? 1.12 : 0.88;
      state.scale = Math.min(4, Math.max(0.18, state.scale * factor));
      const rect = svg.getBoundingClientRect();
      const x = event.clientX - rect.left;
      const y = event.clientY - rect.top;
      state.tx = x - (x - state.tx) * (state.scale / oldScale);
      state.ty = y - (y - state.ty) * (state.scale / oldScale);
      render();
    }, { passive: false });

    document.getElementById('search').addEventListener('input', event => {
      state.search = event.target.value;
      const query = state.search.toLowerCase().trim();
      if (query) {
        const hit = Array.from(nodeById.values()).find(node => node.path.toLowerCase().includes(query));
        if (hit) {
          state.mode = 'files';
          state.selected = hit.id;
          state.selectedGroup = null;
        }
      }
      renderDetails();
      render();
    });
    document.getElementById('showProject').addEventListener('change', event => { state.showProject = event.target.checked; render(); });
    document.getElementById('showDocs').addEventListener('change', event => { state.showDocs = event.target.checked; render(); });
    document.getElementById('showTests').addEventListener('change', event => { state.showTests = event.target.checked; render(); });
    document.getElementById('modeGroups').addEventListener('click', () => { state.mode = 'groups'; state.selected = null; fitView(); renderDetails(); });
    document.getElementById('modeFiles').addEventListener('click', () => { state.mode = 'files'; state.selectedGroup = null; fitView(); renderDetails(); });
    document.getElementById('toggleLabels').addEventListener('click', () => { state.showLabels = !state.showLabels; render(); });
    document.getElementById('toggleEdges').addEventListener('click', () => { state.showEdges = !state.showEdges; render(); });
    document.getElementById('zoomIn').addEventListener('click', () => { state.scale = Math.min(4, state.scale * 1.2); render(); });
    document.getElementById('zoomOut').addEventListener('click', () => { state.scale = Math.max(0.18, state.scale / 1.2); render(); });
    document.getElementById('fitView').addEventListener('click', fitView);
    document.getElementById('resetView').addEventListener('click', () => { state.selected = null; state.selectedGroup = null; fitView(); renderDetails(); });

    initPositions();
    simulate();
    normalizeLayout();
    renderLists();
    document.getElementById('showProject').checked = state.showProject;
    document.getElementById('showDocs').checked = state.showDocs;
    document.getElementById('showTests').checked = state.showTests;
    fitView();
    renderDetails();
  </script>
</body>
</html>`;
  fs.writeFileSync(htmlPath, html, 'utf8');
}

function writeReport(graph) {
  const lines = [];
  lines.push('# AboLife Datei-Node-Graph Audit');
  lines.push('');
  lines.push('Generiert am 2026-06-16 aus Strukturinformationen im Repository. Der Export enthält nur Dateipfade, Dateinamen, erkannte Symbolverweise und Architektur-Metadaten; keine App-Daten, Tokens, Chat-IDs, Finanzdaten, Mahlzeiten, Gewichte oder Backup-Inhalte.');
  lines.push('');
  lines.push('## Zusammenfassung');
  lines.push('');
  lines.push(`- Dateien: ${graph.stats.totalFiles}`);
  lines.push(`- Erkannte Verbindungen: ${graph.stats.totalConnections}`);
  lines.push(`- Isolierte Dateien: ${graph.stats.isolated.length}`);
  lines.push(`- Mögliche God-Files: ${graph.stats.possibleGodFiles.length}`);
  lines.push(`- Audit-Warnungen/Hinweise: ${graph.audits.length}`);
  lines.push('');
  lines.push('## Gruppenübersicht');
  lines.push('');
  for (const [group, count] of Object.entries(graph.stats.groupCounts).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))) {
    lines.push(`- ${group}: ${count}`);
  }
  lines.push('');
  lines.push('## Top 20 zentrale Dateien');
  lines.push('');
  addTable(lines, graph.stats.central, 'degree');
  lines.push('');
  lines.push('## Top 20 ausgehende Verbindungen');
  lines.push('');
  addTable(lines, graph.stats.outgoing, 'outgoing');
  lines.push('');
  lines.push('## Top 20 eingehende Verbindungen');
  lines.push('');
  addTable(lines, graph.stats.incoming, 'incoming');
  lines.push('');
  lines.push('## Isolierte Dateien');
  lines.push('');
  if (graph.stats.isolated.length) {
    for (const node of graph.stats.isolated) lines.push(`- ${node.path}`);
  } else {
    lines.push('- Keine isolierten Dateien erkannt.');
  }
  lines.push('');
  lines.push('## Risiken');
  lines.push('');
  for (const audit of graph.audits) {
    lines.push(`- **${audit.title}** (${audit.severity}): ${audit.message}`);
    if (audit.node) lines.push(`  Datei: \`${audit.node}\``);
    else if (audit.files?.length) lines.push(`  Dateien: ${audit.files.map(file => `\`${file}\``).join(', ')}`);
  }
  lines.push('');
  lines.push('## Empfehlung: zentrale Tageszustands-Schicht prüfen');
  lines.push('');
  lines.push('Der Graph legt nahe, dass Dashboard, Telegram-Zusammenfassung, HTML-Export, Backup/Export, WeeklyReview und DateIntervals an mehreren Stellen Tages-, Wochen- und Statuswerte zusammensetzen. Das ist aktuell nicht automatisch falsch, kann aber mittelfristig zu abweichenden Berechnungen für Kalorien, Protein, Budget, Habits, Training und Gewicht führen.');
  lines.push('');
  lines.push('Empfohlen ist eine read-only Snapshot-Schicht, zum Beispiel `TodaySnapshotService` oder `DailyOverviewService`. Diese Schicht sollte keine neue Persistenz einführen, sondern vorhandene Repositories bündeln und ein konsistentes Tagesmodell liefern: Datum, Kalorien gegessen, Kalorienziel, Kalorien übrig, Protein gegessen, Proteinziel, Budget heute, Ausgaben heute, Budget übrig, Training geplant/erledigt, Habits erledigt/offen, Gewicht, Erinnerungen und kurze Tagesbewertung.');
  lines.push('');
  lines.push('Sinnvoller Einstieg: zuerst ein kleines read-only DTO plus Tests für die bestehenden Berechnungen ergänzen, danach Dashboard, Telegram Daily Summary und HTML Snapshot schrittweise darauf umstellen.');
  lines.push('');
  lines.push('## Konkrete nächste Refactor-Schritte');
  lines.push('');
  lines.push('- `DailyOverviewService` oder `TodaySnapshotService` als read-only Aggregator skizzieren, ohne UI und ohne Telegram-Abhängigkeit.');
  lines.push('- Bestehende Berechnungen in `DashboardStore`, `DailySummaryService`, `HtmlSnapshotExportService` und `WeeklyReviewStore` vergleichen und Testfälle für gleiche Tagesdaten ergänzen.');
  lines.push('- `DateIntervals` als zentrale Kalender-/Intervall-Hilfe behalten, aber fachliche Tagesbewertung nicht dort hineinziehen.');
  lines.push('- Services mit vielen Bereichsverbindungen darauf prüfen, ob sie Infrastruktur oder Fachlogik mischen.');
  lines.push('- Views mit hoher Kopplung schrittweise über kleinere Store-APIs oder Snapshot-Modelle entlasten.');
  lines.push('');
  lines.push('## Bewusst nicht automatisch riskant');
  lines.push('');
  lines.push('- `AppDatabase.swift` darf viele Verbindungen haben, weil es als Infrastruktur-Wurzel und Environment-Brücke fungiert. Risiko entsteht erst, wenn dort fachliche Tageslogik landet.');
  lines.push('- `DesignSystem`- und `Charts`-Dateien können viele eingehende Verbindungen haben, weil sie bewusst wiederverwendbare UI-Bausteine sind.');
  lines.push('- Projektdateien, Dokumentation und Tests sind im interaktiven Graph standardmäßig ausblendbar, weil sie Architekturmetriken verzerren können.');
  lines.push('');
  lines.push('## Artefakte');
  lines.push('');
  lines.push('- Interaktiver HTML-Graph: `docs/AboLife_File_Node_Graph_Interactive.html`');
  lines.push('- DOT-Quelle: `docs/AboLife_File_Node_Graph.dot`');
  lines.push('- SVG-Export: `docs/AboLife_File_Node_Graph.svg`');
  fs.writeFileSync(reportPath, `${lines.join('\n')}\n`, 'utf8');
}

function addTable(lines, nodes, metric) {
  lines.push('| Datei | Gruppe | Gesamt | Ausgehend | Eingehend | Zeilen |');
  lines.push('| --- | --- | ---: | ---: | ---: | ---: |');
  for (const node of nodes) {
    lines.push(`| \`${node.path}\` | ${node.group} | ${node.degree} | ${node.outgoing} | ${node.incoming} | ${node.lineCount || 0} |`);
  }
}

function main() {
  fs.mkdirSync(docsDir, { recursive: true });
  const graph = buildGraph();
  writeDot(graph);
  writeSvg();
  writeHtml(graph);
  writeReport(graph);
  console.log(JSON.stringify({
    dotPath,
    svgPath,
    htmlPath,
    reportPath,
    files: graph.nodes.length,
    edges: graph.edges.length,
    audits: graph.audits.length
  }, null, 2));
}

main();
