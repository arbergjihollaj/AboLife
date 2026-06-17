# UI_SPEC.md

# AboLife UI Specification

## 1. Designziel

AboLife soll grafisch hochwertig und ruhig wirken. Die App soll viele klare Visualisierungen enthalten, aber nicht überladen sein.

Designrichtung:

- Apple-like
- ruhig
- hochwertig
- clean
- persönlich
- grafisch reich
- nicht laut
- nicht hektisch
- nicht wie Broker-App
- nicht wie toxische Fitness-App

## 2. Hauptscreen

Der Hauptscreen ist das Dashboard.

Das Dashboard beantwortet:

- Wie läuft mein Tag?
- Was ist offen?
- Was ist mein nächster sinnvoller Schritt?

## 3. Sidebar

Sidebar-Struktur:

```text
Dashboard
Ernährung
Training
Finanzen
Gewohnheiten
Wochenreview
Körperwerte
Einstellungen
```

## 4. Dashboard-Zonen

```text
Dashboard
├── Hero-Zone
│   ├── Daily Core Ring
│   ├── kurzer Tagesstatus
│   └── Quick Add
├── Daily Progress
│   ├── Kalorienkarte
│   ├── Proteinkarte
│   ├── Training Heute
│   └── Habits Heute
├── Weekly Momentum
│   ├── 7-Tage-Leiste
│   └── Mini-Trends
├── Financial Calm
│   ├── Monatsbudget-Balken
│   └── Restbudget
└── Review / Hinweise
    └── nächster Weekly Review
```

## 5. Quick Add

Quick Add ist ein Kernfeature.

Aktionen:

- Mahlzeit
- Training
- Ausgabe
- Gewicht
- Habit
- Notiz

Regeln:

- Quick Add darf nicht zu einem großen Formular werden
- nur wichtigste Felder
- optional später Advanced Edit
- Standardwerte und letzte Werte verwenden
- per Toolbar erreichbar
- später per Tastenkürzel

## 6. Kartenregeln

Jede Dashboard-Karte muss diese Regeln erfüllen:

- eine Karte = eine Hauptaussage
- maximal eine Hauptzahl
- maximal eine primäre Grafik
- maximal eine Aktion
- keine Tabellen auf dem Dashboard
- keine langen Texte
- klare Empty States
- klare Partial States
- klare Full States

## 7. Visualisierungen in Version 1

Geplante Visuals:

| Visualisierung | Zweck |
|---|---|
| Daily-Core-Ring | Gesamtstatus des Tages |
| Kalorien-Progress | Tageskalorien sichtbar machen |
| Protein-Progress | Protein priorisieren |
| Trainingsstatus | Heute offen/erledigt |
| Finanz-Monatsbalken | Budgetruhe schaffen |
| 7-Tage-Leiste | Wochenmomentum sehen |
| Mini-Trends | kleine Entwicklung zeigen |

## 8. Dashboard-Skizze

```text
┌──────────────────────────────────────────────┐
│ Guten Abend, Arber                  Quick Add │
│                                              │
│ Daily Core                         72 %      │
│        großer ruhiger Ring                   │
└──────────────────────────────────────────────┘

┌──────────────────────┐ ┌──────────────────────┐
│ Kalorien             │ │ Protein              │
│ 1450 / 2200 kcal     │ │ 95 / 160 g           │
│ Progress + MiniTrend │ │ Progress + MiniTrend │
└──────────────────────┘ └──────────────────────┘

┌──────────────────────┐ ┌──────────────────────┐
│ Training             │ │ Finanzen             │
│ Push Day offen       │ │ 42 € Tagesbudget     │
│ 2 / 3 diese Woche    │ │ Monatsbalken         │
└──────────────────────┘ └──────────────────────┘

┌──────────────────────────────────────────────┐
│ Woche: Mo ● Di ● Mi ◐ Do ● Fr ○ Sa ○ So ○   │
└──────────────────────────────────────────────┘
```

## 9. Farben

Regeln:

- Systemfarben bevorzugen
- System Appearance respektieren
- keine eigene Dark/Light-Umschaltung in V1 nötig
- pro Domain eine dezente Akzentfamilie
- rot nur für echte Warnungen oder Fehler
- keine Neonfarben
- keine zu starke Sättigung

## 10. Typografie

- System Font verwenden
- klare Hierarchie
- große KPI-Zahlen
- kleine Meta-Informationen
- keine zu vielen Schriftgrößen

## 11. Empty States

Jede Kernkarte braucht Empty State:

- Ernährung: „Heute noch keine Mahlzeit erfasst“
- Training: „Noch kein Training für heute eingetragen“
- Finanzen: „Noch keine Ausgaben diesen Monat“
- Habits: „Noch keine Gewohnheiten abgehakt“
- Review: „Noch kein Wochenreview gespeichert“

## 12. Fehlerzustände

Fehler sollen ruhig und hilfreich sein:

- keine dramatischen Warnungen
- kurze Erklärung
- Retry-Möglichkeit
- Debug-Details nur optional

## 13. Detailseiten

