# Änderungen

## Hauptversion 0.4.0

- Stabile App-Kennung und eigener Hauptdatenordner; einmalige Kopie aus Preview, ersatzweise Legacy, ohne Überschreiben vorhandener Hauptdaten.
- Isolierter Demomodus für Präsentation/Screenshots, CI-Konfiguration und aktuelle Portfolio-Dokumentation.
- 232 native Tests und 26 Web-/Clienttests lokal erfolgreich.

## Dashboard im ursprünglichen Aufbau

- Ursprüngliches Dashboard aus der gesicherten Version wiederhergestellt: persönliche Begrüßung, Daily-Core-Hero, offene Tagespunkte, detaillierte Trainings-/Finanzkarten, Gewohnheiten, Aktivitäten und Wochenraster.
- Entfernte Kalorien-/Proteinkarten bleiben entfernt; aktuelle Budgetkorrekturen und regelmäßige Aktualisierung bleiben erhalten.

## Gestaltung nach Nutzerwunsch

- Bisherige Dashboardbreite, Sidebar mit schlichtem Profil und mobile Navigation oben wiederhergestellt.
- Funktionsausbau, Datenkorrekturen, Synchronisierung, Offlineeingaben und Wiederherstellung beibehalten.

## [0.4.0] – aktueller Arbeitsstand

- Mac-Anmeldung korrigiert; Sitzung wiederverwendet und unabhängige Änderungen automatisch zusammengeführt.
- Dashboard und mobile Bedienung verbessert; Tagesausgaben vollständig vom Tagesbudget abgezogen.
- Mobile Lernbewertungen, Wochenreviews, Finanzplanung und Workout-Varianten ergänzt.
- Offlinevormerkung mit dauerhaften Anfragekennungen und prüfbaren Konflikten ergänzt.
- Derselbe Swift-Lernplaner für Mac und Homelab, private Tailscale-Einrichtung, Gesundheitscheck und konsistente Onlinebackups.
- Lokaler Restore für JSON, SQLite und neue CSV-Pakete mit Vorprüfung und Sicherung ergänzt.
- 229 native und 26 Web-/Clientprüfungen; Linux-/Browser-/Netzwerkabnahme bleibt wegen der Umgebung offen.

## [0.3.0] - 2026-10-27

- Lernplanungsstand 0.2.6 übernommen und veraltete Bewertungen abgesichert.
- Ernährung und Telegram als aktive Produktfunktionen entfernt; lokale historische Sicherungen bleiben lesbar.
- Dashboard, Menüleiste, Training, Habits, Statistiken und Wochenreview bereinigt.
- Eigenes App-Icon und News-Reader mit RSS, Quellenfiltern, Suche und Merkliste.
- Persönliche mobile Weboberfläche mit zentraler SQLite, Login, revisionsgesicherten Schreibvorgängen und Historie.
- Native Verbindung mit Schlüsselbund, optionalem periodischem Abgleich und expliziter Konfliktauflösung.
- 222 native Tests und 8 In-Process-Webtests erfolgreich. Servereinrichtung, Browser-/Netzwerk-/Live-RSS-Prüfung stehen noch aus.

## [0.2.6.0] - 2026-10-27

Validierung: 269 Tests erfolgreich.

- Vorbereitung kann beide vorherigen erlaubten Lerntage nutzen. Bei lernfreiem Montag und Dienstag können sich Modulphasen dadurch auf Samstag und Sonntag verteilen.
- Auch bei wenigen freigegebenen Lerntagen werden zwei passende Vorbereitungstage über Wochengrenzen hinweg berücksichtigt.
- Neuplanung wahrt die freigegebenen Wochentage, Tagesgrenzen, Pausen und das Lernverbot vor bzw. während der Uni.

## [0.2.5.0] - 2026-10-27

Validierung: 267 Tests erfolgreich.

- An Uni-Tagen erst nach dem letzten Uni-Termin und der tatsächlichen Rückkehr nach Hause lernen. Auch lange Uni-Pausen und freie Morgen bleiben lernfrei.
- Vorarbeit für solche Tage weicht auf frühere erlaubte Zeitfenster aus. Nicht passende Phasen bleiben sichtbar statt die Regel zu übergehen.
- Alte unbestätigte Vorschläge werden neu verteilt, auch wenn ihre vorgeschlagene Startzeit schon vorbei ist. Erledigte Historie und ausdrücklich fixierte Termine bleiben erhalten; fixierte Konflikte werden gemeldet.
- Der frühere Schalter für Lernen in Uni-Pausen entfällt. An Tagen ohne Uni gelten die üblichen Lernzeiten.

## [0.2.4.0] - 2026-10-27

Validierung: 259 Tests erfolgreich, Module zusätzlich mit dem vorhandenen Kalender geprüft.

