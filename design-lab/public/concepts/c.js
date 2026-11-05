// C: isolated dashboard composition. Shared data keeps the comparison fair.
export function renderC({ core, parts, card, financeWidget, trainingWidget, habitsWidget, timeline, ring, progress, btn, go, data }) {
  return `<div class="editorial-hero">${core}<div class="issue-number">05<span>NOV / 2026</span></div></div><div class="editorial-summary"><span>TAGESFORTSCHRITT</span><strong>${progress()}%</strong><p>Routinen, die sich summieren.</p></div><div class="editorial-columns">${card('01 — Dein Spielraum',financeWidget())}${card('02 — In Bewegung',trainingWidget())}${card('03 — Der Tagesplan',timeline())}${card('04 — Wiederholung zählt',habitsWidget())}</div>`;
}
