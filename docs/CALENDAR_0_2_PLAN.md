# AboLife 0.2 – Kalender und adaptive Lernplanung

Stand: 26. Oktober 2026 · Status: UMGESETZT und lokal geprüft · Modus: persönliches Projekt

## Ziel und vereinbarte Richtung

AboLife soll einen eigenen lokalen Kalender bekommen. Der Nutzer hat manuelle Eingabe mit Stundenplan-Import gewählt. Uni, Training, Fahrtzeiten und persönliche Lernzeiten bestimmen, wann Lernblöcke möglich sind. Wiederholungen sollen zusätzlich berücksichtigen, was gelernt wurde und wie gut es noch abrufbar ist. Ändert sich der Kalender, werden noch nicht begonnene Lernvorschläge neu geplant.

Die bisherige Version muss jederzeit weiter nutzbar bleiben. Der freigegebene Umfang ist als getrennte Version umgesetzt. Die Anleitung und die aktuelle Regel stehen in `CALENDAR_GUIDE.md`. Ein echter persönlicher Stundenplan wurde noch nicht eingetragen.

## Gesicherte Ausgangsversion 0.1

Der aktuelle Arbeitsstand wurde nach einem erfolgreichen Lauf aller 195 Tests lokal gesichert:

`outputs/releases/AboLife-0.1-stable-2026-10-26/`

Die Sicherung enthält die ausführbare macOS-App, den tatsächlichen Quellcode einschließlich noch nicht eingecheckter Änderungen und eine konsistente SQLite-Datenkopie. Startkonfigurationen im Quellcodearchiv enthalten keine gespeicherten Umgebungswerte. Der aktuelle Git-HEAD allein bildet diesen Stand nicht ab.

Vor der ersten Umsetzung von 0.2 sind zwingend folgende Grenzen einzurichten und zu testen:

- Eigenes Entwicklungsverzeichnis und eigener Entwicklungszweig, ausgehend vom gesicherten Arbeitsstand.
- Eigene App-Kennung und eigener Datenordner für 0.2, beispielsweise `com.private.AboLife.calendarPreview` und `AboLife-Calendar-Preview`.
- Die Daten der Version 0.1 werden nur kopiert. Neue Migrationen dürfen ausschließlich die Kopie öffnen.
- Eigene Export- und Sicherungspfade sowie getrennte Benutzereinstellungen. Beide Varianten müssen nebeneinander startbar sein.
- Eine Rückkehr zu 0.1 erfolgt durch Öffnen der gesicherten App. Einträge aus 0.2 erscheinen nicht automatisch in 0.1. Ein späterer Datenaustausch wäre ein eigener, geprüfter Import.
- Vor Freigabe: 0.2 mit einer Datenkopie starten, neue Migrationen ausführen und prüfen, dass die Originaldatenbank von 0.1 unverändert bleibt.

Die ursprüngliche App und ihre aktive Datenbank bleiben erhalten. Die Umsetzung erfolgt im eigenen Kalender-Arbeitsverzeichnis.

## Betrachtete Ansätze

1. **Einfacher Kalender mit festen Lernblöcken:** kleinster Einstieg; berücksichtigt Zeiten und Wege, passt Wiederholungen aber nicht an Rückmeldungen an. Deckt den gewünschten Lernplaner nur teilweise ab.
2. **Eigener Kalender mit lokaler, regelbasierter Lernplanung:** gewählte Richtung. Kombiniert feste Termine, Wege, verfügbare Zeiten und Wiederholungsbedarf. Nachvollziehbar und ohne Cloud-Konto nutzbar. Höherer Aufwand als ein reiner Kalender.
3. **Apple Kalender als Terminquelle:** Alternative für einen späteren Ausbau. Würde Berechtigungen, externe Änderungen und Abgleichregeln benötigen. Gehört nicht zum gewählten ersten Umfang.

Empfehlung: Ansatz 2 schrittweise umsetzen. Zuerst belastbare Zeitplanung, danach adaptive Wiederholungen. Keine automatische Kalenderanbindung und keine KI-Dienste im ersten Umfang.

