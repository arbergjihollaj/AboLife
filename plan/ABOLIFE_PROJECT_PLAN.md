# AboLife Projektplan

> **Zentrale Projektdatei für Planung, Codex und spätere Umsetzung**  
> Stand: 11. Juni 2026  
> Ziel: Eine persönliche macOS-App, die Ernährung, Training, Finanzen, Gewohnheiten und Wochenreviews in einem ruhigen täglichen Dashboard verbindet.

---

## 0. Kurzfazit

AboLife ist als persönliches Projekt sinnvoll, **wenn Version 1 nicht als vollständiges Life-OS gebaut wird**. Der stärkste Kern ist ein ruhiges, tägliches Entscheidungs-Dashboard, das schnell zeigt:

- Wie läuft mein Tag?
- Bin ich bei Ernährung und Protein auf Kurs?
- Habe ich Training oder Bewegung erledigt?
- Bin ich finanziell im Rahmen?
- Welche Gewohnheiten fehlen noch?
- Was lerne ich aus dieser Woche?

**Empfohlene Richtung:** native macOS-App mit SwiftUI, lokaler Datenbank, Dashboard-first, Quick Add und klar begrenztem MVP.

---

## 1. Projektübersicht

| Punkt | Entscheidung |
|---|---|
| Projektname | **AboLife** |
| Plattform v1 | native macOS-App |
| Zielgruppe | nur persönliche Nutzung |
| Kernnutzen | tägliche Selbststeuerung durch Dashboard + Quick Add + Review |
| Datenhaltung | lokal, offline nutzbar |
| KI | später optional, nicht Kern der App |
| Mobile Nutzung | später über iPhone-App, App Shortcuts oder Telegram |
| Design | Apple-like, ruhig, hochwertig, grafisch, aber nicht überladen |

---

## 2. Kernidee

AboLife ist kein einzelner Kalorientracker, kein einzelner Finanzplaner und keine reine Fitness-App. Die App ist ein **persönliches Lebens-Dashboard**, das mehrere Alltagsbereiche verbindet, aber nur so weit, wie es für tägliche Entscheidungen wirklich nützlich ist.

### Kernformulierung

> **AboLife ist eine persönliche macOS-App, die Ernährung, Training, Finanzen und tägliche Gewohnheiten in einem ruhigen Dashboard verbindet. Die App hilft mir, täglich bessere Entscheidungen zu treffen, ohne fünf verschiedene Apps benutzen zu müssen. Der Fokus liegt auf einfachem Tracking, sichtbarem Fortschritt und realistischen Routinen.**

---

## 3. Problem, das die App löst

Das eigentliche Problem ist nicht: „Ich brauche eine App für Kalorien.“

Das eigentliche Problem ist:

> **Ich habe keinen klaren, dauerhaft nutzbaren Plan, wie ich Training, Ernährung, Finanzen und Gewohnheiten in meinen Alltag integriere.**

AboLife soll genau das vereinfachen:

```text
Unstrukturierter Alltag
        ↓
Schnelles Erfassen
        ↓
Klares Tagesdashboard
        ↓
Wöchentlicher Review
        ↓
Bessere Entscheidungen
```

---

## 4. Was an der Idee schlau ist

| Stärke | Warum das sinnvoll ist |
|---|---|
| Persönlicher Fokus | Kein Login, kein Billing, keine Öffentlichkeit, keine Durchschnittsnutzer. Die App darf exakt für dich gebaut werden. |
| Dashboard-first | Die App beantwortet sofort: „Bin ich heute auf Kurs?“ |
| Quick Add | Wenig Reibung ist wichtiger als komplexe Features. Wenn Eintragen nervt, wird die App nicht genutzt. |
| Lokale Daten | Schnell, privat, offline, einfach zu kontrollieren. |
| Manuelles Tracking in v1 | Realistisch, robust und unabhängig von unsicheren Food-Datenbanken oder APIs. |
| Weekly Review | Verhindert, dass die App nur ein Archiv wird. Sie wird zu einem Lernsystem. |
| Grafiken mit klarer Hierarchie | Viele Visuals sind möglich, solange jede Karte nur eine Hauptaussage hat. |
| Telegram später | Gute Idee für unterwegs, aber nicht Teil des Kerns. |

