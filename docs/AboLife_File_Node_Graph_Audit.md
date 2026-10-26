# AboLife Datei-Node-Graph Audit

Generiert am 2026-06-16 aus Strukturinformationen im Repository. Der Export enthält nur Dateipfade, Dateinamen, erkannte Symbolverweise und Architektur-Metadaten; keine App-Daten, Tokens, Chat-IDs, Finanzdaten, Mahlzeiten, Gewichte oder Backup-Inhalte.

## Zusammenfassung

- Dateien: 117
- Erkannte Verbindungen: 621
- Isolierte Dateien: 5
- Mögliche God-Files: 6
- Audit-Warnungen/Hinweise: 37

## Gruppenübersicht

- Features: 41
- Persistence: 24
- Docs: 10
- Telegram: 9
- Design: 8
- XcodeProject: 6
- DesignSystem: 5
- ExternalInput: 4
- Charts: 3
- Sonstiges: 3
- ProjectFiles: 2
- Shared: 1
- Tests: 1

## Top 20 zentrale Dateien

| Datei | Gruppe | Gesamt | Ausgehend | Eingehend | Zeilen |
| --- | --- | ---: | ---: | ---: | ---: |
| `AboLife.xcodeproj/project.pbxproj` | XcodeProject | 91 | 91 | 0 | 644 |
| `AboLifeTests/AboLifeTests.swift` | Tests | 54 | 52 | 2 | 2643 |
| `AboLife/Persistence/AppDatabase.swift` | Persistence | 38 | 2 | 36 | 46 |
| `AboLife/DesignSystem/AboLifeColors.swift` | DesignSystem | 28 | 0 | 28 | 111 |
| `AboLife/Features/Dashboard/DashboardStore.swift` | Features | 25 | 17 | 8 | 589 |
| `AboLife/Telegram/HtmlSnapshotExportService.swift` | Telegram | 24 | 19 | 5 | 260 |
| `AboLife/Persistence/DateIntervals.swift` | Persistence | 23 | 0 | 23 | 30 |
| `AboLife/DesignSystem/AboLifeTypography.swift` | DesignSystem | 22 | 0 | 22 | 15 |
| `AboLife/Telegram/TelegramBotModels.swift` | Telegram | 22 | 0 | 22 | 137 |
| `AboLife/ExternalInput/ExternalInputService.swift` | ExternalInput | 20 | 14 | 6 | 190 |
| `AboLife/App/AppRouter.swift` | Sonstiges | 19 | 14 | 5 | 223 |
| `docs/ARCHITECTURE.md` | Docs | 19 | 15 | 4 | 239 |
| `AboLife/Persistence/BackupService.swift` | Persistence | 18 | 12 | 6 | 863 |
| `AboLife/Persistence/Repositories/SettingsRepository.swift` | Persistence | 18 | 3 | 15 | 73 |
| `AboLife/DesignSystem/AboLifeCard.swift` | DesignSystem | 17 | 1 | 16 | 117 |
| `AboLife/Persistence/Seed/SeedData.swift` | Persistence | 17 | 1 | 16 | 13 |
| `AboLife/Telegram/DailySummaryService.swift` | Telegram | 17 | 12 | 5 | 99 |
| `AboLife.xcodeproj/xcshareddata/xcschemes/AboLife.xcscheme` | XcodeProject | 16 | 1 | 15 | 105 |
| `AboLife/DesignSystem/AboLifePremiumBackground.swift` | DesignSystem | 16 | 1 | 15 | 51 |
| `AboLife/Features/Dashboard/DashboardView.swift` | Features | 16 | 14 | 2 | 422 |

## Top 20 ausgehende Verbindungen

