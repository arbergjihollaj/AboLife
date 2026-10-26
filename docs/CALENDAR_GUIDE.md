# AboLife Kalender 0.2 verwenden

Die Kalender-Version läuft unabhängig von 0.1. Sie hat ein eigenes Kalender-Symbol in der Menüleiste und zeigt „AboLife 0.2“ im Hauptfenster. Ihre Daten liegen im getrennten Ordner `~/Library/Application Support/AboLife-Calendar-Preview`. Beim ersten Start wird der alte Datenstand einmal kopiert. Neue Einträge werden danach nicht zwischen den Versionen synchronisiert.

1. **Planungszeiten:** Lege Lerntage und verfügbare Uhrzeiten fest. Vorgegeben sind Mo–Fr, 08:00–21:00, höchstens 120 Minuten Lernen pro Tag, mindestens 25 Minuten je Block und 10 Minuten Pause. Passe das an deinen Alltag an.
2. **Wege:** 60 Minuten zur Uni und 15 Minuten zum Training sind eingetragen. Ohne eigene Rückfahrtdauer wird zunächst dieselbe Dauer wie für die Hinfahrt verwendet und sichtbar als „wie Hinfahrt“ markiert. Du kannst die Rückfahrt separat anpassen oder diese Annahme ausschalten. Trage gegebenenfalls den direkten Weg Uni → Training ein. Home-Training hat keinen Fahrtweg. Fehlende direkte Verbindungen bleiben als Hinweis sichtbar.
3. **Stundenplan:** Trage Termine manuell ein oder wähle eine lokale `.ics`-Datei unter „Stundenplan“. Prüfe die Vorschau. Beim Wiederimport wähle dieselbe Quelle. Einfache Wochenserien, Wochentage, COUNT, UNTIL und EXDATE sind unterstützt; verschobene Serienvorkommen, andere Frequenzen und zusätzliche RDATE-Termine werden ausdrücklich gemeldet und nicht still falsch importiert. Kein PDF-Import.
4. **Training:** Erfasse verbindliche Uhrzeiten und den richtigen Ort. Die bestehenden Home-Trainingspläne haben Trainingstage, aber keinen festen Kalenderbeginn; diese Uhrzeiten werden nicht geraten.
5. **Lernthemen:** Füge Fach, konkretes Thema, erste Fälligkeit und Dauer hinzu; bei Bedarf ein Prüfungsdatum. Die App plant die nächste Wiederholung innerhalb von 14 Tagen in eine geeignete freie Lücke.
6. **Im Alltag:** Bewerte erledigte Einheiten mit Vergessen/Schwer/Gut/Leicht und tatsächlicher Dauer. „Schwer“ bedeutet noch richtig erinnert. „Auslassen“ verschiebt die Fälligkeit mindestens auf den Tag nach dem ausgelassenen Termin. Fixierte Blöcke werden bei Kalenderänderungen nicht eigenmächtig verschoben; Konflikte werden angezeigt.

## Was sich anpasst

Die Startregel ist eine nachvollziehbare Heuristik für Themenblöcke. Sie verspricht keinen wissenschaftlich optimalen Lernerfolg und ist kein trainiertes Gedächtnismodell:

- Vergessen: nächstes Intervall 1 Tag, Faktor sinkt um 0,3.
- Schwer: mindestens 1 Tag, sonst 80 % des vorherigen Intervalls; Faktor sinkt um 0,15.
- Gut: anfangs 2 Tage, später vorheriges Intervall × Faktor.
- Leicht: anfangs 4 Tage, später mindestens 3 Tage bzw. Intervall × (Faktor + 0,4); Faktor steigt um 0,15.
- Der Faktor bleibt zwischen 1,3 und 3; Intervalle höchstens 90 Tage. Kalender-Tage berücksichtigen Sommerzeit. Die tatsächliche Platzierung richtet sich zusätzlich nach freien Zeiten und Prüfungsterminen.
- Die Dauer zukünftiger Blöcke verwendet den Median der letzten höchstens fünf bestätigten Dauern. Die Mindestblocklänge und Tagesgrenze gelten weiter.

Neue Termine lösen sofort eine Neuplanung aus. Bereits passende Vorschläge bleiben möglichst stehen. Der geöffnete Kalender aktualisiert seine Planung zusätzlich jede Minute. Für den Start braucht die App keinen externen Dienst und keine Zugangsdaten. Persönliche Gedächtnisanpassung braucht tatsächliche Bewertungen; bloßes Hinzufügen von Terminen verbessert nur die Zeitplanung.

## Sichern und zurück zu 0.1

Die bisherigen Sicherungsfunktionen sind weiter über ⌘, erreichbar. SQLite-Sicherungen enthalten alle Kalenderdaten; der JSON-Export enthält sie ebenfalls. Beim CSV-Backup gibt es zusätzlich die Datei `calendar_workspace.json`.

Zum alten Stand die gesicherte App 0.1 öffnen. Ihr Datenordner bleibt `~/Library/Application Support/AboLife`. Dafür ist keine Rückwärtsmigration nötig. Einträge aus 0.2 erscheinen nicht automatisch in 0.1.

## Automatische Fahrten ab 0.2.1

Die Tagesansicht zeigt berechnete Fahrten als eigene, dezente Zeilen. Vor dem ersten Uni-Termin liegt die Hinfahrt, nach dem letzten Uni-Termin die Rückfahrt. Auch bei längeren Pausen zwischen Uni-Terminen bleibt der Aufenthalt auf dem Campus bestehen. Das gilt ebenso, wenn Lernen vor Ort ausgeschaltet ist. Zuhause wird nur eingeplant, wenn ein tatsächlicher Termin dort liegt oder alle auswärtigen Termine beendet sind.

Hin- und Rückfahrten sind an die Termine gebunden und werden nach Änderungen oder Absagen neu berechnet. Sie sind keine zusätzlichen importierten Termine und erzeugen beim Wiederimport keine Duplikate. Der Lernplaner reserviert genau dieselben Wege, die angezeigt werden. Kommt später Training hinzu, wird der nächste tatsächliche Ort berücksichtigt; für Uni → Training ist die direkte Fahrtzeit nötig. Ein fehlender direkter Weg wird nicht durch eine erfundene Heimfahrt ersetzt.
