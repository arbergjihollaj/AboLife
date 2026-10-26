# DATA_MODEL.md

# AboLife Data Model

## 1. Grundprinzip

Entries sind die Primärwahrheit. Summen, Trends und Dashboard-Werte werden daraus berechnet.

Nicht sofort speichern:

- Tagessummen
- Wochensummen
- Score-Werte ohne klare Berechnungsregel

## 2. DailyLog

Zweck: Tagesanker für Notizen und spätere Bewertung.

| Feld | Typ | V1 | Beschreibung |
|---|---|---:|---|
| id | UUID/String | ja | eindeutige ID |
| date | Date | ja | Kalendertag |
| note | String? | ja | Tagesnotiz |
| dayRating | Int? | optional | 1-5 Bewertung |
| createdAt | Date | ja | erstellt |
| updatedAt | Date | ja | geändert |

## 3. NutritionEntry

Zweck: manuelles Erfassen von Mahlzeiten, Kalorien und Protein.

| Feld | Typ | V1 | Beschreibung |
|---|---|---:|---|
| id | UUID/String | ja | eindeutige ID |
| occurredAt | Date | ja | Zeitpunkt |
| title | String | ja | z. B. Döner, Frühstück |
| caloriesKcal | Int | ja | Kalorien |
| proteinG | Double | ja | Protein |
| carbsG | Double? | später | Kohlenhydrate |
| fatG | Double? | später | Fett |
| quantityText | String? | ja | z. B. 1 Portion |
| sourceType | String | ja | manual/template/api |
| favoriteTemplateId | String? | später | Favorit |
| externalFoodId | String? | später | API-Lebensmittel |
| note | String? | optional | Notiz |
| createdAt | Date | ja | erstellt |

## 4. WorkoutSession

Zweck: Trainingseinheit erfassen.

| Feld | Typ | V1 | Beschreibung |
|---|---|---:|---|
| id | UUID/String | ja | eindeutige ID |
| occurredAt | Date | ja | Zeitpunkt |
| workoutType | String | ja | push/pull/legs/cardio/custom |
| planName | String? | optional | Name des Plans |
| status | String | ja | planned/done/skipped |
| durationMin | Int? | ja | Dauer |
| rpe | Int? | später | Anstrengung 1-10 |
| note | String? | optional | Notiz |
| createdAt | Date | ja | erstellt |

## 5. ExerciseEntry

Zweck: Übungen innerhalb einer Trainingseinheit.

| Feld | Typ | V1 | Beschreibung |
|---|---|---:|---|
| id | UUID/String | ja | eindeutige ID |
| workoutSessionId | UUID/String | ja | Referenz zu WorkoutSession |
| exerciseName | String | ja | Übungsname |
| orderIndex | Int | ja | Reihenfolge |
| sets | Int? | optional | Sätze |
| reps | Int? | optional | Wiederholungen |
| weightKg | Double? | optional | Gewicht |
| durationMin | Int? | optional | Dauer |
| distanceKm | Double? | später | Distanz |
| note | String? | optional | Notiz |

## 6. FinanceEntry

Zweck: Ausgaben und einfache Finanzübersicht.

| Feld | Typ | V1 | Beschreibung |
|---|---|---:|---|
| id | UUID/String | ja | eindeutige ID |
| occurredAt | Date | ja | Zeitpunkt |
| amount | Decimal/Double | ja | Betrag |
| currency | String | ja | EUR |
| direction | String | ja | expense/income |
| category | String | ja | Essen, Uni, Freizeit etc. |
| label | String | ja | Beschreibung |
| paymentMethod | String? | später | Karte/Bar/etc. |
| isRecurring | Bool | später | wiederkehrend |
| note | String? | optional | Notiz |
| createdAt | Date | ja | erstellt |

## 7. HabitDefinition

Zweck: Definition einer Gewohnheit.

| Feld | Typ | V1 | Beschreibung |
|---|---|---:|---|
| id | UUID/String | ja | eindeutige ID |
| key | String | ja | z. B. water, training, learning |
| title | String | ja | Anzeigename |
| targetType | String | ja | boolean/count |
| sortOrder | Int | ja | Reihenfolge |
| isActive | Bool | ja | aktiv |

