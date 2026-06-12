# ARCHITECTURE.md

# AboLife Architecture

## 1. Architekturziel

AboLife soll eine saubere, aber nicht übertriebene Architektur haben. Die App ist ein persönliches Projekt, soll aber langfristig wartbar bleiben.

Die Architektur soll unterstützen:

- Dashboard-first UI
- lokale Datenhaltung
- klare Feature-Module
- einfache Tests
- spätere Erweiterungen ohne frühen Overengineering-Aufwand

## 2. Plattform

Version 1 ist eine native macOS-App.

Empfohlener Stack:

- Swift
- SwiftUI
- Observation
- Swift Charts
- lokale Persistenz
- Swift Testing / XCTest

## 3. Persistenzentscheidung

Empfohlene Hauptentscheidung:

- SwiftUI + SQLite + GRDB

Grund:

- explizites Schema
- starke lokale Datenbank
- gute Aggregationen für Reviews und Trends
- Migrationen kontrollierbar
- Export/Backup einfacher nachvollziehbar
- später offen für weitere Integrationen

Alternative:

- SwiftData, wenn bewusst Apple-only, single-device und CRUD-first gearbeitet werden soll.

Für AboLife wird in Version 1 empfohlen:

> SwiftUI + SQLite + GRDB

Phase 3A legt dieses Persistenzfundament lokal an:

- `AboLife/Persistence/` enthält Datenbankkonfiguration, Migrationen, GRDB-Records und kleine Repositories.
- Die SQLite-Datei liegt im Application-Support-Ordner der App als `AboLife.sqlite`.
- Das Dashboard bleibt in Phase 3A noch auf dem In-Memory-Mock-State; echte Quick-Add-Anbindung folgt in Phase 3B.

Phase 3B verbindet die wichtigsten Quick-Add-Aktionen mit SQLite:

- `DashboardStore` bekommt `AppDatabase` injiziert und spricht nur mit Repositories, nicht direkt mit SQL.
- Nutrition, Workout, Finance, Habit und BodyMetric Quick Add schreiben lokal in SQLite.
- Dashboard-Karten nutzen erste berechnete Tages-, Wochen- und Monats-Summaries aus den Entries.

## 4. Architekturprinzipien

- Views enthalten keine Business-Logik
- Datenmodelle sind klar und klein
- Summen und Trends werden aus Entries berechnet
- keine persistierten Summen ohne Begründung
- keine externen Integrationen in Version 1
- kein unnötiges Clean-Architecture-Overengineering
- Feature-Ordner statt riesiger globaler Dateien
- jede Datenbankänderung braucht Migration

## 5. Grobe Ordnerstruktur

```text
AboLife/
├── App/
├── Foundation/
├── DesignSystem/
├── Persistence/
├── Features/
├── Charts/
├── Services/
├── PreviewSupport/
└── Tests/
```

## 6. Detailstruktur

```text
AboLife/
  App/
    AboLifeApp.swift
    AppRouter.swift
    AppCommands.swift
    Settings/

  Foundation/
    Types/
    Extensions/
    Formatters/
    DateAndTime/
    Validation/

  DesignSystem/
    Colors/
    Typography/
    CardStyles/
    Components/
    Icons/

  Persistence/
    Database/
      AppDatabase.swift
      DatabaseConfiguration.swift
    Migrations/
    Models/
    Repositories/
    Queries/
    SeedData/

  Features/
    Dashboard/
    Nutrition/
    Training/
    Finance/
    Habits/
    Review/
    BodyMetrics/

  Charts/
    CoreRingView.swift
    TrendChart.swift
    BudgetBarChart.swift
    ProgressViews.swift

  Services/
    BackupService.swift
    ExportService.swift
    ImportService.swift
    NotificationService.swift

  PreviewSupport/
    PreviewData.swift
    PreviewDatabase.swift
    SampleStates.swift

  Tests/
    Unit/
    Integration/
    UI/
```

## 7. Feature-Architektur

Jedes Feature enthält:

- View
- Store/ViewModel
- Form Views
- Feature-spezifische Components
- Preview States

Beispiel:

```text
Features/Nutrition/
├── NutritionView.swift
├── NutritionStore.swift
├── NutritionEntryForm.swift
├── NutritionDashboardCard.swift
└── NutritionPreviewData.swift
```

## 8. Datenfluss

```text
User Action
   ↓
SwiftUI View
   ↓
Feature Store
   ↓
Repository
   ↓
SQLite/GRDB
   ↓
Queries/Aggregations
   ↓
Dashboard Read Model
   ↓
UI Update
```

## 9. Services

Services sind nur für echte Infrastruktur zuständig:

- Backup
- Export
- Import
- Notifications
- spätere Telegram Bridge
- spätere Health Bridge
- spätere AI Bridge

Services dürfen nicht zum Ort für normale Feature-Logik werden.

## 10. Tests

Mindesttests:

- Berechnung von Tageskalorien
- Berechnung von Proteinfortschritt
- Monatsbudget-Rest
- Habit-Completion
- Weekly-Review-Aggregationen
- Datenbankmigrationen

## 11. Nicht in Version 1

Keine Architektur für:

- Cloud-Sync
- Telegram-Live-Sync
- iPhone-App
- Web-App
- HealthKit
- KI-Agenten
