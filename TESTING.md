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
