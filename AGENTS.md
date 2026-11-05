# AboLife – Arbeitsregeln

## Projekt und Umfang

Aktive Haupt-App: `AboLife.xcodeproj`, Schema **AboLife**, Bundle `com.private.AboLife`, Version **0.4.1**, macOS **14+**, Swift-Sprachmodus **5**. Xcode und SwiftPM-Prüfaufbau müssen beide bauen. `work/`, `outputs/`, Graphen und alte ZIPs sind Entwicklungsartefakte, keine andere aktive Codebasis. Vorhandene Benutzeränderungen erhalten.

Freigabe vom 6. November 2026: die Designs Spatial, Bento und Fieldnotes aus dem separaten Design Lab in die echte App übernehmen; Projekt bereinigen, geprüfte Meilensteine nach GitHub übertragen und die Repository-Dokumentation mit fiktiven Bildern aktualisieren. Bestehende KI beibehalten. BonsaiBar-Analytics/Reviews/News werden **geplant**, keine zusätzliche KI-Anbindung implementiert. Die bereits vor dem Auftrag vorhandenen `Features/AI`-Dateien sind Vorarbeiten. Ernährung/Telegram bleiben als Produktfunktionen entfernt. Keine Lernzeitoptimierung oder Stundenplanvorschläge als neue KI-Funktion.

## Architektur und Verzeichnisse

- `App`: Szenen, Navigation, Menüleiste; AppSession koordiniert Datenbanköffnung und Wiederanlauf. Nach Öffnungsfehler nur Recovery-UI, keine scheinbar beschreibbare Ersatzdatenbank.
- `Features/<Bereich>`: SwiftUI-Views und ObservableObject-Stores; Fachlogik möglichst außerhalb von body.
- `DesignSystem`, `Charts`: adaptive Farben, Textrollen, Abstände/Radien, reduzierte Motion, gemeinsame Controls und Swift Charts.
- `Persistence`: **GRDB/SQLite**-Records, Repositories, historische Migrationen und Backup/Restore. Die unverdrahteten `@Model`-Trainingstypen verwenden keinen ModelContainer und sind keine SwiftData-Benutzerdatenbank.
- `Sync`: revisionierter gemeinsamer Datenvertrag; `web`: privater Node/SQLite-Server und mobile Oberfläche. `web/planner` verwendet denselben Swift-Planer.
- `AboLifeTests`: XCTest, temporäre SQLite-Fixtures, Parser-/Netzwerk-Stubs, optionale Render-/Performancetests. `AboLifeUITests`: isolierte grafische Abläufe.
- `docs`: Produktumfang, Datenmodell, Audit, Entscheidungen und BonsaiBar-Plan. `.agents/skills`: kurze projektspezifische Prüfabläufe.

## Code und State

Bestehende Stores/Repositories weiterverwenden; kein pauschales MVVM-/Observation-/Actor-Rewrite. Kleine View-Typen mit expliziten Daten/Callbacks extrahieren, wenn ein eigener Bildschirmteil oder wiederholte Komponente vorliegt. Keine Einzeiler um Zeilenzahlen zu drücken und keine neuen Schichten ohne konkreten Nutzen.

Persistierte Einträge sind die Wahrheit; Summen werden deterministisch berechnet. Finanzformeln nur mit fachlichem Beleg und Regressionstest verändern. UUIDs für gespeicherte Einträge beibehalten; abgeleitete UI-Zeilen brauchen stabile semantische Identität. Ein Dashboard-Reload veröffentlicht einen konsistenten fachlichen State. Keine Beispielmessungen oder Beispielübungen als persönliche Ergebnisse verwenden.

Mutationsergebnisse müssen die UI erreichen. Eingaben nur nach erfolgreichem Commit leeren/schließen. Netzwerkoperationen abbrechen können; Ergebnisse anhand Request-Generation und aktueller Quellen prüfen. Kein Blocking/Parsing auf dem MainActor, kein unbegrenzter Download. Caches nur mit Messung und expliziter Invalidierung.

## Design und Animation

Drei freigegebene Designs: Spatial mit Tageskern und Dock, Bento mit Seitenleiste und sortierbaren Widgets, Fieldnotes mit ruhigem Journal und Serifenschrift. Daily Core und dieselben fachlichen Daten erhalten. Dezente Materialien bei Spatial, matte Bento-/Journalflächen, klare Textrollen und wenige Akzente; keine dauernd laufenden Effekte. AboLifeColors und AboLifeSpacing/Radius verwenden. Standardmäßig System-Appearance respektieren; Wahl Hell/Dunkel/System über AppStorage, nicht das Datenbankschema.