| Datei | Gruppe | Gesamt | Ausgehend | Eingehend | Zeilen |
| --- | --- | ---: | ---: | ---: | ---: |
| `AboLife.xcodeproj/project.pbxproj` | XcodeProject | 91 | 91 | 0 | 644 |
| `AboLifeTests/AboLifeTests.swift` | Tests | 54 | 52 | 2 | 2643 |
| `AboLife/Telegram/HtmlSnapshotExportService.swift` | Telegram | 24 | 19 | 5 | 260 |
| `AboLife/Features/Dashboard/DashboardStore.swift` | Features | 25 | 17 | 8 | 589 |
| `plan/ABOLIFE_VISUAL_OVERVIEW_FIXED.html` | Docs | 16 | 16 | 0 | 702 |
| `docs/ARCHITECTURE.md` | Docs | 19 | 15 | 4 | 239 |
| `plan/ABOLIFE_PROJECT_PLAN.md` | Docs | 16 | 15 | 1 | 683 |
| `AboLife/App/AppRouter.swift` | Sonstiges | 19 | 14 | 5 | 223 |
| `AboLife/ExternalInput/ExternalInputService.swift` | ExternalInput | 20 | 14 | 6 | 190 |
| `AboLife/Features/Dashboard/DashboardView.swift` | Features | 16 | 14 | 2 | 422 |
| `AboLife/Features/Review/WeeklyReviewStore.swift` | Features | 16 | 13 | 3 | 264 |
| `AboLife/Features/Training/TrainingStore.swift` | Features | 14 | 13 | 1 | 339 |
| `AboLife/Features/Statistics/StatisticsStore.swift` | Features | 15 | 12 | 3 | 181 |
| `AboLife/Persistence/BackupService.swift` | Persistence | 18 | 12 | 6 | 863 |
| `AboLife/Telegram/DailySummaryService.swift` | Telegram | 17 | 12 | 5 | 99 |
| `AboLife/Features/Training/TrainingView.swift` | Features | 14 | 11 | 3 | 758 |
| `AboLife/Features/Finance/FinanceView.swift` | Features | 13 | 10 | 3 | 320 |
| `AboLife/Features/Habits/HabitsView.swift` | Features | 13 | 10 | 3 | 435 |
| `AboLife/Features/Nutrition/NutritionView.swift` | Features | 14 | 10 | 4 | 667 |
| `AboLife/Features/Review/WeeklyReviewView.swift` | Features | 13 | 10 | 3 | 371 |

## Top 20 eingehende Verbindungen

| Datei | Gruppe | Gesamt | Ausgehend | Eingehend | Zeilen |
| --- | --- | ---: | ---: | ---: | ---: |
| `AboLife/Persistence/AppDatabase.swift` | Persistence | 38 | 2 | 36 | 46 |
| `AboLife/DesignSystem/AboLifeColors.swift` | DesignSystem | 28 | 0 | 28 | 111 |
| `AboLife/Persistence/DateIntervals.swift` | Persistence | 23 | 0 | 23 | 30 |
| `AboLife/DesignSystem/AboLifeTypography.swift` | DesignSystem | 22 | 0 | 22 | 15 |
| `AboLife/Telegram/TelegramBotModels.swift` | Telegram | 22 | 0 | 22 | 137 |
| `AboLife/DesignSystem/AboLifeCard.swift` | DesignSystem | 17 | 1 | 16 | 117 |
| `AboLife/Persistence/Seed/SeedData.swift` | Persistence | 17 | 1 | 16 | 13 |
| `AboLife.xcodeproj/xcshareddata/xcschemes/AboLife.xcscheme` | XcodeProject | 16 | 1 | 15 | 105 |
| `AboLife/DesignSystem/AboLifePremiumBackground.swift` | DesignSystem | 16 | 1 | 15 | 51 |
| `AboLife/Persistence/Repositories/SettingsRepository.swift` | Persistence | 18 | 3 | 15 | 73 |
| `AboLife/Features/Habits/HabitDefinitions.swift` | Features | 15 | 2 | 13 | 134 |
| `AboLife/Persistence/Models/NutritionEntryRecord.swift` | Persistence | 12 | 0 | 12 | 47 |
| `AboLife/Persistence/Models/WorkoutSessionRecord.swift` | Persistence | 11 | 0 | 11 | 47 |
| `AboLife/Persistence/Repositories/NutritionRepository.swift` | Persistence | 14 | 3 | 11 | 101 |
| `AboLife/Persistence/Models/FinanceEntryRecord.swift` | Persistence | 10 | 0 | 10 | 51 |
| `AboLife/Persistence/Repositories/HabitRepository.swift` | Persistence | 14 | 4 | 10 | 285 |
| `AboLife/Persistence/Repositories/WorkoutRepository.swift` | Persistence | 13 | 3 | 10 | 94 |
| `AboLife/Charts/CoreRingView.swift` | Charts | 11 | 2 | 9 | 64 |
| `AboLife/DesignSystem/ProgressViews.swift` | DesignSystem | 11 | 2 | 9 | 114 |
| `AboLife/Persistence/Repositories/FinanceRepository.swift` | Persistence | 12 | 3 | 9 | 95 |

