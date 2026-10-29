# AboLife 0.4 – Projektüberblick

## Problem und Produkt

Kalender, Lernen, Gewohnheiten und Budget beeinflussen sich im Alltag, liegen aber oft in getrennten Werkzeugen. AboLife verbindet sie in einer nativen Mac-Anwendung und ergänzt einen persönlichen mobilen Zugriff.

Die wichtigste Einschränkung der Lernplanung: Eine freie Uhrzeit ist nicht automatisch ein geeigneter Lernblock. Uni-Aufenthalt, Fahrtwege, Pausen, erlaubte Wochentage und Tageslimits müssen berücksichtigt werden. Fixierungen und erledigte Einheiten dürfen nicht still verschwinden.

## Technische Entscheidungen

| Entscheidung | Begründung / Grenze |
|---|---|
| SwiftUI für den Mac | Native Fenster, Menüleiste und Navigation; Plattformbindung ist bewusst akzeptiert. |
| SQLite über GRDB | Transaktionen, Migrationen und typisierte Repositories; keine Datenbankdatei über Netzlaufwerke teilen. |
| Gemeinsamer Swift-Planer | Dieselben Terminregeln in Mac und Homelab. Der Server benötigt eine zusätzliche Swift-Laufzeit. |
| Node ohne npm-Pakete | Kleine Abhängigkeitsfläche; HTTP, SQLite und Kryptografie kommen aus der Standardbibliothek. |
| Versioniertes Dokument | Einfacher persönlicher Abgleich mit History und klaren Revisionen; bei vielen Datensätzen weniger effizient als ein vollständiges Änderungsprotokoll. |
| Drei-Wege-Zusammenführung | Unabhängige Änderungen kombinieren; fachliche Widersprüche benötigen eine Entscheidung. |
| Dauerhafte Anfragekennungen | Ein unklarer Netzwerkabbruch darf bei erneutem Senden keine doppelte Ausgabe erzeugen. |
| Privates Homelab | Datenhoheit und mobiler Zugriff; Einrichtung, Verfügbarkeit und externe Sicherung bleiben eigene Betriebsaufgaben. |

## Code zum Einstieg

- `AboLife/Features/Calendar/StudyPlannerEngine.swift`: Verfügbarkeit, Intervalle und Platzierung.
- `AboLife/Features/Calendar/ModuleStudyPlanner.swift`: modulbezogene Vor-/Nacharbeit.
- `AboLife/Sync/SharedDataService.swift`: Datenvertrag, Revisionen, Schlüsselbund und Zusammenführung.
- `web/server.mjs` und `web/state.mjs`: authentifizierte API, Transaktionen und fachliche Aktionen.
- `AboLife/Persistence/BackupService.swift`: konsistente Sicherungen und transaktionaler Restore.
- `AboLifeTests/CalendarPlannerTests.swift`, `SharedDataAndNewsTests.swift` und `web/test/`: Beispiele für Tests an Fach- und Systemgrenzen.

## Für eine Präsentation

Mit der isolierten Demo beginnen, den Kalender und ein Lernfenster erklären, dann eine Ausgabe oder Gewohnheit erfassen. Anschließend anhand eines konkreten Tests zeigen, wie ein Termin-/Wegekonflikt oder eine wiederholte Netzwerkübertragung behandelt wird. Tatsächlich geprüfte Funktionen und noch offene Geräte-/Betriebsprüfungen getrennt benennen.

Das Projekt ist ein lernendes persönliches Entwicklungsprojekt und wurde mit KI-Unterstützung weiterentwickelt. Eine Präsentation sollte die eigenen Entscheidungen und die tatsächlich verstandenen Codepfade erklären, ohne Produktionserfahrung oder manuelle Autorenschaft jeder Zeile zu behaupten.
