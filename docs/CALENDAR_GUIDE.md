# AboLife Kalender 0.2 verwenden

AboLife 0.4 ist die Haupt-App. Beim ersten Start werden vorhandene Preview-Daten als Kopie in `AboLife-Main` übernommen. Spätere Preview-Einträge werden nicht erneut automatisch kopiert.

1. **Planungszeiten:** Lege Lerntage und verfügbare Uhrzeiten fest. Vorgegeben sind Mo–Fr, 08:00–21:00, höchstens 120 Minuten Lernen pro Tag, mindestens 25 Minuten je Block und 10 Minuten Pause. Passe das an deinen Alltag an.
2. **Wege:** 60 Minuten zur Uni und 15 Minuten zum Training sind eingetragen. Ohne eigene Rückfahrtdauer wird zunächst dieselbe Dauer wie für die Hinfahrt verwendet und sichtbar als „wie Hinfahrt“ markiert. Du kannst die Rückfahrt separat anpassen oder diese Annahme ausschalten. Ein direkter Weg Uni → Training ist nur für zeitlich knappe Übergänge nötig. Nach dem letzten Uni-Termin geht es zuerst nach Hause und später von dort zum Training. Home-Training hat keinen Fahrtweg. Fehlende direkte Verbindungen bleiben als Hinweis sichtbar.
3. **Stundenplan:** Trage Termine manuell ein oder wähle eine lokale `.ics`-Datei unter „Stundenplan“. Prüfe die Vorschau. Beim Wiederimport wähle dieselbe Quelle. Einfache Wochenserien, Wochentage, COUNT, UNTIL und EXDATE sind unterstützt; verschobene Serienvorkommen, andere Frequenzen und zusätzliche RDATE-Termine werden ausdrücklich gemeldet und nicht still falsch importiert. Kein PDF-Import.
4. **Training:** Erfasse verbindliche Uhrzeiten und den richtigen Ort. Die bestehenden Home-Trainingspläne haben Trainingstage, aber keinen festen Kalenderbeginn; diese Uhrzeiten werden nicht geraten.
5. **Lernplanung:** Aus deinen Uni-Terminen entstehen automatisch Modulblöcke für Vor- und Nacharbeit. Du musst keine eigenen Themen anlegen. Zusätzliche Themen mit einer eigenen Wiederholungsfälligkeit und optionalem Prüfungstermin bleiben möglich.
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

Die Tagesansicht zeigt berechnete Fahrten als eigene, dezente Zeilen. Vor dem ersten Uni-Termin liegt die Hinfahrt, nach dem letzten Uni-Termin die Rückfahrt. Auch bei längeren Pausen zwischen Uni-Terminen bleibt der Aufenthalt auf dem Campus bestehen. Uni-Pausen bleiben dabei lernfrei. Nach dem letzten Uni-Termin ist die Heimfahrt vorgesehen, auch wenn später noch Training oder ein anderer auswärtiger Termin folgt.

Hin- und Rückfahrten sind an die Termine gebunden und werden nach Änderungen oder Absagen neu berechnet. Sie sind keine zusätzlichen importierten Termine und erzeugen beim Wiederimport keine Duplikate. Der Lernplaner reserviert genau dieselben Wege, die angezeigt werden. Kommt später Training hinzu, wird zunächst Uni → Zuhause und später Zuhause → Training eingeplant. Beide bekannten Wegedauern müssen vor den festen Termin passen. Ist das zeitlich unmöglich, erscheint ein Hinweis; eine direkte Weiterfahrt kann dann nur mit bekannter, passender Dauer geplant werden. Fehlt eine benötigte Wegedauer, bleibt die Lücke ungeplant.

## Nach der Uni zuerst nach Hause (0.2.2)

Die Heimfahrt beginnt direkt nach dem letzten Uni-Termin des Tages. Ein späteres Fußballtraining verlängert den Uni-Aufenthalt nicht. Bis zur Abfahrt von Zuhause ist die freie Zeit für Lernen zu Hause verfügbar. Zwischen zwei Uni-Terminen gibt es weiterhin keine automatische Heimfahrt, auch bei längeren Pausen.

Beispiel: Uni endet um 09:30, Heimweg 60 Minuten, Training beginnt um 19:00, Hinfahrt 15 Minuten. Die App plant 09:30–10:30 nach Hause und 18:45–19:00 zum Training. Der Rückweg nach dem Training folgt wie bisher. Erledigte Historie und fixierte Lernblöcke bleiben bestehen; passt ein fixierter Block nicht mehr zur neuen Planung, wird der Konflikt angezeigt. Andere Vorschläge werden an den richtigen Ort neu geplant.

## Module automatisch vor- und nachbereiten (0.2.4)

Die automatische Modulplanung ist zunächst eingeschaltet. Nach Import, Hinzufügen, Bearbeiten, Absagen oder Entfernen von Terminen werden flexible Lernblöcke sofort neu berechnet. Beim geöffneten Kalender aktualisiert die App die Planung zusätzlich jede Minute.

