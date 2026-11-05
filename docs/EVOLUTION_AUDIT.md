# AboLife – Bestandsaudit und Arbeitsplan

Stand: 5. November 2026. Grundlage ist der **Arbeitsbaum**, nicht nur der letzte Commit.

## Aktiver Stand und Schutzgrenzen

- Aktives Projekt: `AboLife.xcodeproj`, Schema `AboLife`, Bundle `com.private.AboLife`, macOS 14+.
- Xcode und Paketierung deklarieren 0.4.1; `VERSION` enthält veraltet 0.4.0. Das wird vereinheitlicht, ohne einen neuen Release zu veröffentlichen.
- Ausgangsbranch `feature/bonsaibar-ai-integration`; Arbeitsbranch `codex/abolife-quality-evolution`.
- Sehr umfangreiche vorhandene Änderungen einschließlich entfernter Ernährung/Telegram-Module und neuer Kalender-, News-, Web- und KI-Module. Diese sind Vorarbeiten, keine Ergebnisse dieses Auftrags. Keine Wiederherstellung entfernter Produktfunktionen.
- 91 App-Swift-Dateien und vier Testdateien; 22.078 Swift-Zeilen insgesamt. Größte App-Dateien: BackupService 1.499, TrainingView 1.015, FinanceRepository 950, FinanceView 799, DashboardStore 550, DashboardView 471 Zeilen.
- Tatsächliche Persistenz: **GRDB/SQLite**, keine aktive SwiftData-Datenbank. In TrainingDomainModels stehen unverdrahtete @Model-Typen ohne ModelContainer/Query; sie sind keine alternative Benutzerdatenhaltung. Historische Migrationen v1–v14, stabile Hauptdatenbank unter Application Support/AboLife-Main. Separate Demo und temporäre Testdatenbanken. Keine Änderung des Schemas geplant.
- Baseline, Quellkopien und Git-Diff liegen ausschließlich im ignorierten `work/evolution-baseline`. Persönliche Datenbanken werden für Entwicklung und Bilder nicht geöffnet.
- Vorhandenes `Features/AI` implementiert schon einen lokalen Connector und Aktionen. Diese Vorarbeiten bleiben erhalten; dieser Auftrag erweitert keine Inferenzanbindung. Der neue Analytics-/News-Plan wird getrennt davon dokumentiert.

## Prüfung

Projektdatei, Schemen, alle Swift-Dateien per Typ-/Funktionsinventar, Stores, Repositories, Modelle, Migrationen, Backup-/Sync-Vertrag, Views, Designsystem, Skripte, CI und Produkt-/Architekturdokumentation wurden untersucht. Die existierenden Codegraphen stammen aus Juni und sind ausdrücklich keine aktuelle Quelle für entfernte Module. Architekturbehauptungen werden am Quelltext geprüft.

Ausgangsprüfung `scripts/check-native.sh`: **254 XCTest-Tests entdeckt, 3 übersprungen, 0 Fehler**, **26 Node-Tests bestanden**. Übersprungene externe KI-Livetests werden nicht als ausgeführt gezählt. Toolchain: Xcode 27.2, Swift 6.4.2; Swift-Sprachmodus im Projekt weiterhin 5, Deployment macOS 14. Keine pauschale Swift-6-Migration.

Live-UI-Prüfung zunächst blockiert: Computer-Use meldet gesperrten Mac. Entsperren wurde angefragt. Automatische Bildrenderings und Layoutprüfungen werden ergänzend genutzt; sie ersetzen keine echte Interaktions-/VoiceOver-/Motion-Abnahme.

## Priorisierte Befunde