Detailseiten dürfen mehr Daten enthalten als das Dashboard.

Dashboard zeigt Überblick.
Detailseiten zeigen Historie, Listen, Bearbeitung und tiefergehende Charts.

### Phase 4A Ernährung

- Die Ernährung-Seite ist eine einfache Tagesansicht mit Header, Kalorien-/Protein-Progresskarten und Mahlzeitenliste.
- Mahlzeiten werden aus lokalen `NutritionEntry`-Daten angezeigt und können gelöscht werden.
- Empty State: „Heute noch keine Mahlzeit erfasst.“ mit Hinweis auf Quick Add.
- Nicht Teil dieser Phase: Food-Datenbank, Barcode, KI, Rezepte, Templates/Favorites und Wochenanalyse.

### Phase 4B Training

- Die Training-Seite ist eine einfache Wochenansicht mit Header, zentraler Wochen-Fortschrittskarte, Mo-So-Leiste und Workout-Liste.
- Workouts werden aus lokalen `WorkoutSession`-Daten angezeigt und können gelöscht werden.
- Empty State: „Diese Woche noch kein Training abgeschlossen.“ mit Hinweis auf Quick Add.
- Nicht Teil dieser Phase: Trainingspläne, Übungsdatenbank, Sätze/Wiederholungen/Gewichte, Progression, Kalenderintegration, HealthKit, KI und Monatsanalyse.

### Phase 4C Finanzen

- Die Finanzen-Seite ist eine einfache Monatsansicht mit Header, zentraler Budget-Fortschrittskarte, kompakten Budgetwerten und Ausgabenliste.
- Ausgaben werden aus lokalen `FinanceEntry`-Daten angezeigt und können gelöscht werden.
- Empty State: „Diesen Monat noch keine Ausgaben erfasst.“ mit Hinweis auf Quick Add.
- Nicht Teil dieser Phase: Bankverbindung, Kontosynchronisierung, automatische Kategorienlogik, wiederkehrende Fixkosten, Sparplan-/Investmentlogik, Abofolio-Integration, Steuerlogik, KI und Jahresberichte.

### Phase 4D Gewohnheiten

- Die Gewohnheiten-Seite ist eine einfache Tagesansicht mit Header, zentraler Fortschrittskarte und Liste fester Habits.
- Heutige Habit-Zustände werden aus lokalen `HabitEntry`-Daten angezeigt und können per Toggle gesetzt oder zurückgesetzt werden.
- Initial State: „Noch keine Gewohnheit erledigt.“ mit Hinweis auf einen kleinen Start.
- Nicht Teil dieser Phase: Habit-Erstellung, Streaks, Reminder, Kalenderansicht, Gamification, KI und Wochen-/Monatsanalyse.

### Phase 4E Wochenreview

- Die Wochenreview-Seite ist eine einfache Wochenansicht mit Header, zentraler Review-Karte, vier Summary-Cards und einem ruhigen Notizformular.
- Summary-Cards zeigen echte Wochenwerte aus Ernährung, Training, Finanzen und Gewohnheiten.
- Review-Notizen bestehen aus „Was lief gut?“, „Was war schwierig?“ und „Fokus für nächste Woche“ und werden lokal gespeichert.
- Empty/Low-Data State: „Sammle ein paar Tage Daten, damit dein Review aussagekräftiger wird.“
- Nicht Teil dieser Phase: KI-Auswertung, Coaching, komplexe Statistiken, Monatsberichte, PDF-Reports und externe Integrationen.

### Phase 5 Einstellungen

- Die Einstellungen-Seite ist eine ruhige Zielwerte-Seite mit separaten Glass-Cards für Ernährung, Training, Finanzen und Allgemein.
- Bearbeitbar sind Kalorienziel, Proteinziel, Workouts pro Woche und Monatsbudget; Währung ist vorerst EUR, Wochenstart Montag.
- Aktionen: Speichern und „Defaults“ zum Zurücksetzen auf Standardwerte.
- Hinweis: „Alle Daten werden lokal auf diesem Mac gespeichert.“
- Nicht Teil dieser Phase: Accounts, Cloud Sync, Export/Backup, Ziel-Historie, Profile, Reminder, KI und externe Integrationen.

### Phase 7A Home-Trainingsplan

- Die Training-Seite ergänzt eine ruhige Glass-Card „Home-Trainingsplan“ für Körpergewicht und einfache Klimmzugstange.
- Die Card zeigt das heutige oder nächste geplante Workout aus einem festen 3-Tage-Plan: Montag Pull + Core, Mittwoch Push + Legs, Freitag Full Body.
- Die Hauptvisualisierung der Card ist ein zentrierter Doppelring: außen Wochenfortschritt, innen Übungsfortschritt des aktuellen Workouts.
- Minimum, Normal und Stark wählen die Übungsliste und abgeleitete Dauer; Minimum gilt als echtes abgeschlossenes Training.
- Übungen werden als lokale Checkliste angezeigt; Satzdetails werden nicht persistiert.
- „Workout abschließen“ speichert eine normale `WorkoutSession`, damit bestehende Listen, Dashboard und Wochenreview unverändert mitzählen.
- Nicht Teil dieser Phase: Übungsdatenbank, eigene Übungen, Satz-/Gewichts-Historie, Kalenderansicht, Drag-and-Drop, Reminder, Videoanleitungen, HealthKit, KI oder externe Integrationen.

