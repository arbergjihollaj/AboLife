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

Stand Phase 4A:

- Die Ernährung-Detailseite ersetzt den Placeholder und lädt gespeicherte `NutritionEntry`-Daten aus SQLite.
- Die Seite zeigt eine einfache Tagesübersicht für Kalorien und Protein, heutige Mahlzeiten und Löschen einzelner Einträge.
- Bewusst nicht enthalten: Food-Datenbank, Barcode, API-Integrationen, KI, Rezepte, Templates/Favorites oder Wochenanalyse.

Stand Phase 4B:

- Die Training-Detailseite ersetzt den Placeholder und lädt gespeicherte `WorkoutSession`-Daten aus SQLite.
- Die Seite zeigt eine einfache Wochenübersicht mit Wochenziel, abgeschlossenen Workouts, Dauer, Wochen-Tage-Leiste und löschbarer Workout-Liste.
- Bewusst nicht enthalten: Trainingspläne, Übungsdatenbank, Sätze/Wiederholungen/Gewichte, Progression, Kalenderintegration, HealthKit oder KI.

Stand Phase 4C:

- Die Finanzen-Detailseite ersetzt den Placeholder und lädt gespeicherte `FinanceEntry`-Daten aus SQLite.
- Die Seite zeigt eine einfache Monatsübersicht mit Budget, Ausgaben, Restbudget, verfügbarem Tagesbudget und löschbarer Ausgabenliste.
- Bewusst nicht enthalten: Bankverbindung, Kontosynchronisierung, automatische Kategorienlogik, wiederkehrende Fixkosten, Sparplan-/Investmentlogik, Abofolio-Integration oder KI.

Stand Phase 4D:

- Die Gewohnheiten-Detailseite ersetzt den Placeholder und lädt heutige `HabitEntry`-Daten aus SQLite.
- Die Seite zeigt eine einfache Tagesübersicht für feste Habits, Fortschritt und toggelbare Habit-Zeilen.
- Bewusst nicht enthalten: Habit-Erstellung, Streaks, Reminder, Kalenderansicht, Gamification oder KI.

Stand Phase 4E:

- Die Wochenreview-Detailseite ersetzt den Placeholder und fasst echte Wochenwerte aus Nutrition, Training, Finance und Habits zusammen.
- Review-Notizen für Wins, Schwierigkeiten und Fokus nächste Woche werden lokal in `weekly_reviews` gespeichert.
- Bewusst nicht enthalten: KI-Auswertung, Coaching-Logik, komplexe Statistiken, Monatsberichte, PDF-Reports oder externe Integrationen.

Stand Phase 5 Settings:

- Die Einstellungen-Seite ersetzt den Placeholder und speichert zentrale Zielwerte lokal in `app_settings`.
- Kalorienziel, Proteinziel, Wochen-Trainingsziel, Monatsbudget, EUR-Währung und Wochenstart werden geladen, gespeichert und auf Defaults zurückgesetzt.
- Dashboard, Ernährung, Training, Finanzen und Wochenreview nutzen die zentralen Settings beim Laden.
- Bewusst nicht enthalten: Account, Cloud/iCloud Sync, Export/Backup, Telegram, HealthKit, KI oder externe Integrationen.

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

Stand Phase 6A:

- Die Einstellungen-Seite enthält eine ruhige lokale Sektion „Backup & Export“.
- SQLite-Backups werden lokal im Application-Support-Backup-Ordner erstellt.
- JSON-Exporte sichern die wichtigsten bestehenden Tabellen als lesbare Datei.
- Bewusst nicht enthalten: Restore/Import, Cloud/iCloud Sync, Accounts, Hintergrunddienst oder externe Integrationen.

Stand Phase 7A:

- Die Training-Seite enthält einen einfachen Home-Trainingsplan für Körpergewicht und einfache Klimmzugstange.
- Der Plan nutzt feste Trainingstage: Montag Pull + Core, Mittwoch Push + Legs, Freitag Full Body.
- Jede Einheit bietet Minimum, Normal und Stark als alltagstaugliche Varianten.
- Ein abgeschlossener Plan speichert eine normale `WorkoutSession` und zählt dadurch in Training, Dashboard und Wochenreview mit.
- Bewusst nicht enthalten: Übungsdatenbank, eigene Trainingstage, Satz-/Gewichts-Historie, Progression, Kalender, Reminder, HealthKit, KI oder externe Integrationen.

Stand Phase 7B:

- Die Wochenreview-Seite enthält eine ruhige Sektion „Trends dieser Woche“ mit 7-Tage-Trends für Kalorien, Protein, Ausgaben, Training und Gewohnheiten.
- Alle Trends zeigen Montag bis Sonntag; Tage ohne Daten werden als 0 dargestellt.
- Die Diagramme nutzen bestehende SwiftUI-/Glass-Komponenten und keine externe Chart-Library.
- Bewusst nicht enthalten: Langzeit-Analytics, Monats-/Jahresdiagramme, Heatmaps, Prognosen, KI-Auswertung, neue Exportformate oder externe Integrationen.

Stand Phase 7C:

- Die Gewohnheiten-Seite wurde zu einer messbaren Habit-Seite mit großem Tagesring, Habit-Grid und kompakter Wochenübersicht umgebaut.
- Die fünf festen Habits haben Tagesziele: Wasser 3,0 Liter, Trainieren 1 Training, Ernährung 3 Mahlzeiten, Lernen 60 Minuten und Schlafroutine 1.
- `habit_entries` speichert zusätzlich `value`, `target_value` und `unit`; alte Boolean-Daten bleiben kompatibel.
- Bewusst nicht enthalten: Custom Habits, Habit-Bibliothek, Reminder, Notifications, Streak-Analytics, Kalenderansicht, Heatmaps, HealthKit, KI oder externe Integrationen.

Stand Phase 7D:

- Die Floating Bottom Quick Bar bleibt bei Mahlzeit, Training, Plus, Ausgabe und Gewohnheit.
- Die Dock-Buttons routen direkt auf Meal-, Training-, Expense- und messbares Habit-Quick-Panel; Plus öffnet ein kompaktes allgemeines Quick Action Menü.
- Das Plus-Menü enthält die Gruppen „Eintragen“ und „Schnelle Gewohnheiten“ mit direkten Actions für Wasser +0,25 L, Ernährung +1 Mahlzeit, Lernen +15 Min. und Schlafroutine erledigt.
- Die Quick Panels speichern über bestehende Repositories in SQLite und nutzen für Habits die Phase-7C-Felder `value`, `target_value` und `unit`.
- Bewusst nicht enthalten: neue Bottom-Bar-Buttons, Telegram, iPhone, HealthKit, KI, Reminder, Custom Habits, Übungsdatenbank, Satz-/Gewichts-Historie, neue Exportformate oder externe Dependencies.

Stand Phase 7E:

- Die aktive Habit-Liste ersetzt Bewegung durch Trainieren: Wasser, Trainieren, Ernährung getrackt, Lernen und Schlafroutine.
- Trainieren wird nicht separat in `habit_entries` gepflegt, sondern aus abgeschlossenen `WorkoutSession`-Datensätzen des Tages abgeleitet.
- Dashboard und Wochenreview nutzen den Durchschnitt der messbaren Habit-Fortschritte; Trainieren zählt je Tag mit 0 % oder 100 %.
- Habit-Quick-Panel und Plus-Menü enthalten keine Bewegung-Aktion mehr; Training erfüllt Trainieren über Training-Panel oder Training-Seite.
- Bewusst nicht enthalten: Custom Habits, Habit-Einstellungen, Reminder, Notifications, HealthKit, Apple Watch, iPhone, Telegram, KI, Streak-Analytics, Heatmap, Cloud, Netzwerkaufrufe oder externe Dependencies.

Stand Phase 7F:

- Der MVP wurde stabilisiert: Berechnungen, Quick Actions, Empty/Error States, Settings-Zielwerte und Export/Backup wurden konsistenter gemacht.
- Habit-Summaries ignorieren abgeleitete Habits in `habit_entries`, deduplizieren Mehrfachzeilen und nutzen Trainieren weiter aus `WorkoutSession`-Daten.
- Dashboard und Finanzen verwenden dieselbe Tagesbudget-Logik; Dashboard zeigt keine technischen Lade- oder Mock-Aktivitäten mehr.
- QuickAdd-Zahlen werden gegen nicht-finite Werte abgesichert, das QuickAdd-Sheet scrollt bei kleinen Höhen, und die Routing-Tabelle ist konsistent.
- Backup & Export umfasst SQLite-Backup, JSON-Export und CSV-Dateien für Numbers aus den bestehenden Tabellen.
- Bewusst nicht enthalten: neue Hauptnavigation, neue Analytics-Seiten, Custom Habits, Notifications, Reminder, Cloud, Accounts, Telegram, iPhone, Apple Watch, HealthKit, KI, Netzwerkaufrufe oder neue externe Dependencies.

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
