// A: isolated dashboard composition. Shared data keeps the comparison fair.
export function renderA({ core, parts, card, financeWidget, trainingWidget, habitsWidget, timeline, ring, progress, btn, go, data }) {
  return `<section class="native-hero">${core}${ring(progress())}</section><div class="native-grid">${parts.finance}${parts.training}${parts.habits}${parts.calendar}</div>`;
}