## 8. HabitEntry

Zweck: Tagesstatus einer Gewohnheit.

| Feld | Typ | V1 | Beschreibung |
|---|---|---:|---|
| id | UUID/String | ja | eindeutige ID |
| habitKey | String | ja | Referenz zu HabitDefinition |
| date | Date | ja | Tag |
| valueBool | Bool? | ja | erledigt/nicht erledigt |
| valueCount | Int? | optional | Anzahl |
| note | String? | optional | Notiz |
| createdAt | Date | ja | erstellt |

## 9. BodyMetricEntry

Zweck: Gewicht und spätere Körperwerte.

| Feld | Typ | V1 | Beschreibung |
|---|---|---:|---|
| id | UUID/String | ja | eindeutige ID |
| occurredAt | Date | ja | Zeitpunkt |
| weightKg | Double? | ja | Gewicht |
| sleepHours | Double? | später | Schlafdauer |
| bodyFatPct | Double? | später | Körperfett |
| waistCm | Double? | später | Bauchumfang |
| dayRating | Int? | optional | Tagesgefühl 1-5 |
| note | String? | optional | Notiz |

## 10. AppSettings

Zweck: zentrale Zielwerte und App-Konfiguration.

| Feld | Typ | V1 | Beschreibung |
|---|---|---:|---|
| id | String | ja | single/settings |
| kcalTarget | Int | ja | Tagesziel Kalorien |
| proteinTargetG | Double | ja | Tagesziel Protein |
| weeklyWorkoutTarget | Int | ja | Workouts pro Woche |
| monthlyBudget | Decimal/Double | ja | Monatsbudget |
| defaultCurrency | String | ja | EUR |
| weekStartsOn | Int | ja | Montag/Sonntag |
| dashboardCardOrder | String/JSON | später | Reihenfolge |
| quickAddDefaults | String/JSON | optional | Defaults |

## 11. WeeklyReview

Zweck: strukturierter Wochenrückblick.

| Feld | Typ | V1 | Beschreibung |
|---|---|---:|---|
| id | UUID/String | ja | eindeutige ID |
| weekStartDate | Date | ja | Start der Woche |
| winsText | String | ja | Was lief gut? |
| missesText | String | ja | Was lief schlecht? |
| nextWeekFocusText | String | ja | Fokus nächste Woche |
| overallScore | Int? | optional | 1-5 |
| trainingScore | Int? | optional | 1-5 |
| nutritionScore | Int? | optional | 1-5 |
| financeScore | Int? | optional | 1-5 |
| completedAt | Date | ja | abgeschlossen |

## 12. Dashboard Read Models

Dashboard-Werte werden nicht als primäre Tabellen betrachtet. Sie entstehen durch Queries:

- caloriesToday
- proteinToday
- remainingCalories
- trainingStatusToday
- expensesThisMonth
- remainingMonthlyBudget
- habitCompletionToday
- weeklyCoreScore
- sevenDayTrend

## 13. Phase 3A Persistenzschema

Phase 3A persistiert als Fundament nur die ersten Core-Tabellen:

- `nutrition_entries`
- `workout_sessions`
- `finance_entries`
- `habit_entries`
- `body_metric_entries`
- `app_settings`

Noch nicht persistiert werden Dashboard-Read-Models, Weekly Reviews, komplexe Aggregationen oder Beziehungen zwischen Einträgen. Datensätze verwenden UUID-Strings als IDs; Zeitpunkte werden konsistent ueber GRDB/SQLite-Date-Felder gespeichert, Habit-Tage als `YYYY-MM-DD`-Text.

## 14. Phase 3B Persistierte Dashboard-Summaries

Phase 3B speichert keine Dashboard-Read-Models. Das Dashboard berechnet erste Werte direkt aus Entries:

- heutige Kalorien und Protein aus `nutrition_entries`
- abgeschlossene Workouts der aktuellen Woche aus `workout_sessions`
- Monatsausgaben aus `finance_entries`
- heutige Habit-Erledigungen aus `habit_entries`
- optional letztes Gewicht aus `body_metric_entries`

Habit-Definitionen bleiben vorerst feste App-Habits im Dashboard-State; es gibt noch keine `habit_definitions`-Tabelle.