---

## 5. Was riskant oder unschlau ist

| Risiko | Warum gefährlich | Gegenmaßnahme |
|---|---|---|
| Alles in Version 1 bauen | Ernährung, Training, Finanzen, Habits, Sync und KI wären mehrere Produkte gleichzeitig. | MVP hart begrenzen. |
| Telegram zu früh | Braucht Bot, Server/Long Polling, Sicherheit und Sync-Logik. | Erst nach stabilem lokalen Kern. |
| Food-Datenbank zu früh | Lebensmitteldaten sind oft unvollständig, regional unterschiedlich oder API-abhängig. | V1: manuell + Favoriten/Templates. |
| Schöne UI ohne Datenmodell | Spätere Trends, Reviews und Migrationen werden chaotisch. | UI-Prototyp ja, aber mit klaren Datenverträgen. |
| HealthKit auf macOS | macOS ist für Health-Daten kein guter v1-Startpunkt. | Health später iPhone-first. |
| KI als Kern | Macht Produkt unklar und abhängig von API/Prompt-Logik. | KI nur optional für spätere Auswertung. |
| App bauen statt Leben strukturieren | Entwicklung fühlt sich produktiv an, kann aber Verhalten ersetzen. | Weekly Review und kleine tägliche Kernmetriken einbauen. |

---

## 6. Beste Vorgehensweise

### Grundregel

> **Erst planen, dann UI-Prototyp, dann Datenmodell, dann echte Module. Nicht alles parallel.**

### Phasen

```text
Phase 0  Konzept & Spezifikation
Phase 1  UI-Prototyp mit Mock-Daten
Phase 2  Lokale Datenbank + Datenmodell
Phase 3  Quick Add + erste echte Einträge
Phase 4  Ernährung, Training, Finanzen, Habits
Phase 5  Weekly Review + Statistiken
Phase 6  Backup/Export
Phase 7  Spätere Erweiterungen: Telegram, iPhone, KI, Health
```

---

## 7. MVP-Abgrenzung

### Muss in Version 1 rein

- native macOS-App
- Dashboard als Hauptscreen
- Quick Add
- Kalorien- und Proteintracking, manuell
- Training heute / Workout erledigen
- einfache Ausgaben und Monatsbudget
- 3–5 tägliche Habits
- Wochenreview
- 7-Tage-Mini-Trends
- lokale Speicherung
- Empty States
- Backup/Export-Grundlage

### Sollte in Version 1 rein

- Mahlzeiten-Favoriten oder Templates
- wiederverwendbare Workout-Templates
- Gewicht als einfacher manueller Wert
- Tastenkürzel für Quick Add
- Mock-/Seed-Daten für UI-Previews

### Später

- Telegram-Bot
- iPhone-App
- Web-App
- Food-Search / Barcode
- Apple Health
- Kalender/Reminders
- KI-Auswertung
- Cloud-Sync

### Auf keinen Fall in Version 1

- Banking-Sync
- Barcode-Scanner
- OCR für Essen oder Rechnungen
- AI-Coach
- komplexes Cross-Device-Sync
- vollwertige Food-Datenbank
- Web-App parallel zur Mac-App

---

## 8. Empfohlener Tech-Stack