## Isolierte Dateien

- AboLife.xcodeproj/project.xcworkspace/contents.xcworkspacedata
- AboLife.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
- AboLife.xcodeproj/project.xcworkspace/xcuserdata/arbergjihollaj.xcuserdatad/UserInterfaceState.xcuserstate
- plan/AboLife_Projektgrundlage_Professionelle_PDF.pdf
- scripts/generate_architecture_audit.js

## Risiken

- **Doppelte Tageslogik möglich** (warning): 10 Dateien berechnen oder aggregieren wahrscheinlich Tages-/Statuslogik. Eine read-only Snapshot-Schicht wie TodaySnapshotService oder DailyOverviewService sollte geprüft werden.
  Dateien: `AboLife/Features/Dashboard/DashboardMockData.swift`, `AboLife/Features/Dashboard/DashboardStore.swift`, `AboLife/Features/Dashboard/DashboardView.swift`, `AboLife/Features/Dashboard/QuickAddPanels.swift`, `AboLife/Features/Review/WeeklyReviewStore.swift`, `AboLife/Features/Review/WeeklyReviewTrends.swift`, `AboLife/Persistence/BackupService.swift`, `AboLife/Persistence/DateIntervals.swift`, `AboLife/Telegram/DailySummaryService.swift`, `AboLife/Telegram/HtmlSnapshotExportService.swift`
- **Potentielles God-File** (warning): DashboardStore.swift kombiniert 589 Zeilen mit 25 Verbindungen. Verantwortlichkeiten prüfen.
  Datei: `AboLife/Features/Dashboard/DashboardStore.swift`
- **Potentielles God-File** (warning): NutritionView.swift kombiniert 667 Zeilen mit 14 Verbindungen. Verantwortlichkeiten prüfen.
  Datei: `AboLife/Features/Nutrition/NutritionView.swift`
- **Potentielles God-File** (warning): TrainingView.swift kombiniert 758 Zeilen mit 14 Verbindungen. Verantwortlichkeiten prüfen.
  Datei: `AboLife/Features/Training/TrainingView.swift`
- **Potentielles God-File** (warning): BackupService.swift kombiniert 863 Zeilen mit 18 Verbindungen. Verantwortlichkeiten prüfen.
  Datei: `AboLife/Persistence/BackupService.swift`
- **Potentielles God-File** (warning): HtmlSnapshotExportService.swift kombiniert 260 Zeilen mit 24 Verbindungen. Verantwortlichkeiten prüfen.
  Datei: `AboLife/Telegram/HtmlSnapshotExportService.swift`
- **Potentielles God-File** (warning): TelegramPollingController.swift kombiniert 460 Zeilen mit 15 Verbindungen. Verantwortlichkeiten prüfen.
  Datei: `AboLife/Telegram/TelegramPollingController.swift`
- **Service verbindet viele Bereiche** (warning): ExternalInputService.swift ist ein Service mit 20 Verbindungen. Fachliche Verantwortlichkeiten abgrenzen prüfen.
  Datei: `AboLife/ExternalInput/ExternalInputService.swift`
- **Service verbindet viele Bereiche** (warning): BackupService.swift ist ein Service mit 18 Verbindungen. Fachliche Verantwortlichkeiten abgrenzen prüfen.
  Datei: `AboLife/Persistence/BackupService.swift`
- **Service verbindet viele Bereiche** (warning): DailySummaryService.swift ist ein Service mit 17 Verbindungen. Fachliche Verantwortlichkeiten abgrenzen prüfen.
  Datei: `AboLife/Telegram/DailySummaryService.swift`
- **Service verbindet viele Bereiche** (warning): HtmlSnapshotExportService.swift ist ein Service mit 24 Verbindungen. Fachliche Verantwortlichkeiten abgrenzen prüfen.
  Datei: `AboLife/Telegram/HtmlSnapshotExportService.swift`
- **Service verbindet viele Bereiche** (warning): ReminderService.swift ist ein Service mit 15 Verbindungen. Fachliche Verantwortlichkeiten abgrenzen prüfen.
  Datei: `AboLife/Telegram/ReminderService.swift`
- **UI-Datei mit vielen Abhängigkeiten** (warning): DashboardView.swift ist eine View mit 16 direkten Verbindungen. UI-Logik und Datenzugriff trennen prüfen.
  Datei: `AboLife/Features/Dashboard/DashboardView.swift`
