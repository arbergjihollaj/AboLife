# Prüfstand – 5. November 2026

Aktueller lokaler Lauf: **276 native XCTest-Tests entdeckt, 273 ausgeführt, 3 optionale KI-Livetests übersprungen, 0 Fehler**; **26 Node-Tests bestanden**. Die optionalen Render- und Performancetests wurden mit gesetzten Ausgabepfaden tatsächlich ausgeführt. 16 isolierte Dashboard-Komponentenrenderings decken Hell/Dunkel, 760/1100 pt, leeren Stand, Budgetüberschreitung und lange Texte ab.

Xcode baut App, Unit- und UI-Testtarget. Nach Entsperren des Macs wurden **alle drei grafischen Abläufe tatsächlich bestanden**: Bereichswechsel, Ausgabenvalidierung/-speicherung/Escape sowie Darstellungseinstellungen. Der Runner wird lokal ad-hoc signiert; der erste unsignierte Start wurde vor der Testverbindung beendet. UI-Tests adressieren ausdrücklich `com.private.AboLife.demo` mit ABOLIFE_DEMO=1; AppSession trennt zusätzlich Einstellungen/Auto-Sync von persönlichen Präferenzen. Die Demo muss vorher mit den Paketierungsskripten erstellt werden.

Live geprüft: Hell/Dunkel, Hauptfenster, Initialfokus und vollständig scrollbarer Trainingsdialog samt Escape. Die visuelle Prüfung fand einen weiteren echten Fehler: Ein gestriges Workout erschien als „Training heute erledigt“. Tagesstatus und Wochenfortschritt sind jetzt getrennt, durch Regressionstest und Demo-UI-Assertion abgesichert. Noch offen: gesprochener VoiceOver-Durchlauf, interaktives Resize auf kleine Hauptfenster sowie Motion-/FPS-/Start-/RAM-Profiling. Die 16 Komponentenreferenzen ersetzen diese Prüfungen nicht.

`scripts/check-quality.py` besteht: Swift-format prüft 34 neue oder überarbeitete Swift-Dateien; 79 alte Pfade sind ausdrücklich nur von Formatierung ausgenommen. SwiftLint prüft alle App-/Unittestdateien; 24 vorhandene strukturelle Befunde sind sichtbar baseliniert, neue Befunde lassen das Gate scheitern. Der lokale Artefakt-/Credentialscan findet keine Treffer.

Performance: 20 Wiederholungen, Debug, 5.000 synthetische Buchungen und 120 Workouts, temporäre SQLite. Budgets P95: Dashboard <100 ms, Finanzen <100 ms, Statistiken <200 ms. Messungen ohne parallelen Build; Rohdaten unter work/evolution-baseline und work/evolution-after. Finale Werte und Grenzen im [Abschlussbericht](docs/EVOLUTION_REPORT.md). Ein Instruments-Time-Profiler-Trace ist zusätzlich vorhanden; wegen Instrumentierungs-Overhead kein SLA-Testlauf und keine GUI-FPS-Messung.

```sh
scripts/check-quality.py
ABOLIFE_RENDER_DIR="$PWD/work/visual-qa" ABOLIFE_PERFORMANCE_REPORT="$PWD/work/performance.json" scripts/check-native.sh
scripts/package-local-app.sh
scripts/package-demo-app.sh
scripts/check-ui.sh
```

Der folgende bisherige Prüfstand beschreibt vorhandene Vertrags-/Betriebsprüfungen. Remote-CI, Homelab/iPhone und echte Inferenzabnahmen werden dadurch nicht neu ausgeführt.

---

# Prüfstand 0.4.0