| Bereich | Empfehlung | Begründung |
|---|---|---|
| UI | **SwiftUI** | Native macOS-App, Apple-like Design, guter Fit für Dashboard und Sidebar. |
| State | **Observation** | Moderner SwiftUI-State für Stores/ViewModels. |
| Datenbank | **SQLite + GRDB** | Explizites Schema, Migrationen, Aggregationen für Trends/Reviews, gute Exportierbarkeit. |
| Charts | **Swift Charts + eigene Ring-Komponente** | Native Charts für Trends; Daily-Core-Ring besser als eigene SwiftUI-Komponente. |
| Tests | **Swift Testing + XCTest** | Unit-Tests modern, UI-Tests weiterhin mit XCTest. |
| Backup | SQLite Backup + JSON/CSV Export | Restore-fähig und zusätzlich lesbar/exportierbar. |
| Projektverwaltung | GitHub Issues / Projects / Milestones | Für Solo-Projekt ausreichend und direkt am Code. |
| Dokumentation | Markdown im Repo | Codex-freundlich, versionierbar, leicht zu pflegen. |

### Alternative

SwiftData ist okay, wenn AboLife bewusst Apple-only und single-device bleibt. Für langfristige Erweiterungen mit Telegram, Export, Web oder sauberer Datenanalyse ist **GRDB + SQLite** wahrscheinlich stabiler.

---

## 9. Architekturvorschlag

AboLife sollte keine übertriebene Clean-Architecture-Kathedrale werden. Es braucht eine klare, feature-orientierte Struktur.

```text
AboLife/
├── App/
│   ├── AboLifeApp.swift
│   ├── AppRouter.swift
│   └── Settings/
│
├── Foundation/
│   ├── Types/
│   ├── Extensions/
│   ├── Formatters/
│   └── Validation/
│
├── DesignSystem/
│   ├── Colors/
│   ├── Typography/
│   ├── CardStyles/
│   └── Components/
│
├── Persistence/
│   ├── Database/
│   ├── Migrations/
│   ├── Models/
│   ├── Repositories/
│   ├── Queries/
│   └── SeedData/
│
├── Features/
│   ├── Dashboard/
│   ├── Nutrition/
│   ├── Training/
│   ├── Finance/
│   ├── Habits/
│   ├── Review/
│   └── BodyMetrics/
│
├── Charts/
│   ├── CoreRingView.swift
│   ├── TrendChart.swift
│   ├── BudgetBarChart.swift
│   └── ProgressViews.swift
│
├── Services/
│   ├── BackupService.swift
│   ├── ExportService.swift
│   ├── ImportService.swift
│   └── FutureIntegrations/
│
├── PreviewSupport/
│   ├── PreviewData.swift
│   ├── PreviewDatabase.swift
│   └── SampleStates.swift
│
└── Tests/
    ├── Unit/
    ├── Integration/
    └── UI/
```

### Architektur-Regel

- Views zeigen UI.
- Stores/ViewModels halten UI-State und Actions.
- Repositories sprechen mit der Datenbank.
- Services machen Nebenwirkungen wie Export, Backup oder spätere Integrationen.
- Primärdaten werden gespeichert, Summen und Trends werden abgeleitet.

---

## 10. Datenmodell-Übersicht

### Zentrale Modelle

| Modell | Zweck |
|---|---|
| `DailyLog` | Tagesanker für Notiz, Bewertung und Tageszusammenfassung. |
| `NutritionEntry` | Mahlzeit oder Ernährungseintrag mit kcal und Protein. |
| `WorkoutSession` | Ein abgeschlossenes oder geplantes Training. |
| `ExerciseEntry` | Einzelne Übung innerhalb eines Workouts. |
| `FinanceEntry` | Ausgabe oder Einnahme. |
| `HabitEntry` | Erledigter oder gemessener Habit pro Tag. |
| `BodyMetricEntry` | Gewicht, Schlaf oder Tagesbewertung. |
| `AppSettings` | Ziele, Budget, Standardwerte, Wocheinstellungen. |
| `WeeklyReview` | Reflexion und Zusammenfassung einer Woche. |

### Datenprinzip

```text
Einträge sind Wahrheit.
Summen sind berechnet.
Reviews sind bewusste Auswertung.
```

Das verhindert, dass die App später widersprüchliche Zahlen speichert.