## Kalender und Eingaben

Der Kalender bekommt einen einzigen neuen Navigationseintrag „Kalender“. Innerhalb davon liegen Wochenansicht, Stundenplan und Lernplanung. Bestehende Gesundheitsseiten bleiben erhalten.

Termine enthalten Beginn, Ende, Kategorie, Ort sowie optional Fach, Semesterzeitraum und Wiederholungsregel. Manuelle Termine unterstützen wöchentliche Wiederholung, Ausnahmen und Absagen. Universität, Training, persönliche Termine und Lernvorschläge sind unterscheidbar.

Der erste Stundenplan-Import unterstützt lokale `.ics`-Dateien mit einer Vorschau vor Übernahme. Unterstützt werden einzelne Termine und wöchentliche Serien mit Enddatum oder Anzahl sowie Ausnahmedaten. Nicht unterstützte Wiederholungsregeln werden ausdrücklich angezeigt, statt still falsch importiert zu werden. Zeitzonen und Sommerzeit werden berücksichtigt. PDF- oder Screenshot-Erkennung wird für diesen Umfang nicht zugesagt.

Beim erneuten Import wird die Identität aus Importquelle und `UID` gebildet; einzelne Serienvorkommen verwenden zusätzlich `RECURRENCE-ID`. Verschobene Einzelvorkommen werden in diesem ersten Umfang in der Vorschau ausdrücklich als nicht unterstützt ausgewiesen. Eigene Termine und manuelle Ausnahmen dürfen nicht überschrieben werden. Bei widersprüchlichen lokalen und importierten Änderungen entscheidet der Nutzer in der Vorschau. Fehlende Termine gelten nur bei einem ausdrücklich vollständigen Wiederimport derselben Quelle als mögliche Löschungen; sie werden vor dem Löschen zur Prüfung angezeigt. Ein Teilimport löst keine Löschungen aus.

## Uni, Training und Fahrtzeiten

Bekannt sind zunächst:

- Uni: 60 Minuten Hinfahrt.
- Training außer Haus: 15 Minuten Hinfahrt.

Die Rückwege sind noch zu bestätigen. Hin- und Rückfahrt werden getrennt gespeichert; Gleichheit darf in der Einrichtung vorgeschlagen, aber nicht als feststehende Nutzervorgabe behandelt werden.

Die bestehenden Trainingspläne liefern Trainingstage und Varianten, aber keine verbindlichen Uhrzeiten. Start, Dauer und Trainingsort müssen deshalb im Kalender gesetzt werden. Ein Home-Workout hat keinen Weg zum Fitnessstudio.

Wege werden zwischen tatsächlichen Orten geplant. Ein direkter Wechsel von Uni zum Training darf nicht versehentlich als Heimfahrt plus neue Hinfahrt gerechnet werden. Für eine unbekannte Verbindung fordert die Einrichtung eine Dauer an. Bis sie bekannt ist, gilt das gesamte Zeitfenster zwischen dem Ende des vorherigen Termins und dem Beginn des Folgetermins als ungeklärt und wird nicht automatisch mit Lernen belegt. Ist ein bekannter Weg länger als dieses Zeitfenster, zeigt die App einen Konflikt zwischen den festen Terminen. Sie behauptet keine machbare Verbindung und verschiebt feste Termine nicht selbstständig.

Uni-Pausen können als Lernzeit nutzbar sein, wenn Lernen vor Ort erlaubt ist. Der Planer erzwingt dafür keine Heimfahrt. Schlafzeiten, feste Termine, bestätigte Fahrtzeiten und benötigte Pausen sind gesperrt.

## Lernplanung

Der Nutzer legt Fächer und konkrete Themen an. Ein Vorlesungstermin kann einem Fach zugeordnet werden, verrät aber noch nicht, welche Inhalte beherrscht werden. Für ein Thema werden gewünschte Sitzungsdauer und optional Prüfungstermin erfasst. Lernfenster, Tagesobergrenze, Mindestblocklänge und Pausen sind einstellbar.

Der Planer arbeitet in zwei Schritten:

1. Freie Zeitfenster aus Terminen, Orten, Wegen und persönlichen Grenzen berechnen.
2. Fällige Themen in geeignete Fenster verteilen. Überfälligkeit, Prüfungstermin und benötigte Dauer bestimmen die Priorität; die Oberfläche erklärt den Vorschlag kurz.

Beispiel: Beginnt Uni um 09:00 Uhr, wird die bekannte Hinfahrt ab 08:00 Uhr freigehalten. Endet ein Lernblock um 17:45 Uhr und beginnt Training um 18:00 Uhr, ist das nur passend, wenn der tatsächliche Weg zum Training höchstens 15 Minuten dauert und keine weitere Pause nötig ist.

Kann nicht alles untergebracht werden, zeigt die App unplatzierte Themen mit Grund. Sie überbucht weder Fahrten noch Schlaf. Verschobene oder ausgelassene Sitzungen werden nicht als gelernt markiert.

## Wiederholungen und Anpassung

Verteilte Wiederholungen sind wissenschaftlich begründet; ein universell bester Abstand für jedes Thema und jede Prüfung existiert daraus nicht. Die Planung unterscheidet deshalb zwischen einem gewünschten Wiederholungszeitpunkt und dem tatsächlich verfügbaren Termin.

Nach einer Wiederholung wird kurz bewertet: „Vergessen“, „Schwer“, „Gut“ oder „Leicht“. Gespeichert werden Thema, tatsächlicher Zeitpunkt, Bewertung und tatsächliche Dauer. Diese Rückmeldungen beeinflussen die nächste Fälligkeit. Ohne Rückmeldungen kann die App Termine anpassen, aber keine persönliche Gedächtnisentwicklung ableiten.

Für den ersten Ausbau wird ein transparenter, versionierter Regelansatz für Themenblöcke festgelegt und getestet. Er ist eine Heuristik, kein Nachweis maximalen Lernerfolgs. FSRS ist ein möglicher späterer Baustein für konkrete Wissensabfragen; das Verfahren darf nicht ungeprüft von Karteikarten auf beliebige lange Lernsitzungen übertragen werden. Personalisierte Modellparameter benötigen tatsächliche Wiederholungsdaten.

Eine spätere Verbesserung des Planers kann typische Sitzungsdauern aus erledigten Einheiten ableiten. Die App verändert dabei nur die Planungsdaten und Modellparameter innerhalb der neuen Version; sie schreibt keinen eigenen Programmcode um.

Grundlagen:

- Cepeda et al., „Distributed practice in verbal recall tasks“: https://pubmed.ncbi.nlm.nih.gov/16719566/
- FSRS, Scheduler und Optimizer: https://github.com/open-spaced-repetition/fsrs4anki

## Automatische Neuplanung

Neuplanung wird durch relevante Änderungen ausgelöst: Termin hinzufügen, verschieben, absagen oder importieren; Lernbewertung speichern; Sitzung abschließen oder auslassen; verfügbare Zeiten ändern.

Vergangene, laufende, erledigte und ausdrücklich fixierte Lernblöcke bleiben bestehen. Wird nachträglich ein kollidierender Termin hinzugefügt, zeigt die App den Konflikt mit einem laufenden oder fixierten Block sichtbar an und überlässt dessen Auflösung dem Nutzer. Der Block wird bis dahin als konfliktbehaftet dargestellt, statt ihn als gültigen Vorschlag auszugeben. Alle übrigen neu berechneten Vorschläge bleiben konfliktfrei. Noch gültige zukünftige Vorschläge bleiben nach Möglichkeit an ihrem Platz. Gleiche Eingaben erzeugen denselben Plan; bloßes Öffnen der Ansicht würfelt die Woche nicht neu.

Die Planung läuft lokal und erhält ein Abbild aller Eingaben. Werden diese während der Berechnung verändert, wird ein veraltetes Ergebnis verworfen. Lernblöcke zeigen nachvollziehbar, welches Thema fällig ist und warum das Zeitfenster passt.

## Umsetzungsschritte und vorhandener Code