- **UI-Datei mit vielen Abhängigkeiten** (warning): NutritionView.swift ist eine View mit 14 direkten Verbindungen. UI-Logik und Datenzugriff trennen prüfen.
  Datei: `AboLife/Features/Nutrition/NutritionView.swift`
- **UI-Datei mit vielen Abhängigkeiten** (warning): TrainingView.swift ist eine View mit 14 direkten Verbindungen. UI-Logik und Datenzugriff trennen prüfen.
  Datei: `AboLife/Features/Training/TrainingView.swift`
- **Zentrale Datei beobachten** (warning): AppRouter.swift hat 19 Verbindungen (14 ausgehend, 5 eingehend).
  Datei: `AboLife/App/AppRouter.swift`
- **Zentrale Datei beobachten** (warning): AboLifeColors.swift hat 28 Verbindungen (0 ausgehend, 28 eingehend).
  Datei: `AboLife/DesignSystem/AboLifeColors.swift`
- **Zentrale Datei beobachten** (warning): AboLifeTypography.swift hat 22 Verbindungen (0 ausgehend, 22 eingehend).
  Datei: `AboLife/DesignSystem/AboLifeTypography.swift`
- **Zentrale Datei beobachten** (warning): ExternalInputService.swift hat 20 Verbindungen (14 ausgehend, 6 eingehend).
  Datei: `AboLife/ExternalInput/ExternalInputService.swift`
- **Zentrale Datei beobachten** (warning): DashboardStore.swift hat 25 Verbindungen (17 ausgehend, 8 eingehend).
  Datei: `AboLife/Features/Dashboard/DashboardStore.swift`
- **Zentrale Datei beobachten** (warning): AppDatabase.swift hat 38 Verbindungen (2 ausgehend, 36 eingehend).
  Datei: `AboLife/Persistence/AppDatabase.swift`
- **Zentrale Datei beobachten** (warning): BackupService.swift hat 18 Verbindungen (12 ausgehend, 6 eingehend).
  Datei: `AboLife/Persistence/BackupService.swift`
- **Zentrale Datei beobachten** (warning): DateIntervals.swift hat 23 Verbindungen (0 ausgehend, 23 eingehend).
  Datei: `AboLife/Persistence/DateIntervals.swift`
- **Zentrale Datei beobachten** (warning): DailySummaryService.swift hat 17 Verbindungen (12 ausgehend, 5 eingehend).
  Datei: `AboLife/Telegram/DailySummaryService.swift`
- **Zentrale Datei beobachten** (warning): HtmlSnapshotExportService.swift hat 24 Verbindungen (19 ausgehend, 5 eingehend).
  Datei: `AboLife/Telegram/HtmlSnapshotExportService.swift`
- **Zentrale Datei beobachten** (warning): TelegramBotModels.swift hat 22 Verbindungen (0 ausgehend, 22 eingehend).
  Datei: `AboLife/Telegram/TelegramBotModels.swift`
- **Zentrale Datei beobachten** (warning): TelegramPollingController.swift hat 15 Verbindungen (10 ausgehend, 5 eingehend).
  Datei: `AboLife/Telegram/TelegramPollingController.swift`
- **Hohe eingehende Kopplung** (info): HabitDefinitions.swift wird von vielen Dateien referenziert (13 eingehend). API-Stabilität beachten.
  Datei: `AboLife/Features/Habits/HabitDefinitions.swift`
- **Hohe eingehende Kopplung** (info): TelegramBotModels.swift wird von vielen Dateien referenziert (22 eingehend). API-Stabilität beachten.
  Datei: `AboLife/Telegram/TelegramBotModels.swift`
- **Service koppelt mehrere Bereiche** (info): ExternalInputService.swift verbindet 7 Bereiche: ExternalInput, Features, Persistence, ProjectFiles, Telegram, Tests, XcodeProject.
  Datei: `AboLife/ExternalInput/ExternalInputService.swift`
- **Service koppelt mehrere Bereiche** (info): BodyProgressService.swift verbindet 3 Bereiche: Features, Tests, XcodeProject.
  Datei: `AboLife/Features/Training/BodyProgressService.swift`
