# AboLife · UI Design Lab

Separate Konzeptgalerie für AboLife 0.4.1. Kein Swift-Code, keine persönlichen Datenbanken, keine Sync-/Backup-Operationen, keine externe Abhängigkeit und kein Kontakt zu einer KI. Die echte App wird nicht geändert.

## Öffnen

**Mit automatischer Projektdokumentation:** `Start-UI-Design-Lab.command` doppelklicken oder im Terminal:

```sh
cd /Users/arbergjihollaj/Developer/Apps/AboLife/design-lab
npm start
```

Dann **http://127.0.0.1:4177** öffnen. Node.js 24+ genügt; `npm install` ist nicht nötig. Abbrechen mit Ctrl+C. Für einen anderen freien Port: `LAB_PORT=4178 npm start`.

**Ohne Server:** `UI-Design-Lab.html` im Browser öffnen. Die Datei enthält die komplette Galerie und alle fünf echten Prototypen. Feedback bleibt im lokalen Browser unter `abolife.design-lab.feedback.v1` gespeichert. Unter „Deine Auswahl“ als Markdown exportieren und in diesem Ordner als `DESIGN_FEEDBACK.md` ablegen. Browser können lokale Dateispeicherung einschränken; das Lab zeigt Lade-/Speicherfehler an. Für die zuverlässige Projektdatei-Speicherung die Node-Version verwenden. Offline- und Serverversion haben getrennte Feedbackspeicher.

## Rundgang

1. A bis E nacheinander öffnen. „Mehr Platz“ blendet die Feedbackspalte aus.
2. Dashboard, Finanzen, Training, Gewohnheiten und Kalender testen. Beispielsweise Ausgabe hinzufügen, Wasser erhöhen und eine Trainingseinheit abschließen.
3. Gewicht, Statistiken, Review, Nachrichten und Einstellungen über die jeweilige Konzeptnavigation oder den Bildschirmwähler öffnen.
4. Gesamtnote und sechs Einzelnoten vergeben, Kommentare schreiben und Bausteine markieren. Automatisches Speichern nach kurzer Eingabepause; manuelles Speichern zusätzlich möglich. Nur die Meldung „Gespeichert“ bestätigt den Commit.
5. Unter „Vergleichen“ zwei bis fünf Konzepte wählen. Der Bildschirmwähler steuert alle Prototypen. Mac skaliert die 1000-px-Ansicht; „Groß“ und „Schmal“ erlauben Bedienung ohne Verkleinerung und horizontales Scrollen. Jede Spalte lässt sich einzeln vergrößern. „Beispieldaten angleichen“ setzt Demo-Eingaben zurück.
6. Unter „Deine Auswahl“ Favoriten und Bewertungen sammeln und als Markdown/JSON exportieren.

Escape schließt Dialoge; alle Aktionen sind mit beschrifteten Buttons und Formularfeldern zugänglich. Systemseitiges Reduce Motion und der zusätzliche Schalter in den Prototyp-Einstellungen deaktivieren Bewegung. Dies ersetzt keine grafische Accessibility-Abnahme.

## Konzeptumfang

| Konzept | Primäre Navigation | Dashboard | Charakter |
|---|---|---|---|
| A · Apple Native | Permanente Sidebar | Ruhiger Tageskern mit Karten | Systemschrift, Blau, Weißraum |
| B · Futuristic Spatial | Schwebendes Dock | Instrumente um einen zentralen Orbit | Tiefe, Transparenz, Mint |
| C · Editorial Swiss | Nummerierter Index | Asymmetrische Schlagzeile, Zeilenraster | Große Zahlen, Signalrot |
| D · Modular Bento | Kompakte Werkzeugleiste | Umsortierbare Widgets | Direkter Zugriff, Lila, farbige Module |
| E · Fieldnotes | Kapitelregister + Bereichswähler | Linearer Tagespfad mit Randnotizen | Serifentypografie, Papierfarben, Waldgrün |

Alle fünf bieten dieselben zehn Bereiche und dieselben Demo-Aktionen. Umsortieren ist bewusst ein spezifisches Bedienexperiment von D. Die Prototypen ersetzen keine vollständige Fachimplementierung: ICS-Parser, Satzeditor, automatische Kalenderplanung, Finanzplanung, echte RSS-Abfragen, Datenbankverwaltung und KI sind nicht nachgebaut. Diese Funktionen wurden bei der Informationsarchitektur berücksichtigt; sie werden erst beim später freigegebenen nativen Redesign im Detail gestaltet.

## Feedback & Daten