---

## 11. UI/UX-Richtung

### Design-Ziel

AboLife soll wirken wie:

- Apple-like
- ruhig
- hochwertig
- persönlich
- visuell stark
- nicht überladen
- nicht wie eine hektische Fitness-App
- nicht wie eine Broker-App
- nicht wie ein To-do-Chaos

### UI-Regeln

| Regel | Bedeutung |
|---|---|
| Eine Karte = eine Hauptaussage | Jede Card hat genau einen Fokus. |
| Maximal eine Hauptgrafik pro Karte | Kein visuelles Durcheinander. |
| Keine Tabellen im Dashboard | Details gehören in Modulansichten. |
| Dashboard zeigt heute und diese Woche | Keine tiefe Historie auf dem Startscreen. |
| Empty States sind Pflicht | Die App muss auch ohne Daten hochwertig wirken. |
| Grafiken unterstützen Entscheidungen | Keine Deko-Charts. |
| Ruhige Farben | Akzentfarben sparsam und bewusst. |

---

## 12. Dashboard-Konzept

### Hauptfrage

> **Was ist heute wichtig und bin ich auf Kurs?**

### Aufbau

```text
┌──────────────────────────────────────────────┐
│ Hero: Daily Core Ring                         │
│ Heute, Tagesstatus, nächster sinnvoller Schritt│
└──────────────────────────────────────────────┘

┌──────────────────────┐ ┌──────────────────────┐
│ Kalorien              │ │ Protein               │
│ 1450 / 2200 kcal      │ │ 95 / 160 g            │
│ Progress + Mini Trend │ │ Progress + Mini Trend │
└──────────────────────┘ └──────────────────────┘

┌──────────────────────┐ ┌──────────────────────┐
│ Training              │ │ Finanzen              │
│ Push Day offen        │ │ Monatsbudget ruhig    │
│ 2 / 3 diese Woche     │ │ Restbetrag sichtbar   │
└──────────────────────┘ └──────────────────────┘

┌──────────────────────────────────────────────┐
│ Wochenstatus                                  │
│ Mo ●  Di ●  Mi ◐  Do ●  Fr ○  Sa ○  So ○      │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│ Quick Add: Mahlzeit | Workout | Ausgabe | ... │
└──────────────────────────────────────────────┘
```

### Wichtigster Button

```text
+ Quick Add
```

Quick Add öffnet schnelle Eingaben für:

- Mahlzeit
- Workout
- Ausgabe
- Gewicht
- Notiz
- Habit

---

## 13. Visualisierungs-Konzept

| Visualisierung | Einsatz |
|---|---|
| Daily-Core-Ring | Gesamtstatus des Tages. |
| Kalorienbalken | Tagesziel und Restkalorien. |
| Proteinbalken | Fortschritt Richtung Proteinziel. |
| 7-Tage-Sparkline | Kleine Trends ohne große Analyse. |
| Wochen-Dot-Grid | Welche Tage liefen gut? |
| Finanz-Monatsbalken | Sparen, Ausgaben, Restbudget. |
| Training-Frequenz | 2/3 Workouts diese Woche. |
| Review-Scores | Wöchentliche Einschätzung. |

### Grafisch reich, aber ruhig

```text
1 große Hauptgrafik
2–4 wichtige Karten
kleine Mini-Charts nur unterstützend
viel Abstand
klare Prioritäten
```

---

## 14. Telegram und spätere Erweiterungen

Telegram ist sinnvoll, aber nicht für v1.

### Warum sinnvoll?

Du könntest unterwegs Einträge machen:

```text
/meal Döner 850 kcal 45 protein
/workout done push 35min
/expense Mensa 4.20
/weight 82.4
```

### Warum später?

Telegram braucht:

- Bot-Token
- Update-Verarbeitung
- Long Polling oder Webhook
- Sicherheitslogik
- eventuell Server oder Bridge-Service
- Sync mit lokaler App

### Empfohlene spätere Architektur