### Phase 7B Wochenreview-Diagramme

- Die Wochenreview-Seite ergänzt nach den Summary-Cards eine Sektion „Trends dieser Woche“.
- Fünf kompakte Glass-Cards zeigen 7-Tage-Trends für Kalorien, Protein, Ausgaben, Training und Gewohnheiten.
- Alle Karten nutzen Montag bis Sonntag, zeigen leere Tage als 0 und bleiben auch bei komplett leerer Woche sichtbar.
- Die Charts sind kleine SwiftUI-Sparklines im bestehenden Premium/Glass-Stil; es gibt keine neue externe Dependency.
- Nicht Teil dieser Phase: Langzeit-Analytics, Monats-/Jahresdiagramme, Heatmaps, Kalenderansicht, interaktive Tooltips, Zoom, KI-Auswertung, Reports oder externe Integrationen.

### Phase 7C Gewohnheiten-Redesign

- Die Gewohnheiten-Seite nutzt einen Apple-Fitness-inspirierten Aufbau mit Header, großem Tagesring, Habit-Grid und kompakter Wochenübersicht.
- Die warme Orange-/Gold-Stimmung bleibt die Hauptidentität; einzelne Habits bekommen dezente Akzente für Wasser, Trainieren, Ernährung, Lernen und Schlaf.
- Die fünf Habit-Karten zeigen messbare Tageswerte gegen Zielwerte, Progressbar, Plus/Minus bzw. Schlafroutine-Button und eine kleine Mo-So-Wochenleiste.
- Der große Hero-Ring berechnet den Durchschnitt der fünf Habit-Fortschritte, nicht nur erledigt/offen.
- Nicht Teil dieser Phase: Custom Habits, Habit-Bibliothek, Reminder, Notifications, Streak-Analytics, Kalenderansicht, Heatmap, KI-Coaching, HealthKit, Apple Watch oder externe Integrationen.

### Phase 7D Quick Panels

- Die Floating Bottom Quick Bar bleibt kompakt: Mahlzeit, Training, Plus, Ausgabe und Gewohnheit.
- Mahlzeit, Training, Ausgabe und Gewohnheit öffnen direkt ihr jeweiliges Quick Panel; der Plus-Button öffnet ein allgemeines Quick Action Menü.
- Das Plus-Menü ist in „Eintragen“ und „Schnelle Gewohnheiten“ gegliedert und nutzt kleine Glass-Chips statt großer Formulare.
- Das Gewohnheit-Quick-Panel nutzt die messbaren Phase-7C-Habits mit Wasser, Trainieren, Ernährung getrackt, Lernen und Schlafroutine. Es ersetzt die alte reine Toggle-Liste.
- Quick Panels zeigen ruhige Inline-Erfolgsmeldungen und bleiben im bestehenden Premium-/Glass-Stil.
- Nicht Teil dieser Phase: Notiz-Button in der Bottom Bar, neue Navigation, Telegram, iPhone, HealthKit, KI, Reminder, Custom Habits, Übungsdatenbank oder externe Dependencies.

### Phase 7E Dashboard/Habits/Training-Sync

- Die aktive Habit-Liste lautet Wasser, Trainieren, Ernährung getrackt, Lernen und Schlafroutine.
- Trainieren ist eine abgeleitete Karte: Sie zeigt 0 / 1 bzw. erledigt/offen, hat keine Plus-/Minus-Steuerung und verweist auf Training als Quelle.
- Dashboard-Habits zeigen Tagesfortschritt als Prozentwert und kompakte Chips mit den aktuellen Habit-Werten; Trainieren wird aus abgeschlossenen Workouts erkannt.
- Habit-Quick-Panel und Plus-Menü bieten schnelle Aktionen für Wasser, Ernährung, Lernen und Schlafroutine; Training läuft über das Training-Quick-Panel.
- Das Wochenreview nutzt dieselben fünf Habit-Fortschritte; Trainieren zählt pro Tag mit 100 %, wenn mindestens ein Workout abgeschlossen wurde.

### Phase 7F MVP-Stabilisierung

- Detailseiten zeigen ruhige Empty- und Fehlerzustände ohne technische Fehlermeldungen.
- Quick Panels bleiben bei Mahlzeit, Training, Plus, Ausgabe und Gewohnheit; das Sheet kann bei kleineren Höhen scrollen.
- Numeric Quick-Add-Eingaben werden stabil normalisiert, sodass keine NaN-/Inf-Werte in Ringe, Charts oder Persistenz gelangen.
- Dashboard verwendet keine sichtbaren Mock-/Debug-Aktivitäten im Laufzeitpfad und nutzt dieselbe Tagesbudget-Logik wie Finanzen.
- Settings zeigt Backup & Export mit SQLite, JSON und CSV für Numbers im bestehenden Glass-Stil.