Die Node-Version speichert Gesamtnote, Einzelnoten, vier Kommentare und Favoriten in `.local/feedback.json` und schreibt nach jedem erfolgreichen Speichern `DESIGN_FEEDBACK.md`. `.local/` ist ignoriert. Das Markdown dient zur gemeinsamen Auswertung und enthält ausschließlich tatsächlich eingegebenes Feedback. Für private Bewertungen vor einem späteren Git-Commit die Datei prüfen. Keine automatischen Commits oder Pushes.

Prototyp-Eingaben bleiben im Arbeitsspeicher des jeweiligen Frames. Sie überleben interne Seitennavigation, werden beim erneuten Öffnen oder Neuladen zurückgesetzt und sind vollständig unabhängig von produktiven Daten. Review-Entwürfe bleiben bei internem Seitenwechsel erhalten. Ein globaler Neustart des Vergleichs gleicht die Fixture wieder an. Alle Datumsangaben beziehen sich ausdrücklich auf den fiktiven 5. November 2026.

Der Server bindet ausschließlich an `127.0.0.1`. Er akzeptiert nur begrenzte, validierte gleich-originäre JSON-Schreibzugriffe und liefert nur öffentliche Lab-Dateien aus. Schreibvorgänge werden serialisiert und dateiweise atomar ersetzt. Ein Lesefehler wird nicht als leerer Speicher ausgegeben. Dies ist ein lokales Einpersonen-Lab, keine Mehrbenutzer-Synchronisation.

## Struktur & Prüfungen

- `public/concepts/a–e.js`: eigenständige Dashboard-Kompositionen.
- `public/concepts/a–e.css`: voneinander getrennte Designsprachen.
- `public/prototype.js`: gemeinsame Demo-Aktionen und zehn Testbereiche; je Konzept eigener iframe und isolierter State.
- `public/prototype.css`, `public/responsive.css`: semantische Basis, Motion und schmale Ansichten.
- `public/lab.js`, `public/lab.css`: Galerie, Vergleich, Favoriten, Bewertung.
- `server.mjs`: isolierter lokaler Dateiserver und Feedbackpersistenz.
- `build-offline.mjs`: reproduzierbares Einbetten der vollständigen Anwendung in eine HTML-Datei.
- `APP_ANALYSIS.md`: Bestandsaufnahme und gestalterische Entscheidungen.
- `TEST_REPORT.md`: tatsächliche Ergebnisse und Grenzen.

```sh
npm test
node build-offline.mjs
```

Keine Native-Builds notwendig: Swift-/Xcode-/SwiftPM-Quellen und Buildkonfigurationen sind von diesem Auftrag unberührt.

**Entscheidungspunkt:** Nach gemeinsamer Auswertung entsteht Konzept F. Die echte App wird erst nach ausdrücklicher Freigabe verändert.

## Neu: Konzept F – drei Designs in einer App

Öffne die sechste Karte **My Perfect Design** oder den Hauptbutton „Deine Designauswahl testen“. Im Prototyp unter **Einstellungen → Dein Erscheinungsbild → Design** zwischen B, D und E wechseln. Dort lässt sich auch die Akzentfarbe ändern. Im Bento-Modus erscheint zusätzlich „Dashboard anordnen“ mit Drag-and-drop und Tastaturalternative über Auf-/Ab-Buttons.

Auswahl, Akzentfarbe und Widgetreihenfolge bleiben in diesem Browser gespeichert. Der Wechsel erhält die aktuellen Demo-Eingaben und den geöffneten Bereich. Die Bewertung für F lässt sich wie bei A–E speichern; maximal fünf Konzepte sind gleichzeitig vergleichbar. Bei bereits laufendem Node-Server diesen einmal mit Ctrl+C beenden und `npm start` erneut ausführen, damit auch der Server die F-Bewertung kennt. Anschließend die Galerie neu laden. Die Offline-HTML wurde ebenfalls aktualisiert.

Details und Abgrenzung: `DESIGN_DECISION.md`. Aktuelle Prüfung: 16 erfolgreiche automatisierte Tests; visuelle Browserabnahme bleibt aufgrund der zuvor dokumentierten Umgebungsgrenzen offen.

## Bestehenden KI-Assistenten ausprobieren

„AboLife AI“ ist aus jedem Prototypbereich erreichbar: B oben in der Kopfzeile, D in der Seitenleiste, E neben dem Register. Kontextfreigaben sind zunächst leer. Frage eingeben oder einen Vorschlag auswählen; „Ablauf testen“ zeigt eine ausdrücklich vorbereitete Demoantwort. Ein Review-Aktionsvorschlag lässt sich nach Freigabe prüfen, ablehnen oder im Prototyp bestätigen. Es erfolgt keine echte Modellanfrage. Die vorhandene KI der nativen App wurde nicht verändert. Galerie bzw. Offline-HTML neu öffnen, um die Ergänzung zu sehen.