| Priorität | Beleg / Ursache | Maßnahme |
|---|---|---|
| P1 Datenvertrauen | QuickAddPanels quittiert Speichern unabhängig vom Ergebnis; DashboardStore schluckt Fehler in Aktivitäten. Ungültiger Betrag wird zu 0. | Explizite Mutationsergebnisse, Eingaben erhalten, validieren, verständliche Fehler direkt im Formular. Fehlerfälle auf isolierter Datenbank testen. |
| P1 Datenvertrauen | TrainingStore erzeugt Empfehlungen aus `sampleResults` und Körpertrends aus `sampleMeasurements`, auch mit echter Datenbank. | Keine Beispielwerte als persönliche Erkenntnisse. Fehlende Daten als leer anzeigen; nur gespeicherte Ergebnisse verwenden. |
| P2 Analytics | WeightStore nimmt `prefix(7/30)`, StatisticsStore nennt die letzten sieben Messungen „7-Tage-Schnitt“. | Tatsächliche Kalenderintervalle einschließlich fehlender Tage und ohne künftige Einträge verwenden; dünne Datenbasis kennzeichnen. |
| P2 Analytics | FinanceView zeichnet Einnahmen/Ausgaben und Prognose/Budget auf unterschiedlichen Skalen. Monatswahl und historische Reviews sind in Stores vorhanden, in den Ansichten kaum erreichbar. | Gemeinsame Chartskala; funktionierende Zeitraumwahl, historische Reviews mit Schutz ungespeicherter Eingaben. |
| P2 Fehlerzustände | App-Start fällt bei Datenbankfehler auf nil zurück, Debug-Assertion; UI kann scheinbar erfolgreich im Speicher arbeiten. | Verständlicher, gesperrter Wiederanlaufzustand statt beschreibbarer Oberfläche ohne Persistenz. Private strukturierte Diagnose. |
| P3 Wartbarkeit | NewsView enthält Modelle, XML-Parser, DB-Zugriff, Netzwerk, Filter und Oberfläche. Sehr große Training-/Finanzviews. | News nach Verantwortung trennen; gezielt große, eigenständige UI-Bestandteile extrahieren. Keine Repository-Komplettneuschreibung. |
| P3 Datenfluss | DashboardHabits und Statistik-Kacheln bekommen neue UUIDs bei jedem Reload. Newsfilter wiederholt Berechnung, Quellenwechsel kann laufenden Request überholen. | Stabile Identität, einmalig abgeleitete Darstellung, strukturierter Feedabruf mit expliziter Abbruch-/Quellenwechselregel. |
| P4 Design | Matte Graphitkarten/Blau passen zur gewünschten Identität, aber erzwungenes Dunkel und feste weiße Textfarben verhindern Light Mode. Abstände/Radien sind verstreut. | Semantische adaptive Farben, zentrale Tokens, alte Karten-/Ringhierarchie erhalten, native Appearance respektieren. |
| P4 Motion | Fast keine Animationen außer Gesundheit-Disclosure, keine gemeinsame Motionregel. | Wertegebundene Ring-/Balken-/Zahlenanimationen, Sidebar-Auswahl, kurze Opazitätswechsel und Interaktionsfeedback; Reduce Motion zentral berücksichtigen. Keine Endlosschleifen. |
| P4 Layout/AX | Detail-Minimum 860×640 zusätzlich zu Sidebar, feste 560×600-Quick-Add-Sheets, Newsfilter eine lange Zeile, unlabeled Iconbuttons. | Kleinere sinnvolle Minima, scrollbare/adaptive Dialoge und Filter, semantische Labels, sichtbarer Tastaturfokus. |
| P5 Performance | Statistiken laden alle Aktivitätsdaten zum Zählen; News parst seriell auf MainActor; Stores laden synchron im init/onAppear. | Erst messen; gezielte Query-/Feedverbesserungen, lazy Artikelliste. Keine unbelegten Caches oder Actor-Umbauten der gesamten App. |

## Umsetzungsfolge

1. Isolierte Ausgangs-Renderings und reproduzierbare Fehlerfälle erfassen.
2. Speicherfeedback, Beispielstatistiken und echte Tagesintervalle korrigieren; Regressionstests.
3. Adaptive Design-/Motiontokens, gemeinsame Zustandsanzeigen und Controls implementieren.
4. Dashboardidentität bewahren und verfeinern; Navigation, Ringe und Schnellerfassung verbessern.
5. Finanz-/Statistik-/Reviewansichten: Zeitraum, Datenherkunft, korrekte Vergleiche, kontrollierte Detailtiefe.
6. News entkoppeln und Abruf, Filter, Artikelzustände und schmale Layouts verbessern.
7. Training/Gewicht/Habits/Kalender/Einstellungen auf gemeinsame Regeln abstimmen.
8. Prüfbare Format-/Lintregeln, projektspezifische Skills und AGENTS.md ergänzen.
9. Vollständigen BonsaiBar-Plan am zugänglichen Nachbarprojekt überprüfen; keine KI-Anbindung ergänzen.
10. Build, Tests, Bildrenderings, Performance und kritische Selbstprüfung wiederholen; Grenzen ausdrücklich berichten.

## Fachliche Invarianten

Tagesbudget: vor heutigen Ausgaben verbleibenden Monatspuffer auf verbleibende Kalendertage einschließlich heute verteilen, danach heutige Ausgaben vollständig abziehen, Minimum 0. Monatsausgaben, Monatsrest und heute freier Betrag bleiben unterschiedliche Kennzahlen. Der Menüleistenring zeigt weiterhin den heute freien Anteil am gesamten Monatsbudget; der Finanzring den verbrauchten Monatsanteil. Keine fachliche Neudefinition durch Animation oder Layout.

Entries bleiben Primärwahrheit. Keine gespeicherten Summen, keine Schemaänderung, kein automatischer Restore/Sync, keine Veröffentlichung, kein Upload privater Daten. Qualitätsänderungen werden gegen den gesicherten Arbeitsbaum bewertet; vorbestehende Änderungen werden nicht als eigene Leistungen oder ungeprüft als eigener Commit ausgegeben.
