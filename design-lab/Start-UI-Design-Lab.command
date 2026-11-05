#!/bin/zsh
# User launcher. Runs only the isolated lab, never the production app.
cd -- "${0:A:h}" || exit 1
if ! command -v node >/dev/null 2>&1; then
  print 'Node.js 24+ fehlt. Alternativ UI-Design-Lab.html per Doppelklick öffnen.'
  read '?Enter zum Schließen …'
  exit 1
fi
print 'Öffne nach dem Start http://127.0.0.1:4177 im Browser.'
print 'Beenden mit Ctrl+C. Feedback bleibt im Design-Lab gespeichert.'
node server.mjs
