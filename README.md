# AboLife Codex Docs

Diese ZIP enthält die Markdown-Dokumente, die als Grundlage für Codex dienen sollen.

Empfohlene Nutzung:

1. ZIP entpacken.
2. Den Ordner `docs/` in dein AboLife-Projekt kopieren.
3. Erst danach Codex starten.
4. Codex immer zuerst diese Dokumente lesen lassen.

Enthalten:

- `docs/PRODUCT_SPEC.md`
- `docs/MVP_SCOPE.md`
- `docs/ARCHITECTURE.md`
- `docs/DATA_MODEL.md`
- `docs/UI_SPEC.md`
- `docs/ROADMAP.md`
- `docs/CODEX_RULES.md`

Wichtig:

AboLife v1 bleibt lokal, fokussiert und dashboard-first. Telegram ist als kontrollierter lokaler Bot-Kanal ergänzt; iPhone, Health, KI und Web bleiben spätere Erweiterungen.

Aktueller Stand:

- Phase 7F stabilisiert den lokalen MVP.
- Dashboard, Ernährung, Training, Finanzen, messbare Gewohnheiten, Wochenreview, Settings, Quick Panels sowie Backup/Export sind nutzbar.
- Trainieren wird aus abgeschlossenen `WorkoutSession`-Datensätzen abgeleitet und nicht doppelt als Habit gepflegt.
- SQLite-Backups, JSON-Exporte und CSV-Dateien für Numbers bleiben lokal im Backup-Ordner auf diesem Mac.
- Telegram kann per lokalem Bot-Token und erlaubter Chat-ID Quick Inputs, Erinnerungen, HTML-Snapshots und Barcode-Ernährung verarbeiten.
- Barcode-Ernährung: Ein Foto eines Lebensmittel-Barcodes wird temporär geladen, lokal per Apple Vision erkannt, über Open Food Facts nachgeschlagen und erst nach Mengenwahl plus finaler Bestätigung als Mahlzeit gespeichert.
- Grenzen: Open Food Facts benötigt Internetzugang, Produkte oder Nährwerte können fehlen, und das Barcode-Foto muss lesbar sein. Fehlende Kalorien oder Proteinwerte werden nicht geraten.
- Datenschutz: Telegram-Token werden nicht in der App-Datenbank gespeichert oder exportiert; Barcode-Fotos werden nur temporär verarbeitet und danach bestmöglich gelöscht. Nur die konfigurierte `ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID` wird verarbeitet.
- Restore/Import, Cloud Sync, Accounts, iPhone, HealthKit, KI und Web sind nicht Teil des MVP.
