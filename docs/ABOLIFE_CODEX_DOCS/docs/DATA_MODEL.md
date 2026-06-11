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