```text
Telegram Bot
    ↓
Bridge / Inbox-Service
    ↓
AboLife Import-Inbox
    ↓
Lokale Datenbank
```

Nicht direkt:

```text
Telegram schreibt direkt in die Mac-Datenbank
```

### Mögliche Alternative

Für Apple-Workflows könnten später **App Intents + Shortcuts** natürlicher sein als Telegram.

---

## 15. Roadmap

### Phase 0: Planung

- Projektdateien erstellen
- MVP festlegen
- Tech-Stack entscheiden
- Datenmodell definieren
- UI-Regeln festlegen

### Phase 1: UI-Prototyp

- macOS-App-Shell
- Sidebar
- Dashboard mit Mock-Daten
- Core Ring
- Kartenlayout
- Quick Add als Mock

### Phase 2: Lokale Persistenz

- SQLite/GRDB einbauen
- Migrationen
- Repositories
- Seed-Daten
- erste Tests

### Phase 3: Quick Add real machen

- NutritionEntry
- WorkoutSession
- FinanceEntry
- HabitEntry
- BodyMetricEntry

### Phase 4: Module

- Ernährung
- Training
- Finanzen
- Habits
- Körperwerte

### Phase 5: Review und Statistiken

- Weekly Review
- 7-Tage-Trends
- Monatsübersicht
- Completion-Rates

### Phase 6: Stabilisierung

- Backup
- Export
- Tests
- Fehlerzustände
- UI-Polish

### Phase 7: Später

- Telegram
- iPhone-App
- App Shortcuts
- Health
- Kalender
- KI
- Sync

---

## 16. Codex-Workflow

### Rolle von Codex

> Codex ist nicht der Projektleiter. Codex ist der Entwickler.

Du gibst Codex kleine, klare Aufgaben mit Grenzen.

### Gute Codex-Tasks

```text
Baue nur die ProteinProgressCard mit Mock-Daten.
```

```text
Erstelle nur die Datenbankmigration für NutritionEntry.
```

```text
Schreibe Tests für die Budgetberechnung.
```

### Schlechte Codex-Tasks

```text
Baue die ganze App.
```

```text
Mach das Dashboard fertig.
```

```text
Implementiere Training, Ernährung und Finanzen.
```

### Dauerhafte Codex-Regeln

- keine neuen Packages ohne Erlaubnis
- keine Telegram-, KI-, Health- oder Sync-Arbeit in MVP-Tasks
- keine stillen Refactorings
- keine persistierten Summen ohne Begründung
- jede Datenbankänderung braucht Migration
- jede Kernkarte braucht Empty/Partial/Full-State
- jede UI-Komponente braucht Preview-Daten
- nach Änderungen Build/Test prüfen
- immer Scope gegen `MVP_SCOPE.md` prüfen

---

## 17. Empfohlene Repo-Dokumente

```text
docs/
├── PRODUCT_SPEC.md
├── MVP_SCOPE.md
├── ARCHITECTURE.md
├── DATA_MODEL.md
├── UI_SPEC.md
├── ROADMAP.md
├── CODEX_RULES.md
├── TEST_PLAN.md
├── EXPORT_BACKUP.md
└── DECISIONS.md
```

### Zweck

| Datei | Zweck |
|---|---|
| `PRODUCT_SPEC.md` | Was ist AboLife und warum existiert es? |
| `MVP_SCOPE.md` | Was ist v1 und was nicht? |
| `ARCHITECTURE.md` | Technische Entscheidungen. |
| `DATA_MODEL.md` | Modelle, Felder, Beziehungen. |
| `UI_SPEC.md` | Layout, Karten, Visualisierungen, States. |
| `ROADMAP.md` | Reihenfolge der Umsetzung. |
| `CODEX_RULES.md` | Regeln für Codex-Arbeit. |
| `TEST_PLAN.md` | Was getestet werden muss. |
| `EXPORT_BACKUP.md` | Backup, Restore, Export. |
| `DECISIONS.md` | Architekturentscheidungen mit Begründung. |

