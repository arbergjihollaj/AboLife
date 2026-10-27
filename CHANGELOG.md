# Änderungen

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