## 15. Phase 4A Ernährung-Detailseite

Phase 4A nutzt das bestehende `nutrition_entries`-Schema ohne Migration. Die Ernährung-Seite liest Tagesentries aus SQLite, berechnet Kalorien und Protein aus den geladenen Entries und kann einzelne `NutritionEntry`-Datensätze löschen.

Nicht modelliert werden in dieser Phase Food-Datenbank, Barcode-Daten, externe Food-IDs, KI-Auswertung, Rezepte, Templates/Favorites oder Wochenanalyse.

## 16. Phase 4B Training-Detailseite

Phase 4B nutzt das bestehende `workout_sessions`-Schema ohne Migration. Die Training-Seite liest Sessions der aktuellen Woche aus SQLite, berechnet abgeschlossene Workouts und Gesamtdauer aus den geladenen `done`-Sessions und kann einzelne `WorkoutSession`-Datensätze löschen.

Nicht modelliert werden in dieser Phase Trainingspläne, ExerciseEntry-UI, Übungsdatenbank, Sätze/Wiederholungen/Gewichte, Progression, Kalenderintegration, HealthKit, KI oder Monatsanalyse.

## 17. Phase 4C Finanzen-Detailseite

Phase 4C nutzt das bestehende `finance_entries`-Schema ohne Migration. Die Finanzen-Seite liest Ausgaben des aktuellen Monats aus SQLite, berechnet Monatsausgaben und Restbudget aus den geladenen Entries und den AppSettings und kann einzelne `FinanceEntry`-Datensätze löschen.

Nicht modelliert werden in dieser Phase Bankverbindung, Kontosynchronisierung, automatische Kategorienlogik, wiederkehrende Fixkosten, Sparplan-/Investmentlogik, Abofolio-Integration, Steuerlogik, KI oder Jahresberichte.

## 18. Phase 4D Gewohnheiten-Detailseite

Phase 4D nutzt das bestehende `habit_entries`-Schema ohne Migration. Die Gewohnheiten-Seite liest Entries des ausgewählten Tages aus SQLite und zeigt sie gegen feste App-Habits: `water`, `training`, `nutrition`, `learning` und `sleep`.

Das Umschalten einer Gewohnheit nutzt ein idempotentes Upsert: vorhandene Einträge werden aktualisiert, fehlende Einträge werden angelegt. Die Tageszusammenfassung berechnet erledigte feste Habits und Gesamtzahl aus diesen Definitionen.

Nicht modelliert werden in dieser Phase Habit-Erstellung, `habit_definitions` als Tabelle, Streaks, Reminder, Kalenderansicht, Gamification, KI oder Wochen-/Monatsanalyse.

## 19. Phase 4E Wochenreview-Detailseite

Phase 4E ergänzt eine minimale Tabelle `weekly_reviews` für persönliche Review-Notizen. Ein Datensatz ist über `week_start_date` eindeutig einer Woche zugeordnet und speichert `wins_text`, `challenges_text`, `next_week_focus_text`, optional `rating`, sowie `created_at` und `updated_at`.

Die Wochenreview-Seite persistiert keine berechneten Summen. Ernährung, Training, Finanzen und Gewohnheiten werden aus bestehenden Entry-Tabellen über einfache Wochen-Summaries gelesen.

Nicht modelliert werden in dieser Phase KI-Auswertung, Coaching-Logik, komplexe Statistikmodelle, Monatsberichte, PDF-Reports, Kalenderansicht oder externe Integrationen.

## 20. Phase 5 Einstellungen und Zielwerte

Phase 5 nutzt `app_settings` als Single-Row-Tabelle für zentrale Zielwerte. Ergänzt wird `weekly_workout_target` per Migration, damit Training, Dashboard und Wochenreview dasselbe Wochenziel verwenden.

Persistiert werden Kalorienziel, Proteinziel, Wochen-Trainingsziel, Monatsbudget, Währung `EUR` und Wochenstart Montag. Defaults werden zentral über `SeedData.defaultSettings` bereitgestellt und über `SettingsRepository` geladen, gespeichert oder zurückgesetzt.