---

## 18. Erster sinnvoller Codex-Prompt

```text
Erstelle für mein privates macOS-Projekt „AboLife“ zunächst nur die Projektdokumentation und noch keinen App-Code.

Ziel:
Ich will Version 1 einer persönlichen, lokalen, offline nutzbaren macOS-App planen, die Dashboard, Quick Add, Kalorien/Protein, Training, Finanzen, Habits und Weekly Review verbindet.

Wichtig:
- Noch keine Implementierung von Views, Datenbank oder Packages
- Noch keine iPhone-, Web-, Telegram-, Health-, Kalender- oder KI-Integration
- Keine neuen Dependencies vorschlagen
- Arbeite nur dokumentationsorientiert
- Schreibe klar, konkret und knapp
- Sprache: de-DE

Bitte lege diese Dateien mit sinnvollem Inhalt an:
- PRODUCT_SPEC.md
- MVP_SCOPE.md
- ARCHITECTURE.md
- DATA_MODEL.md
- UI_SPEC.md
- ROADMAP.md
- CODEX_RULES.md

Anforderungen:
- PRODUCT_SPEC.md: Produktziel, Kernproblem, Zielbild, Nicht-Zielbild, täglicher Nutzen
- MVP_SCOPE.md: Muss rein / sollte rein / später / nicht in Version 1
- ARCHITECTURE.md: Empfehlung für SwiftUI + lokale Persistenz, kurze Begründung, keine Overengineering-Architektur
- DATA_MODEL.md: Vorschlag für DailyLog, NutritionEntry, WorkoutSession, ExerciseEntry, FinanceEntry, HabitEntry, BodyMetricEntry, AppSettings, WeeklyReview
- UI_SPEC.md: Dashboard-Struktur, Sidebar, Quick Add, Kartenregeln, Empty States, Dark/Light-Verhalten
- ROADMAP.md: Phasen von Konzept bis spätere Integrationen
- CODEX_RULES.md: strikte Arbeitsregeln für spätere Codex-Tasks

Zusatzregel:
Jede Datei soll Entscheidungen explizit machen und Scope begrenzen. Keine generischen Phrasen, keine Marketing-Sprache.
```

---

## 19. Nächster Schritt

Der nächste sinnvolle Schritt ist nicht direkt Xcode.

### Reihenfolge ab jetzt

```text
1. Diese Projektdatei prüfen
2. Daraus visuelle HTML-Datei erstellen
3. Repo-Dokumente generieren
4. Erst danach Codex mit Dokumentations-Prompt starten
5. Danach UI-Prototyp mit Mock-Daten bauen
```

### Heute konkret

- `ABOLIFE_PROJECT_PLAN.md` als Hauptdatei speichern
- HTML-Übersicht daraus erzeugen
- danach `docs/`-Dateien für Codex erstellen

---

## 20. Finale Entscheidungsempfehlung

| Frage | Empfehlung |
|---|---|
| Soll AboLife gebaut werden? | Ja, aber strikt MVP-first. |
| Name | AboLife behalten. Für privat sehr passend. |
| Plattform v1 | native macOS-App. |
| Stack | SwiftUI + GRDB/SQLite + Swift Charts. |
| Start | Dokumentation, dann UI-Prototyp mit Mock-Daten. |
| Nicht jetzt | Telegram, iPhone, Health, KI, Web, Sync. |
| Wichtigste Produktregel | Quick Add + Dashboard müssen täglich nützlich sein. |

---

# Ende

AboLife sollte nicht als perfektes Life-OS starten. Es sollte als **kleines, hochwertiges tägliches Kontrollzentrum** starten, das Ernährung, Training, Finanzen und Gewohnheiten so verbindet, dass du bessere Entscheidungen triffst.

Wenn Version 1 täglich nutzbar ist, kann alles Weitere später wachsen.
