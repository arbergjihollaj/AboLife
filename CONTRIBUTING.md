# Entwicklung

AboLife 0.4 ist die Hauptversion. Die App nutzt SwiftUI, GRDB/SQLite und einen optionalen persönlichen Webserver. Designänderungen sollen den bestehenden Dashboard-Aufbau und die App-Farben erhalten.

## Lokal starten

`AboLife.xcodeproj` öffnen, die gepinnte Swift-Package-Abhängigkeit auflösen und das Schema **AboLife → My Mac** starten. Die Mac-Kernfunktionen benötigen keine Zugangsdaten. Node 24 wird für die Webtests und den Datenvertrag benötigt; es gibt keine npm-Abhängigkeiten.

```sh
scripts/check-native.sh
scripts/package-local-app.sh
```

Falls GRDB nicht im Xcode-Standardcache liegt, `ABOLIFE_GRDB_CHECKOUT` auf einen vorhandenen Checkout setzen. Alternativ zunächst `xcodebuild -resolvePackageDependencies -project AboLife.xcodeproj -scheme AboLife -clonedSourcePackagesDirPath work/dependencies` ausführen und den dortigen Checkout verwenden.

## Änderungen prüfen

- Berechnungen und Persistenz mit aussagekräftigen Tests und festen Zeitwerten prüfen.
- Schemaänderungen mit Migration und Swift↔Web-Vertrag abstimmen.
- Bei Wiederherstellung und Synchronisierung niemals still einen konkurrierenden Stand überschreiben.
- Änderungen und tatsächlich ausgeführte Prüfungen im Pull Request benennen.
- Screenshots ausschließlich mit dem isolierten Demomodus erstellen.
- `python3 scripts/check-publication.py` vor einem Push ausführen.

Die Haupt-App speichert unter `AboLife-Main`. Beim ersten Start kopiert sie einen vorhandenen Preview-Stand, ersatzweise den älteren 0.1-Stand. Die Quell-Datenbanken bleiben unverändert; spätere Preview-Einträge werden nicht automatisch erneut übernommen.

Der Quellcode steht für Portfolio-/Code-Review zur Verfügung; Nutzungsrechte regelt [LICENSE](LICENSE).
