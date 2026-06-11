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