- **Service koppelt mehrere Bereiche** (info): TrainingProgressionService.swift verbindet 3 Bereiche: Features, Tests, XcodeProject.
  Datei: `AboLife/Features/Training/TrainingProgressionService.swift`
- **Service koppelt mehrere Bereiche** (info): BackupService.swift verbindet 5 Bereiche: Docs, Features, Persistence, Tests, XcodeProject.
  Datei: `AboLife/Persistence/BackupService.swift`
- **Service koppelt mehrere Bereiche** (info): DailySummaryService.swift verbindet 5 Bereiche: Features, Persistence, Telegram, Tests, XcodeProject.
  Datei: `AboLife/Telegram/DailySummaryService.swift`
- **Service koppelt mehrere Bereiche** (info): HtmlSnapshotExportService.swift verbindet 6 Bereiche: Features, Persistence, ProjectFiles, Telegram, Tests, XcodeProject.
  Datei: `AboLife/Telegram/HtmlSnapshotExportService.swift`
- **Service koppelt mehrere Bereiche** (info): ReminderService.swift verbindet 5 Bereiche: ExternalInput, Persistence, Telegram, Tests, XcodeProject.
  Datei: `AboLife/Telegram/ReminderService.swift`
- **Service koppelt mehrere Bereiche** (info): TelegramBotService.swift verbindet 4 Bereiche: ExternalInput, Telegram, Tests, XcodeProject.
  Datei: `AboLife/Telegram/TelegramBotService.swift`

## Empfehlung: zentrale Tageszustands-Schicht prüfen

Der Graph legt nahe, dass Dashboard, Telegram-Zusammenfassung, HTML-Export, Backup/Export, WeeklyReview und DateIntervals an mehreren Stellen Tages-, Wochen- und Statuswerte zusammensetzen. Das ist aktuell nicht automatisch falsch, kann aber mittelfristig zu abweichenden Berechnungen für Kalorien, Protein, Budget, Habits, Training und Gewicht führen.

Empfohlen ist eine read-only Snapshot-Schicht, zum Beispiel `TodaySnapshotService` oder `DailyOverviewService`. Diese Schicht sollte keine neue Persistenz einführen, sondern vorhandene Repositories bündeln und ein konsistentes Tagesmodell liefern: Datum, Kalorien gegessen, Kalorienziel, Kalorien übrig, Protein gegessen, Proteinziel, Budget heute, Ausgaben heute, Budget übrig, Training geplant/erledigt, Habits erledigt/offen, Gewicht, Erinnerungen und kurze Tagesbewertung.

Sinnvoller Einstieg: zuerst ein kleines read-only DTO plus Tests für die bestehenden Berechnungen ergänzen, danach Dashboard, Telegram Daily Summary und HTML Snapshot schrittweise darauf umstellen.

## Konkrete nächste Refactor-Schritte

- `DailyOverviewService` oder `TodaySnapshotService` als read-only Aggregator skizzieren, ohne UI und ohne Telegram-Abhängigkeit.
- Bestehende Berechnungen in `DashboardStore`, `DailySummaryService`, `HtmlSnapshotExportService` und `WeeklyReviewStore` vergleichen und Testfälle für gleiche Tagesdaten ergänzen.
- `DateIntervals` als zentrale Kalender-/Intervall-Hilfe behalten, aber fachliche Tagesbewertung nicht dort hineinziehen.
- Services mit vielen Bereichsverbindungen darauf prüfen, ob sie Infrastruktur oder Fachlogik mischen.
- Views mit hoher Kopplung schrittweise über kleinere Store-APIs oder Snapshot-Modelle entlasten.

## Bewusst nicht automatisch riskant

- `AppDatabase.swift` darf viele Verbindungen haben, weil es als Infrastruktur-Wurzel und Environment-Brücke fungiert. Risiko entsteht erst, wenn dort fachliche Tageslogik landet.
- `DesignSystem`- und `Charts`-Dateien können viele eingehende Verbindungen haben, weil sie bewusst wiederverwendbare UI-Bausteine sind.
- Projektdateien, Dokumentation und Tests sind im interaktiven Graph standardmäßig ausblendbar, weil sie Architekturmetriken verzerren können.

## Artefakte

- Interaktiver HTML-Graph: `docs/AboLife_File_Node_Graph_Interactive.html`
- DOT-Quelle: `docs/AboLife_File_Node_Graph.dot`
- SVG-Export: `docs/AboLife_File_Node_Graph.svg`