Nicht modelliert werden in dieser Phase Accounts, Cloud/iCloud Sync, Export/Backup, Ziel-Historie, Profile, Reminder, HealthKit, KI oder externe Integrationen.

## 21. Phase 6A Backup und Export

Phase 6A ändert das Datenbankschema nicht. Backups und Exporte lesen die bestehenden Tabellen:

- `nutrition_entries`
- `workout_sessions`
- `finance_entries`
- `habit_entries`
- `body_metric_entries`
- `weekly_reviews`
- `app_settings`

SQLite-Backups werden als konsistente Datenbankkopie erstellt. JSON-Exporte enthalten `exportVersion`, `createdAt`, `appName` und Arrays der wichtigsten App-Daten. CSV-Exporte schreiben je bestehender Tabelle eine Numbers-freundliche `.csv`-Datei in einen lokalen Exportordner. Der Export ist eine lokale Sicherungs-/Lesedatei und kein Importvertrag.

Nicht modelliert werden in dieser Phase Restore/Import, Datenbank-Ersetzung, Cloud/iCloud Sync, Accounts, Verschluesselung, Scheduler oder externe Integrationen.

## 22. Phase 7A Home-Trainingsplan

Phase 7A ändert das Datenbankschema nicht. Der Home-Trainingsplan besteht aus kleinen reinen Swift-Modellen (`HomeWorkoutPlan`, `HomeWorkoutDay`, `HomeWorkoutIntensity`, `HomeWorkoutExercise`) und einem statischen Provider.

Ein abgeschlossener Plan wird als normale `WorkoutSession` in `workout_sessions` gespeichert:

- `workout_type`: z. B. `Home Plan: Pull + Core`
- `duration_min`: aus der Intensität abgeleitet, Minimum 15, Normal 30, Stark 45
- `status`: `done`
- `note`: Intensität, erledigte Übungen und Übungsliste als Text

Nicht modelliert werden in dieser Phase persistierte Plan-Records, Exercise-Records, Satz-/Gewichts-Historie, automatische Progression, eigene Trainingstage, Kalenderintegration, Reminder, HealthKit, KI oder externe Integrationen.

## 23. Phase 7C Messbare Gewohnheiten

Phase 7C erweitert `habit_entries` additiv um messbare Tageswerte:

- `value` als `DOUBLE?`
- `target_value` als `DOUBLE?`
- `unit` als `TEXT?`

`is_completed` bleibt als Kompatibilitätsfeld bestehen. Für messbare Habits wird es beim Speichern aus `value >= target_value` abgeleitet; alte Boolean-Daten bleiben lesbar. Die Migration setzt bekannte feste Habits auf Default-Ziele und transformiert bestehende Boolean-Werte: erledigt wird zum Zielwert, offen wird `0`.

Die fünf Habit-Definitionen bleiben feste Swift-Defaults: Wasser 3,0 Liter, Trainieren 1 Training, Ernährung getrackt 3 Mahlzeiten, Lernen 60 Minuten, Schlafroutine 1. Es gibt weiterhin keine `habit_definitions`-Tabelle und keine Custom Habits.

Nicht modelliert werden in dieser Phase Ziel-Historie, Custom Habits, Reminder, Streak-Analytics, Kalender-/Heatmap-Daten, HealthKit, KI oder externe Integrationen.

## 24. Phase 7D Quick Panels

Phase 7D ändert das Datenbankschema nicht. Die überarbeiteten Quick Panels schreiben weiter in bestehende Tabellen:

- Mahlzeiten als `NutritionEntry`
- Trainings und Home-Workouts als normale `WorkoutSession`
- Ausgaben als `FinanceEntry`
- Habit Quick Actions als `HabitEntry` mit den Phase-7C-Feldern `value`, `target_value` und `unit`

Die messbaren Habit-Schritte aktualisieren vorhandene Tagesrecords per Repository-Upsert. Es gibt keine zweite Habit-Struktur, keine `habit_definitions`-Tabelle und keine neue Migration.

## 25. Phase 7E Trainieren als abgeleiteter Habit

Phase 7E ändert das Datenbankschema nicht. Der aktive Habit `training` wird nicht in `habit_entries` geschrieben, sondern aus `workout_sessions` abgeleitet:

