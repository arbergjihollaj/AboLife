# Prüfungen

AboLife verwendet XCTest. Die Tests laufen lokal auf einem Mac im Schema `AboLife`:

```bash
xcodebuild test -project AboLife.xcodeproj -scheme AboLife -destination 'platform=macOS'
xcodebuild build -project AboLife.xcodeproj -scheme AboLife -configuration Release -destination 'platform=macOS'
```

## Dokumentierter Stand

Release 0.2.3 · Veröffentlichung 0.2.3.0 · 27. Oktober 2026 · Xcode 27.1 auf Apple Silicon.

240 Tests erfolgreich. Dazu gehören die bestehenden Fachbereiche und Prüfungen für Kalender-Persistenz, Versionskopie, Schutz der alten Datenbank, Serien/Sommerzeit, ICS-Fehler und Wiederimport, Wege einschließlich Mitternacht und Planungsgrenzen, Lernorte, Tageslimits, manuelles Verschieben, Fixierungen, Rückmeldungen und Export.

Es wird keine prozentuale Testabdeckung behauptet. Andere macOS-/Xcode-Kombinationen sind mit diesem Prüfstand nicht separat bestätigt. Der Build-Zielwert ist macOS 14; das native Liquid Glass verwendet macOS 26 oder neuer.

## Oberfläche

Der Kalender wurde mit dem persönlichen Datenbestand lokal geprüft. Die Bilder im Repository stammen dagegen ausschließlich aus einer isolierten Instanz mit fiktiven Daten. Kalender, Lernthemen, Dashboard und Finanzen wurden dort direkt in der nativen Oberfläche geöffnet.

Persönliche SQLite-Dateien, Zugangsdaten, Test-Ergebnisbündel und lokale Build-Produkte werden nicht eingecheckt. Allgemeine Hinweise zur Screenshot-Erstellung stehen in [SCREENSHOTS.md](docs/SCREENSHOTS.md).