- Uni-Module erzeugen automatisch Vor- und Nacharbeit ohne manuell angelegte Themen. Mehrere Veranstaltungen desselben Moduls und Tages werden gebündelt.
- Neue Termine, Import, Absagen und Änderungen verteilen flexible Modulphasen neu; Wege, Pausen, Lernorte und Tagesgrenzen bleiben berücksichtigt.
- Erledigte Phasen bleiben erledigt, tatsächliche Dauern verbessern spätere Schätzungen. Konflikte und nicht platzierbare Phasen sind sichtbar.
- Wochenenden und andere ausgeschaltete Lerntage werden bei Vor-/Nacharbeit berücksichtigt. Test-App-Starts verwenden eine eigene temporäre Datenbank.

## [0.2.3.0] - 2026-10-27

### Added

- Eigener Kalender mit manuellen Terminen, Wochenserien, kontrolliertem ICS-Import und Wiederimport.
- Lokale Lernplanung mit Themen, Bewertungen, Prüfungsdaten, Fahrtwegen und automatisch aktualisierten Vorschlägen.
- Projektübersicht auf GitHub mit echten App-Screenshots aus einer isolierten Demo, Einrichtung und Entwicklungsdokumentation.

### Changed

- Kompakter Menüleisten-Überblick mit einem Quick-Actions-Button und nativem Liquid-Glass-Hintergrund auf unterstützten Systemen.
- Ernährung, Training und Gewicht sind unter Gesundheit gruppiert; Einstellungen öffnen in einem eigenen Fenster über ⌘,.
- Erweiterte Gesundheits-, Finanz-, Export- und Telegram-Abläufe aus dem gesicherten Arbeitsstand sind im veröffentlichten Quellstand enthalten.
- Uni-Pausen bleiben auf dem Campus. Nach dem letzten Uni-Termin geht es zuerst nach Hause; spätere Trainingsfahrten starten von Zuhause.
- Eigene App-Kennung und Datenkopie halten die Kalender-Preview vom gesicherten Stand 0.1 getrennt.

### Fixed

- Fahrten über Mitternacht werden auch an den Grenzen des angezeigten oder geplanten Zeitraums reserviert.
- Fehlerhafte ICS-Felder mit leerem Namen erzeugen eine Warnung statt eines Absturzes.
- Lernbewertungen verwenden einen gemeinsamen Zeitstempel für die tatsächlich bestätigte Dauer.

Validierung: 240 Tests erfolgreich; Release-Build sowie native Ansichten geprüft.

## 0.2.2 — 27.10.2026

- 235 Tests erfolgreich, zusätzlich mit dem eingetragenen Uni-Stundenplan und Fußballtraining geprüft.

- Nach dem letzten Uni-Termin zuerst nach Hause; spätere Trainingsfahrten beginnen von Zuhause. Uni-Pausen bleiben auf dem Campus.
- Zu knappe Heimwege erzeugen einen Hinweis; eine direkte Weiterfahrt benötigt eine bekannte passende Dauer.
- Lernvorschläge berücksichtigen den tatsächlichen Lernort nach dem Heimweg. Fixierte oder laufende Konflikte bleiben sichtbar.

## 0.2.1 — 26.10.2026

- 231 Tests erfolgreich; Wege zusätzlich mit dem vorhandenen persönlichen Stundenplan geprüft.

- Automatische Hin-, Rück- und Weiterfahrten erscheinen im Kalender und sperren dieselben Zeiten für Lernvorschläge.
- Uni-Pausen bleiben vor Ort, auch wenn Lernen auf dem Campus ausgeschaltet ist. Keine automatischen Heimweg-Umwege zwischen auswärtigen Terminen.
- Fehlende Rückfahrtdauern übernehmen zunächst die Hinfahrtdauer, sichtbar gekennzeichnet und separat einstellbar. Direkte Verbindungen zum Training bleiben eigene Wege.

## 0.2 — 26.10.2026

- Eigener Kalender mit manuell gepflegten Terminen und Wochenserien sowie kontrolliertem ICS-Stundenplan-Import.
- Lernplanung über 14 Tage mit Wegen, Lernorten, Pausen, Tagesgrenze und Prüfungsterminen; gültige Vorschläge bleiben bei Änderungen möglichst erhalten.
- Fixieren, Verschieben, Auslassen und bewertete Wiederholungen mit tatsächlicher Dauer. Transparente Heuristik passt Intervalle und Dauer an Rückmeldungen an.
- Separate App-Kennung und Datenkopie schützen den gesicherten Stand 0.1. Kalenderdaten sind in SQLite-, JSON- und mehrteiligen CSV-Sicherungen enthalten.
- 224 Tests erfolgreich, einschließlich der bestehenden 195 Tests.
