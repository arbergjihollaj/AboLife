# Entwicklung

AboLife ist ein persönliches macOS-Projekt und befindet sich in der Preview-Phase. Änderungen sollten die lokale Datenhaltung, die vorhandenen App-Farben und die kurzen Alltagsabläufe erhalten.

## Lokaler Start

Öffne `AboLife.xcodeproj`, lasse Swift Package Manager die Abhängigkeiten auflösen und wähle `AboLife` → `My Mac`. Die Kernfunktionen benötigen keine Zugangsdaten. Telegram ist optional; reale Werte bleiben in deiner lokalen Umgebung und werden nicht in geteilte Xcode-Schemes geschrieben.

## Änderungen prüfen

- Halte einen zusammenhängenden Zweck pro Änderung fest.
- Ergänze bei Berechnungs- oder Persistenzänderungen aussagekräftige Tests mit festen Zeitwerten.
- Dokumentiere Datenbankänderungen mit Migration, Tests und einer Aktualisierung des Datenmodells.
- Führe die [Tests und den Release-Build](TESTING.md) aus.
- Erstelle Screenshots mit einer getrennten Demo-Datenbank. Lade keine privaten Stundenpläne, Gesundheitswerte, Buchungen oder Bot-Zugangsdaten hoch.
- Beschreibe im Pull Request das veränderte Verhalten und die tatsächlich ausgeführten Prüfungen.

Die Kalender-Preview und Version 0.1 verwenden getrennte Datenordner. Diese Grenze gehört zum Datenvertrag und muss erhalten bleiben.
