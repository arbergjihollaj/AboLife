// D: isolated dashboard composition. Shared data keeps the comparison fair.
export function renderD({ core, parts, card, financeWidget, trainingWidget, habitsWidget, timeline, ring, progress, btn, go, data, personal }) {
  return `<div class="board-heading"><div><span class="eyebrow">DEIN PERSÖNLICHER WORKSPACE</span><h1>Heute, auf deine Art.</h1></div>${personal?go('Widgets konfigurieren','settings','secondary'):btn('⇄ Widgets umsortieren','reorder','secondary')}</div><div class="bento-grid"><section class="panel bento-core">${ring(progress())}<div><h2>Ein guter Anfang.</h2><p>Dein Tagesstatus wächst mit jeder kleinen Aktion.</p>${btn('+ Schnellerfassung','add','primary')}</div></section>${data.widgets.map(id=>parts[id]).join('')}</div>`;
}