- 232 native XCTest-Prüfungen über den lokalen Swift-Package-Prüfaufbau mit vorhandenem GRDB-Checkout.
- 26 Node-Prüfungen einschließlich tatsächlicher In-Process-Serververarbeitung, SQLite-Persistenz, CSRF/HTTPS-Vertrag, Revisionen, Historie, idempotenten Offline-Übertragungen, RSS, Finanzplanung, Trainingsplänen und konsistenter Online-Sicherung.
- Clienttests führen die echte `app.js` in einer kleinen DOM-Testumgebung aus: Routen, HTML-Escaping, Offlinevormerkung/Übertragung, Schutz wiederholter Tagesänderungen, Abmeldung, Übernachttermine und Tagesbudget.
- Swift↔Web-Datenvertrag einschließlich Übungen/Sätzen; Tabellenschema wird mit der tatsächlichen GRDB-Datenbank verglichen.
- Der gemeinsame Swift-Planer wird separat kompiliert und vom Node-Test als Unterprozess aufgerufen. Die vorhandenen nativen Kalenderprüfungen decken seine Regeln ab.
- Neue native Prüfungen für unabhängige Feld-/Datensatzänderungen, echte Konflikte, doppelte Tagesdatensätze, Tagesbudget und JSON-/CSV-/SQLite-Restore einschließlich ungültiger Quelldaten.
- Gestartete Mac-App visuell geprüft: Dashboard, vollständig sichtbares Ausgabenformular und Einstellungen einschließlich Verbindung/Restore. Dabei wurden keine Testbuchungen in der Nutzerdatenbank angelegt.
- Optimierter nativer Release-Build mit Assetkatalog und Ad-hoc-Signierung über `scripts/package-local-app.sh`.
- Compose-Konfiguration syntaktisch mit `docker compose config --quiet` geprüft. Dies startet keinen Container und prüft weder Linux-Images noch Zertifikate.

## Reproduzieren

```sh
scripts/check-native.sh
scripts/package-local-app.sh
scripts/package-homelab.sh
```

Optional `ABOLIFE_GRDB_CHECKOUT` auf einen existierenden GRDB.swift-Checkout setzen. Der Prüfaufbau verwendet synthetische Daten und temporäre Datenbanken, nicht die Nutzerdatenbank. Ohne die vom Skript gesetzten Vertrags-/Planerpfade überspringt ein alleiniger `node --test web/test/*.test.mjs` die entsprechenden Integrationstests.

## Noch offen

Der reguläre Xcode-Projektlauf scheitert an nicht beschreibbaren Paket-/Modulcaches und der eingeschränkten Umgebung. Die alternative Swift-Kompilierung und die native Testsuite laufen.

SSH zum Zielserver meldet `Operation not permitted`; lokale TCP-Listener melden `listen EPERM`. Ein lokaler Docker-Daemon ist nicht verfügbar. Deshalb sind Containerbuild unter Linux, HTTP-/HTTPS-Geräteabgleich, reale Sessionabläufe, Web-Live-News und echte mobile Browserdarstellung noch nicht geprüft.

Der Browser lehnt lokale Dateivorschauen aufgrund seiner URL-Richtlinie ab. Es wurde keine alternative Browseroberfläche zur Umgehung verwendet. Die Clienttests sind Logiktests und prüfen keine Pixel, iOS-Tastatur, Service-Worker-Installation/-Aktualisierung oder tatsächliche Safari-Speicherräumung. Diese Punkte bleiben ausdrücklich in `TODO.md` offen.

Die Hauptversions-Umstellung ergänzt Prüfungen für Preview-Vorrang, Legacy-Fallback und Schutz vorhandener Hauptdaten. Der Demomodus wird mit einer synthetischen temporären Datenbank geprüft.

## BonsaiBar-AI-Erweiterung

Der erweiterte Lauf enthält 252 native Tests. Zwei davon sind optionale echte Modelltests und werden ohne explizite lokale Fixture-Verbindung übersprungen; mit Testserver wurden alle 252 erfolgreich ausgeführt. Zusätzlich bestehen 26 Webtests. Die Tests prüfen insbesondere Bereichsfilter, unbekannte Aktionsfelder/Fächer, fehlende Bestätigung, widerrufene Grants, veraltete Vorschau, Replay, freie/belegte Lernfenster, Erhalt vorhandener Reviewnotizen und additive Migration samt Sicherung.

Echte KI-Tests verwenden ausschließlich fiktive Daten in temporären Datenbanken. Die native Demo verwendet ebenfalls isolierte Daten. Schema-begrenzte echte JSON-Ausgabe samt Bestätigung wurde zusätzlich separat mit einer festen Fach-Enum geprüft. Für diesen Lauf `ABOLIFE_BONSAI_LIVE_CONNECTION` auf eine ausdrücklich als Testfixture eingerichtete lokale Verbindung setzen; niemals persönliche Exporte als Testdaten verwenden. Der normale `scripts/check-native.sh` benötigt keinen laufenden Modellserver.