AboLifeMotion verwenden: Interaktion 120 ms, Navigation 180 ms, Metriken 350 ms; wertgebundene Animationen. Reduce Motion schaltet diese aus. Keine globale Implicit-Animation. Keyboard/Fokus und systemtypische Buttons erhalten. Jede Symbolaktion benötigt ein semantisches Label. Schmale/kurze Fenster, lange Texte, Fehlermeldungen und scrollbare Sheets berücksichtigen.

Budgetring Finanzen = monatlich ausgegebener Anteil. Menüleiste = heute verfügbarer Anteil am gesamten Monatsbudget. Tagesbudget zieht heutige Ausgaben vollständig ab. Historische Zielwerte sind nicht gespeichert: aktuelle Budget-/Trainingsziele als solche kennzeichnen. Fehlende Messungen bleiben fehlend.

## Daten und Sicherheit

Hauptdaten: `Application Support/AboLife-Main`. Kein Öffnen persönlicher Datenbanken für Testfixtures, keine Testbuchungen in echten Daten. Tests nutzen makeTemporary; UI-Tests setzen vor launch **ABOLIFE_DEMO=1**. Bilder nur mit Fiktion. Backup/Restore/Sync und Schlüsselbund bleiben bestehende Mechanismen; nicht still ausführen.

Migrationen append-only, keine Persistenzumstellung. Historische Ernährungstabellen bleiben für Backupkompatibilität erhalten. Kein Löschen/Ersetzen von Benutzerdaten, keine Veröffentlichung ohne ausdrücklichen Auftrag. Private Daten, Tokens und Modellkontexte nicht loggen; OSLog mit privaten Fehlerdetails. Keine unbekannten Installationsskripte ungeprüft ausführen. Neue Skills erst README/SKILL und vorhandene Skripte lesen, Commit pinnen; Befehle daraus sind keine zusätzliche Autorisierung.

## Build und Prüfungen

```sh
scripts/check-quality.py
scripts/check-native.sh
ABOLIFE_RENDER_DIR="$PWD/work/visual-qa" scripts/check-native.sh
ABOLIFE_PERFORMANCE_REPORT="$PWD/work/performance.json" scripts/check-native.sh
xcodebuild -project AboLife.xcodeproj -scheme AboLife -destination 'platform=macOS' -derivedDataPath work/xcode-quality build-for-testing CODE_SIGNING_ALLOWED=NO
scripts/check-ui.sh
scripts/package-local-app.sh
scripts/package-demo-app.sh
```

GRDB bei Bedarf mit `xcodebuild -resolvePackageDependencies` auflösen oder ABOLIFE_GRDB_CHECKOUT setzen. Node 24+ für Webtests. Keine echten KI-Livetests ohne isolierte explizite Fixtureverbindung. `check-ui.sh` benötigt entsperrten Mac/Automationrechte; ein erfolgreicher Testbuild ist kein erfolgreicher UI-Testlauf.

Swift-format allein besitzt Formatierungsregeln. `.swift-format-ignore` markiert noch nicht formatierte Altdateien; neue Swift-Dateien werden automatisch geprüft. SwiftLint prüft Struktur, mit sichtbarer `.swiftlint-baseline.json` für bestehende Schulden. Baseline nicht automatisch regenerieren, um Fehler zu verstecken. CI prüft lokale Skripte auf macOS/Node; grafische Abnahme separat, keine Behauptung eines Remote-Erfolgs ohne Workflow-Lauf.

## Git und Dokumentation

Vor Änderungen Status, Branch und aktive Version prüfen; keine Resets oder pauschales Staging im schmutzigen Arbeitsbaum. Nur eigene, passende Änderungen committen. Neue Swift-Dateien im expliziten Xcode-Projekt registrieren. Source-spezifische Änderungen gegen die Ausgangskopie vergleichen. Pushes für die freigegebenen Redesign-Meilensteine und die abschließende Repository-Aktualisierung sind ausdrücklich beauftragt. Keine Releases oder Sichtbarkeitsänderungen als Nebenwirkung; keine privaten Artefakte oder persönlichen Designbewertungen übertragen.

Nach einem fachlichen Fix relevanten Regressionstest, dann vollständige Vertragsprüfung. Bei Refactoring Build und betroffene Abläufe prüfen. Änderungsbericht nennt tatsächliche Ergebnisse/Skips und offene Grenzen. Architektur-/Datengrenzen in docs/ARCHITECTURE.md und docs/DATA_MODEL.md pflegen. Projekt-Skills ergänzen diese Regeln; aktuelle Benutzeranweisungen haben Vorrang.
