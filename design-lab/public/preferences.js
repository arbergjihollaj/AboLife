// Local presentation preferences only. Never stores finance, training or review entries.
export const preferenceKey = 'abolife.design-lab.personal.v1';
export const themeIds = ['b', 'd', 'e'];
export const widgetIds = ['finance', 'training', 'habits', 'calendar'];
export function normalizePreferences(value) {
  const raw = value && typeof value === 'object' ? value : {};
  const order = Array.isArray(raw.widgets) ? raw.widgets : [];
  return {
    theme: themeIds.includes(raw.theme) ? raw.theme : 'b',
    accent: ['default', 'blue', 'violet', 'amber'].includes(raw.accent) ? raw.accent : 'default',
    widgets: [...new Set([...order.filter(id => widgetIds.includes(id)), ...widgetIds])]
  };
}
export function readPreferences(storage) {
  const raw = storage.getItem(preferenceKey);
  return normalizePreferences(raw ? JSON.parse(raw) : {});
}
export function moveWidget(order, from, to) {
  const next = [...order];
  if (!next.includes(from) || !next.includes(to) || from === to) return next;
  const targetIndex = next.indexOf(to);
  next.splice(next.indexOf(from), 1);
  next.splice(targetIndex, 0, from);
  return next;
}
export function paletteFor(theme, accent) {
  const colors = theme === 'b'
    ? { blue: '#9edbff', violet: '#d3b5ff', amber: '#ffce89' }
    : { blue: '#285c99', violet: '#6b4298', amber: '#87561d' };
  return { accent: colors[accent] || '', ink: theme === 'b' ? '#102c28' : '#ffffff' };
}