- Wert `1`, wenn am ausgewählten Tag mindestens eine `WorkoutSession` mit `status = done` existiert
- Wert `0`, wenn keine abgeschlossene Session für diesen Tag existiert
- Zielwert `1`, Einheit leer

Dashboard, Habits-Seite und Wochenreview verwenden diese abgeleitete Quelle. Dadurch wird Trainieren automatisch erfüllt, wenn ein Home-Workout oder manuelles Training gespeichert wird, und automatisch wieder offen, wenn das letzte Workout des Tages gelöscht wird.

Bestehende alte `movement`-Einträge werden nicht gelöscht und nicht migriert. Sie bleiben nur als historische/Export-Daten in `habit_entries` erhalten und werden von den aktiven Habit-Summaries ignoriert.

## 26. Phase 7F MVP-Stabilisierung

Phase 7F ändert das Datenbankschema nicht. Stabilisiert wurden nur Berechnung und Ausgabe:

- Habit-Summaries zählen pro Tag eindeutige, nicht-abgeleitete Habit-Keys und ignorieren `training`-Rows in `habit_entries`.
- Trainieren bleibt aus `workout_sessions` abgeleitet; alte `movement`-Daten bleiben historisch erhalten.
- JSON- und CSV-Export enthalten `habit_entries` inklusive `value`, `target_value` und `unit`; abgeleitetes Trainieren ist über exportierte `workout_sessions` nachvollziehbar.
- Settings-Zielwerte bleiben die Quelle für Kalorien, Protein, Wochen-Workouts, Budget und Wochenstart.

## Version 0.2: lokaler Kalender und Lernplaner

Migration `v12_calendar_workspace` liegt ausschließlich im getrennten Datenordner `AboLife-Calendar-Preview`. Die Originaldaten unter `AboLife` erhalten diese Migration nicht. Beim ersten Start wird mit einer nur lesend geöffneten alten Datenbank eine konsistente SQLite-Kopie angelegt, bevor neue Migrationen auf der Kopie laufen. Gleiche Pfade und symbolische Verweise auf die Originaldatenbank werden abgewiesen.

`calendar_workspace` enthält einen Datensatz (`id = main`, `payload = BLOB`). Der JSON-Dokumentinhalt besteht aus primären Terminen, Themen, Wiederholungs- und Sitzungsverlauf, fixierten bzw. generierten Vorschlägen, Quellenkennungen und Planungspräferenzen. Schreibvorgänge ersetzen das Dokument atomar in einer GRDB-Transaktion. Für die persönliche lokale App gibt es einen schreibenden Kalender-Store; freie Zeitfenster werden berechnet und nicht gespeichert. Unlesbare Dokumente werden nicht durch einen leeren Stand überschrieben.

Termine haben eine stabile UUID, Kategorie, Start/Ende, Ort und Zeitzone; Wochenserien können Wochentage, ein Enddatum oder COUNT sowie einzelne ausgenommene Tage enthalten. Importierte Termine besitzen zusätzlich Quelle und UID sowie eine Markierung für lokale Änderungen. Eine importierte Löschung wird als deaktivierter Datensatz behalten. Verschobene Serienvorkommen werden vorerst ausdrücklich zurückgewiesen, anstatt falsch angewendet.

Lernthemen speichern Fach, Titel, geschätzte Dauer, nächste Fälligkeit, optionales Prüfungsdatum, Intervall, Schwierigkeitsfaktor und die letzten fünf tatsächlichen Dauern. Sitzungen speichern geplanten bzw. bestätigten Zeitraum, Status, Fixierung, Bewertung, tatsächliche Dauer und Bewertungszeitpunkt. Auslassen ist keine erfolgreiche Wiederholung. Bewertete Einheiten und Termine bleiben von Änderungen der Zeitplanung unterscheidbar.

SQLite-Sicherungen enthalten den gesamten Workspace. JSON-Exporte erhalten optional `calendarWorkspace`; ältere Exporte ohne dieses Feld bleiben lesbar. Beim mehrteiligen CSV-Backup liegt zusätzlich `calendar_workspace.json` mit der vollständigen Kalender- und Lernhistorie bei. Für den Kalender ist weiterhin kein automatischer Import in Version 0.1 vorgesehen.
