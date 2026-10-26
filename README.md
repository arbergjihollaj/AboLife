# AboLife Kalender 0.2

Lokale macOS-App für Alltag, Gesundheit, Finanzen und jetzt einen eigenen Kalender mit Lernplanung. Die Kalender-Version läuft als getrennte App neben dem gesicherten Stand 0.1. Die vorhandenen Menüs, Farben und Gesundheitsbereiche bleiben erhalten.

## Kalender starten

1. Öffne die App „AboLife Kalender“ und den Bereich **Kalender**.
2. Stelle **Planungszeiten** und deine tatsächlichen Hin-/Rückwege ein.
3. Erfasse Uni, Training und andere Termine oder importiere einen lokalen ICS-Stundenplan mit Vorschau.
4. Lege Lernthemen an. Bewerte erledigte Wiederholungen, damit Intervalle und geschätzte Dauer angepasst werden.

Die [Anleitung](docs/CALENDAR_GUIDE.md) erklärt Importgrenzen, Zeitplanung und die transparente Wiederholungsregel. Sie ist eine Heuristik für Themenblöcke, kein trainiertes Gedächtnismodell und keine Garantie für optimalen Lernerfolg.

## Versionen und Daten

- **0.1:** Daten unter `~/Library/Application Support/AboLife`, gesicherter Quellstand als Tag `abolife-v0.1-stable-20261026`.
- **0.2:** eigene App-Kennung `com.private.AboLife.calendarPreview`, Daten unter `~/Library/Application Support/AboLife-Calendar-Preview`.
- Beim ersten Start kopiert 0.2 den aktuellen alten Datenbestand mit nur lesendem Zugriff. Neue Migrationen betreffen ausschließlich die Kopie. Anschließend bleiben beide Datenstände getrennt.
- App- und Quellcodearchiv von 0.1 wurden vor der Erweiterung erstellt. Für die Rückkehr öffnest du die alte App; eine Rückwärtsmigration ist nicht nötig.

## Entwickeln und prüfen

Öffne `AboLife.xcodeproj`, verwende das Schema `AboLife` und das Ziel „My Mac“. Der Zweig `codex/calendar-v0.2` enthält die Erweiterung. `xcodebuild test -project AboLife.xcodeproj -scheme AboLife -destination 'platform=macOS'` führt die Tests aus. Aktuell: **224 Tests erfolgreich**, einschließlich 195 bestehender Tests und 29 Kalender-/Datenschutz-/Backup-Prüfungen. Release-Build wird ebenfalls geprüft.

## Vorhandene Bereiche

- Phase 7F stabilisiert den lokalen MVP.
- Dashboard, Ernährung, Training, Finanzen, messbare Gewohnheiten, Wochenreview, Settings, Quick Panels sowie Backup/Export sind nutzbar.
- Trainieren wird aus abgeschlossenen `WorkoutSession`-Datensätzen abgeleitet und nicht doppelt als Habit gepflegt.
- SQLite-Backups, JSON-Exporte und CSV-Dateien für Numbers bleiben lokal im Backup-Ordner auf diesem Mac.
- Telegram kann per lokalem Bot-Token und erlaubter Chat-ID Quick Inputs, Erinnerungen, HTML-Snapshots und Barcode-Ernährung verarbeiten.
- Barcode-Ernährung: Ein Foto eines Lebensmittel-Barcodes wird temporär geladen, lokal per Apple Vision erkannt, über Open Food Facts nachgeschlagen und erst nach Mengenwahl plus finaler Bestätigung als Mahlzeit gespeichert.
- Grenzen: Open Food Facts benötigt Internetzugang, Produkte oder Nährwerte können fehlen, und das Barcode-Foto muss lesbar sein. Fehlende Kalorien oder Proteinwerte werden nicht geraten.
- Datenschutz: Telegram-Token werden nicht in der App-Datenbank gespeichert oder exportiert; Barcode-Fotos werden nur temporär verarbeitet und danach bestmöglich gelöscht. Nur die konfigurierte `ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID` wird verarbeitet.
- Allgemeiner Daten-Restore, Cloud Sync, Accounts, iPhone, HealthKit, externe KI und Web sind nicht Teil des MVP. Der ICS-Stundenplan-Import gehört zu 0.2.
