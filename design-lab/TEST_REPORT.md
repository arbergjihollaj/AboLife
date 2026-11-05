# Prüfung des UI Design Lab

Stand: 5. November 2026.

## Erfolgreich

`npm test --prefix design-lab`: **19 Tests bestanden, 0 Fehler, 0 übersprungen.** Node.js v26.3.0.

- Persistenz von Bewertungen, Einzelaspekten, Freitexten und Favoriten über eine neue Serverinstanz hinweg.
- Markdown wird aus tatsächlich gespeichertem Feedback erzeugt.
- Ungültige JSON-Daten, Noten, zu lange Texte und fremde Origins werden abgewiesen.
- Gleichzeitige Schreibvorgänge werden serialisiert; JSON und Markdown entsprechen dem letzten Snapshot.
- Alle statischen Quellassets erreichbar; Speicherdateien und Pfadüberschreitungen nicht öffentlich zugänglich.
- Beschädigte Feedbackdatei führt zu einem sichtbaren Fehler statt zu einem leeren Ersatzstand.
- Alle sechs Konzeptkompositionen und alle zehn Screens ausgeführt: 60 Renderkombinationen mit eigenen Navigationsstrukturen.
- Demo-Ausgabe aktualisiert Restbudget; Wasser und Trainingsabschluss aktualisieren State; Reset stellt die gemeinsame Fixture wieder her.
- Review-Entwürfe überleben interne Navigation; Nachrichten können gemerkt werden.
- Offlinegalerie enthält sechs echte eingebettete Prototypen, Vergleich für fünf Designs und Browserpersistenz.
- Freitext wird HTML-escaped. Keine produktive Datenbank und kein externer Dienst in den Runtimequellen.
- Tagesfortschritt bleibt auch bei übertroffenen Habit-Zielen auf 100 % begrenzt.
- Beide Hauptscripts und beide eingebetteten Prototypscripts des Offlineartefakts syntaktisch geprüft; keine extern nachzuladenden Skript-/Stylesheetdateien im eingebetteten Prototyp.

Zusätzlich erfolgreich: `node --check` für Server, Galerie, Prototyp und Offlinebuilder; `zsh -n` für den Startlauncher. Offlineartefakt aus den aktuellen Quellen neu gebaut.

## Prüfmethode und Grenzen

Die Tests verwenden ausschließlich temporäre Verzeichnisse und fiktive Werte. Serverrouten wurden direkt über HTTP-Request-/Response-Testobjekte angesprochen. Render- und Interaktionstests führen die tatsächlichen JavaScriptmodule in isolierten VM-Kontexten mit minimalen DOM-Testobjekten aus. Das prüft State, Stringrendering und Handler; es ist **kein echter Browserlauf** und ersetzt keine visuelle Kontrolle, reale Eingabefokustests oder eine vollständige Accessibility-/Performanceabnahme.

`npm start --prefix design-lab` wurde versucht. Der lokale Listen-Aufruf scheiterte an der Ausführungssandbox: `listen EPERM 127.0.0.1:4177`. Der Server wurde deshalb nicht als erfolgreich laufend abgenommen. Die anschließende Öffnung der Offline-HTML im integrierten Browser wurde durch dessen URL-Sicherheitsregel abgewiesen: nur http/https, keine file-URLs. Es wurde kein anderer Browserweg zur Umgehung verwendet. Kein Serverprozess bleibt von diesem Versuch zurück.

**Offene grafische Abnahme:** Galerie im eigenen Browser öffnen; alle fünf Hauptansichten bei 1000 px und 390 px anschauen; Vergleich in 2er- und 5er-Auswahl; Ausgabenformular und Review mit Tastatur bedienen; Escape und Fokus; lange Feedbacktexte; Reduced Motion; Speichern und erneutes Laden. Animationen und tatsächliche Bildschirmdarstellung sind implementiert, aber in dieser Sitzung nicht visuell bestätigt.

## Abgrenzung

Alle eigenen Schreiboperationen liegen in `design-lab`. Vorheriger Branch und vorhandene Änderungen wurden erfasst; kein Reset, Staging, Commit oder Push. Während der Arbeit änderten sich außerdem die bereits vorhandenen Diffs von `README.md` und `scripts/check-ui.sh` außerhalb dieses Auftrags; diese Dateien wurden von dieser Umsetzung nicht beschrieben und nicht zurückgesetzt.

Xcode-/SwiftPM-/native UI-Tests wurden nicht ausgeführt: Die produktive App, Projektkonfiguration, Datenmodelle und Fachlogik wurden für dieses Lab nicht geändert. Es gibt keine Aussage zu einem Remote-CI-Erfolg.


## Nachprüfung: personalisiertes Konzept F

Zusätzlich erfolgreich geprüft: B/D/E-Wechsel erhält aktive Seite, Ausgabe und Review-Entwurf; Darstellung und Farbe bleiben über erneutes Öffnen erhalten. Gesperrter Browserspeicher führt zu sichtbarem Fehler ohne falsche Speicherbestätigung. Widgetverschiebung funktioniert in beide Richtungen, über Drop-Handler und nach erneutem Öffnen. Altfeedback bleibt erhalten und F-Feedback wird zusätzlich serverseitig gespeichert. Keine produktiven Swift-Dateien verändert. Kein erneuter Versuch, die dokumentierten Vorschaugrenzen zu umgehen.


## Nachprüfung: vorhandenen KI-Assistenten im Design berücksichtigen

Drei weitere automatisierte Tests erfolgreich: Zugang in B/D/E auf allen zehn Bereichen; leere Standardfreigaben und explizite Kontextvorschau; Draft bleibt beim Wechsel der Designs erhalten; vorbereitete Antwort als Demo gekennzeichnet; Aktionsvorschlag ohne Freigabe/Bestätigung wirkungslos, Ablehnen schreibt nichts, bestätigter Vorschlag ändert ausschließlich den flüchtigen Demo-Review. Kein Live-KI-Test. Der vorhandene native Assistent wurde als Quelle gelesen, jedoch nicht verändert. Grafische Abnahme bleibt offen.