- Mehrere Uni-Veranstaltungen desselben Moduls an einem Tag werden zusammengefasst. Eine Modulnummer wie `(33-48103)` hat Vorrang bei der Zuordnung; ohne Nummer wird der Titel verwendet.
- **Vorarbeit:** bevorzugt am vorherigen erlaubten Lerntag. Das Fenster umfasst die zwei vorherigen erlaubten Lerntage. Dadurch kann die App bei mehreren lernfreien Wochentagen auch auf den davorliegenden Samstag ausweichen, statt alles auf Sonntag zu legen. Bei mehreren aufeinanderfolgenden Lehrtagen beginnt die Vorbereitung auf den nächsten Tag erst nach den vorherigen Veranstaltungen dieses Moduls.
- **Nacharbeit:** frühestens nach der letzten Veranstaltung des Moduls und der eingestellten Pause. Möglichst am selben Tag, sonst bis zum Ende des nächsten erlaubten Lerntags. So können späte Freitagstermine auf Montag übergehen, wenn du am Wochenende nicht lernen möchtest.
- Beide Phasen beginnen mit 25 Minuten bzw. deiner größeren Mindestblocklänge. Bestätigte Dauern passen die Schätzung für weitere Phasen desselben Moduls an.
- Der Planer priorisiert Dringlichkeit und Nacharbeit. Er wahrt Termine, Fahrtwege, erlaubte Lernorte, Pausen und Tagesgrenzen. Nicht untergebrachte Phasen werden pro Modul angezeigt; er überbucht dafür keine Zeiten.
- Erledigte Phasen werden nicht erneut angelegt. Auslassen verschiebt den frühesten nächsten Versuch, soweit das Lernfenster noch offen ist. Fixierte Blöcke werden nicht heimlich verschoben; Konflikte bleiben sichtbar. Unbestätigte alte Vorschläge vor oder während der Uni werden neu verteilt, auch bei bereits vergangener Startzeit.

Unter **Lernplanung** siehst du die automatisch erkannten Module und ihre nächsten Blöcke. **Eigene Themen** sind optional und nutzen weiterhin die separate Wiederholungsregel. Bei automatischen Modulphasen bleibt das Zeitfenster an den Stundenplan gebunden; die Bewertung dokumentiert deinen Eindruck, die Dauer verbessert weitere Schätzungen. Unter **Planungszeiten** kannst du die automatische Modulplanung ausschalten.

Diese Zeitfenster sind nachvollziehbare Produktregeln. Die ICS verrät keine konkreten Lerninhalte oder individuellen Wissenslücken, und die Regeln garantieren keinen optimalen Lernerfolg. Forschung zum verteilten Lernen zeigt, dass sinnvolle Abstände vom gewünschten Behaltenszeitraum abhängen: [Cepeda et al. (2008)](https://pubmed.ncbi.nlm.nih.gov/19076480/). Eine experimentelle Gegenüberstellung von Vor- und Nachtests untersucht Wissensabruf, keine universelle Uhrzeit für Modulblöcke: [Latimier et al. (2019)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6760123/).

## Lernfreie Zeit vor und während der Uni (0.2.5)

An jedem Tag mit einem Uni-Termin beginnt das Lernfenster erst nach dem letzten Uni-Termin und der Rückkehr nach Hause. Das gilt für alle Module und eigene Themen, auch wenn die erste Veranstaltung erst nachmittags beginnt. Uni-Pausen werden nicht als Lernzeit verwendet; du bleibst zwischen Uni-Terminen weiterhin vor Ort. Alte gespeicherte Campus-Freigaben setzen diese Regel nicht außer Kraft. Bei Online-Uni zu Hause entfällt der Heimweg, die letzte Veranstaltung muss trotzdem beendet sein.

Vorarbeit wird auf einen früheren erlaubten Lernzeitraum gelegt. Gibt es vor der Veranstaltung keinen passenden freien Block, wird die Phase als nicht unterbringbar angezeigt. An Tagen ohne Uni bleiben die eingestellten Lernzeiten nutzbar. Fehlende Heimweg-Dauern geben weder einen freien Morgen noch eine geschätzte Lernlücke frei.

## Lernen am Wochenende verteilen (0.2.6)

Die Wochentage unter **Planungszeiten** bestimmen, an welchen Tagen die App Lernblöcke anlegt. Wenn Montag und Dienstag deaktiviert und Samstag und Sonntag aktiviert sind, bleibt Lernen auf Mittwoch bis Sonntag beschränkt. Uni und Training werden weiterhin unverändert angezeigt.

Vorbereitung bevorzugt den letzten erlaubten Lerntag, kann bei belegten Zeiten oder ausgeschöpfter Tagesgrenze aber den zweiten vorherigen erlaubten Lerntag verwenden. So kann Vorbereitung für Montag bis Mittwoch auf beide Wochenendtage verteilt werden. Die vorherige Veranstaltung desselben Moduls bleibt als früheste Grenze berücksichtigt. An Uni-Tagen beginnt Lernen weiterhin erst nach dem letzten Uni-Termin und der Heimfahrt.