1. Versions- und Datentrennung einrichten; Rückkehr zu 0.1 praktisch testen.
2. Kalenderdaten, Uhrzeiten und Wochenansicht ergänzen; bestehende App-Navigation und Gestaltungsbausteine verwenden.
3. ICS-Import mit Vorschau, Serien, Zeitzonen und Wiederimport ergänzen.
4. Fahrtzeiten und freie Zeitfenster mit isolierten, zeitunabhängig testbaren Berechnungen implementieren.
5. Themen, Lernaufträge und erste manuelle Vorschläge ergänzen.
6. Bewertungen, Wiederholungsfälligkeiten und automatische Neuplanung hinzufügen.
7. Mit einer echten Semesterwoche prüfen und danach als Version 0.2 ausgeben.

Vorhandene Bausteine: `AppRouter`, SQLite/GRDB, Repository-Muster, `HomeWorkoutPlanProvider`, Trainingsdaten, Settings und `BackupService`. Der aktuelle Lern-Habit bleibt zunächst eine Übersicht; automatisch aus Lernblöcken abgeleitete Habit-Minuten sind ein gesondert zu prüfender späterer Anschluss, damit keine doppelte Zählung entsteht.

## Erfolgskriterien und Prüfungen

- Kein automatisch neu geplanter Lernblock überschneidet feste Termine, Wege oder andere Lernblöcke. Nachträgliche Konflikte mit laufenden oder fixierten Blöcken werden sichtbar zur Auflösung vorgelegt.
- Uni- und Trainingswege werden abhängig vom Ort korrekt berücksichtigt.
- Sommerzeitwechsel, Serienausnahmen, Terminabsagen, Doppelimporte, Teilimporte, lokale Importkonflikte, leere Wochen und vollständig belegte Wochen sind getestet.
- Beispieldaten und Tests enthalten einen direkten Uni–Training-Wechsel sowie einen zeitlich unmöglichen Wechsel zwischen festen Terminen.
- Feedback beeinflusst Fälligkeiten nach dokumentierten Regeln; vergangene und fixierte Blöcke bleiben unverändert.
- Änderungen am Kalender führen zu einem konsistenten, erklärbaren neuen Vorschlag.
- Beide App-Versionen starten unabhängig. Neue Datenbankmigrationen verändern die Originaldaten von 0.1 nicht.
- Die bisherige Test-Suite bleibt erfolgreich; neue Berechnungen und Datenmigrationen erhalten eigene Tests.

## Offene Punkte für die Einrichtung

- Echter Stundenplan mit Semesterbeginn und -ende, entweder als ICS-Datei oder als Wochentage mit Uhrzeiten.
- Trainingszeiten, Dauer und Ort.
- Dauer der Rückfahrten sowie gegebenenfalls direkter Wechsel Uni → Training.
- Gewünschte Lernzeiten, Pausen und Tagesobergrenze.
- Erste Fächer/Themen sowie gegebenenfalls Prüfungstermine.

Nächste konkrete Nutzeraktion: den Stundenplan bereitstellen. Trainings- und Wegezeiten können anschließend daran ergänzt werden. Diese persönlichen Daten sind für die spätere Einrichtung nötig; der erste Kalender kann mit neutralen Beispieldaten entwickelt werden.

## Auslieferung

0.1 liegt bereits als lokale App-Sicherung vor. 0.2 wird als separat benannte macOS-App mit eigener Kennung gebaut und lokal bereitgestellt. Veröffentlichung, App Store, Cloud-Synchronisierung und eine externe CI-Veröffentlichung sind für dieses persönliche Projekt zurückgestellt.

## Prüfung des Entwurfs

In zwei unabhängigen Prüfrunden wurden drei Punkte präzisiert: Konflikte mit fixierten Lernblöcken, Identität und Grenzen des Wiederimports sowie unbekannte und unmögliche Fahrtverbindungen. Ergebnis der zweiten Runde: PASS, 9/10. Die anschließende Umsetzung wurde mit 224 automatisierten Tests, einem Release-Build und Prüfungen der nativen Oberfläche abgesichert. Eine Erprobung mit dem persönlichen Stundenplan steht noch aus.
