# ROADMAP.md

# AboLife Roadmap

## Phase 0: Konzept und Spezifikation

Ziel: Projekt klar eingrenzen.

Aufgaben:

- Product Spec finalisieren
- MVP Scope finalisieren
- Architekturentscheidung treffen
- Datenmodell v1 definieren
- UI-Regeln festlegen
- Codex Rules festlegen

Ergebnis:

- stabile docs-Dateien
- kein App-Code nötig

## Phase 1: UI-Prototyp mit Mock-Daten

Ziel: Gefühl der App validieren.

Aufgaben:

- SwiftUI macOS-Projekt anlegen
- Sidebar erstellen
- Dashboard mit Mock-Daten bauen
- Core Ring mocken
- Progress Cards bauen
- Quick Add UI mocken
- Empty/Partial/Full States vorbereiten

Nicht tun:

- keine echte Datenbank
- keine Telegram-Integration
- keine KI
- keine iPhone-App

## Phase 2 / 3A: Lokale Persistenz

Ziel: echte Speicherung einführen.

Aufgaben:

- SQLite/GRDB Setup
- Datenbankkonfiguration
- erste Migrationen
- Repositories
- Seed-Daten
- Tests für Datenbanklogik

Ergebnis:

- lokale Datenbank läuft
- Mock-Daten können durch echte Daten ersetzt werden

Stand Phase 3A:

- GRDB + SQLite sind als lokales Persistenzfundament eingebunden.
- Basis-Migrationen, Records und einfache Repositories existieren.
- Dashboard und Quick Add laufen weiterhin mit In-Memory-Mock-State.
- Phase 3B verbindet Quick Add schrittweise mit den Repositories.

Stand Phase 3B:

- Quick Add schreibt Mahlzeiten, Trainings, Ausgaben, Habits und Gewicht lokal in SQLite.
- Dashboard lädt erste persistierte Summaries für Tag, Woche und Monat.
- Detailmodule, komplexe Aggregationen und WeeklyReview-Persistenz bleiben spätere Phasen.

## Phase 3: Quick Add + erste echte Einträge

Ziel: tägliche Nutzung ermöglichen.

Aufgaben:

- Quick Add für NutritionEntry
- Quick Add für WorkoutSession
- Quick Add für FinanceEntry
- Quick Add für HabitEntry
- Quick Add für BodyMetricEntry
- Dashboard aktualisiert sich aus echten Daten

## Phase 4: Kernmodule

Ziel: Module nutzbar machen.

Reihenfolge:

1. Ernährung
2. Training
3. Finanzen
4. Habits
5. Körperwerte

Je Modul:

- Liste
- Erstellen
- Bearbeiten
- Löschen
- einfache Auswertung
- Empty State

## Phase 5: Weekly Review und Statistiken

Ziel: App wird zu einem Lernsystem.

Aufgaben:

- Weekly Review Screen
- Wochenzusammenfassung
- 7-Tage-Trends
- Budgettrend
- Habit-Completion
- Trainingsfrequenz

## Phase 6: Backup und Export

Ziel: Vertrauen in lokale Daten.

Aufgaben:

- SQLite Backup
- JSON/CSV Export
- Restore-Konzept
- Export UI

## Phase 7: spätere Integrationen

Nur nach stabilem MVP:

- Telegram Bridge
- App Intents / Shortcuts
- iPhone-App
- Cloud-Sync
- Apple Health
- Kalender
- KI-Auswertung

## Nicht parallel bauen

Nicht gleichzeitig bauen:

- iPhone + Telegram + KI
- Food Search + Barcode + OCR
- Cloud Sync + lokale Persistenz
- Health + Schlaf + Sensorik
- mehrere große Module ohne fertigen Quick Add
