# MVP_SCOPE.md

# AboLife MVP Scope

## 1. MVP-Leitlinie

Version 1 soll hochwertig wirken, aber technisch kontrolliert bleiben. Der MVP ist kein vollständiges Life-OS, sondern ein lokales macOS-Dashboard mit Quick Add und wenigen Kernmodulen.

## 2. Muss rein

Diese Funktionen gehören zwingend in Version 1:

### App-Grundlage

- native macOS-App
- SwiftUI-Oberfläche
- lokale Speicherung
- offline nutzbar
- Dashboard als Hauptscreen
- Sidebar-Navigation
- Settings-Screen für Grundwerte

### Dashboard

- Daily-Core-Übersicht
- Kalorienstatus
- Proteinstatus
- heutiges Training
- Monatsbudget / Finanzstatus
- Habit-Status
- 7-Tage-Übersicht

### Quick Add

Quick Add muss folgende Einträge unterstützen:

- Mahlzeit
- Training
- Ausgabe
- Gewicht
- Habit
- Notiz

### Ernährung

- manuelle Kalorienerfassung
- manuelle Proteinerfassung
- Mahlzeitentitel
- Zeitpunkt
- Tages- und Wochenübersicht

### Training

- Workout-Session erstellen
- Training abschließen
- Dauer eintragen
- Übungen optional erfassen
- Wochenstatus anzeigen

### Finanzen

- Ausgabe erfassen
- Kategorie erfassen
- Monatsbudget anzeigen
- Restbudget anzeigen
- einfache Wochen-/Monatsübersicht

### Habits

- 3 bis 5 feste Gewohnheiten
- tägliches Abhaken
- Wochenstatus

### Weekly Review

- Wochenrückblick speichern
- Wins
- Probleme
- Fokus für nächste Woche

## 3. Sollte rein

Diese Funktionen sind sinnvoll, aber nicht kritisch:

- Mahlzeiten-Favoriten
- Workout-Templates
- Tastenkürzel für Quick Add
- Gewichtstrend
- Export als JSON oder CSV
- Seed-/Mock-Daten für Previews
- Empty States für alle Kernkarten

## 4. Später

Diese Funktionen sind explizit spätere Versionen:

- Telegram-Bot
- iPhone-App
- Web-App
- Apple Health
- Kalenderintegration
- Apple Reminders
- Shortcuts / App Intents
- KI-Zusammenfassungen
- FoodDataCentral / OpenFoodFacts
- Barcode-Scanner
- Cloud-Sync
- komplexe Trainingsprogression
- automatische Bankdaten

## 5. Auf keinen Fall in Version 1

Nicht in Version 1 bauen:

- Login-System
- öffentliche Accounts
- Telegram-Sync
- iPhone-App
- Web-App
- HealthKit-Automatik
- KI-Coach
- Chatbot
- Banking-Import
- Barcode-Scanner
- OCR
- komplexe Lebensmittel-Datenbank
- komplexe Cloud-Synchronisation

## 6. MVP-Abbruchkriterien

Ein Feature wird aus Version 1 entfernt, wenn:

- es externe Infrastruktur braucht
- es mehr als ein Modul gleichzeitig verändert
- es eine neue große Dependency braucht
- es den Quick-Add-Flow verlangsamt
- es das Dashboard überlädt
- es keine tägliche Entscheidung unterstützt

## Freigegebener Erweiterungsumfang 0.2 (26. Oktober 2026)

Eigenständige, parallel nutzbare Kalender-Version: eigene Kennung und Datenkopie; manuelle Uni-/Trainings-/Privattermine; Wochenserien mit Semesterende und Ausnahmen; lokale ICS-Vorschau und kontrollierter Wiederimport; persönliche Lern- und Wegezeiten; Lernthemen, Tagesgrenzen, Prüfungstermine, automatische Vorschläge, Fixieren, Verschieben, Auslassen und Bewertungen. Keine Apple-Kalender-Anbindung, PDF-Erkennung, Cloud oder externe KI. Persönliche Stundenplandaten müssen bei der Einrichtung eingetragen oder importiert werden.
