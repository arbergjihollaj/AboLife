# CODEX_RULES.md

# AboLife Codex Rules

Aktuelle Freigabe vom 27.10.2026: Kalender/Lernplanung fertigstellen, Ernährung/Telegram entfernen, App-Icon ergänzen, gemeinsame Datenhaltung und mobile Weboberfläche aufbauen sowie News ergänzen. Die früheren MVP-Verbote für genau diese beauftragten Arbeiten sind damit aufgehoben. Keine Mail-, Health- oder KI-Erweiterung ohne weiteren Auftrag.

## 1. Grundregel

Codex ist Entwickler, nicht Produktmanager. Codex darf nicht eigenständig Features erfinden oder Scope erweitern.

## 2. Vor jeder Aufgabe

Codex muss zuerst lesen:

- PRODUCT_SPEC.md
- MVP_SCOPE.md
- ARCHITECTURE.md
- DATA_MODEL.md
- UI_SPEC.md
- ROADMAP.md
- CODEX_RULES.md

Dann muss Codex kurz sagen:

- welche Dateien relevant sind
- was umgesetzt wird
- was ausdrücklich nicht umgesetzt wird

## 3. Scope-Regeln

Codex darf nicht ohne ausdrückliche Freigabe:

- neue Dependencies hinzufügen
- Persistenztechnologie ändern
- Cloud-Sync einbauen
- Telegram einbauen
- KI einbauen
- HealthKit einbauen
- iPhone-App anlegen
- Web-App anlegen
- große Refactorings durchführen
- mehrere Module gleichzeitig umbauen

## 4. Task-Größe

Jeder Task soll klein und reviewbar sein.

Gute Tasks:

- eine Dashboard Card bauen
- eine Datenbankmigration erstellen
- einen Quick-Add-Flow bauen
- eine Repository-Methode testen
- einen Empty State hinzufügen

Schlechte Tasks:

- baue das ganze Dashboard fertig
- implementiere Training komplett
- mach die App schön
- füge Sync hinzu
- baue alles aus der Roadmap

## 5. UI-Regeln

Codex muss einhalten:

- eine Karte = eine Hauptaussage
- maximal eine Hauptzahl pro Karte
- maximal eine primäre Visualisierung pro Karte
- keine Tabellen auf dem Dashboard
- Empty State für jede Kernkarte
- keine visuelle Überladung
- System Appearance respektieren
- keine Neonfarben

## 6. Datenregeln

- Entries sind Primärwahrheit
- Summen werden berechnet
- keine persistierten Summen ohne Begründung
- jede Schemaänderung braucht Migration
- jede Migration braucht Test oder klare Prüfnotiz
- Datenmodelle nicht ohne DATA_MODEL.md aktualisieren

## 7. Build- und Test-Regeln

Nach relevanten Änderungen:

- Build ausführen
- Tests ausführen, wenn vorhanden
- Ergebnis dokumentieren

Bei Datenlogik:

- Unit-Test oder Integrationstest schreiben

Bei UI:

- Preview-Daten oder Mock-State bereitstellen

## 8. Dokumentationsregeln

Wenn Codex eine Entscheidung trifft, muss sie dokumentiert werden.

Bei Architekturentscheidungen:

- ARCHITECTURE.md aktualisieren
- falls nötig DECISIONS.md oder ADR erstellen

Bei Scopeänderungen:

- MVP_SCOPE.md aktualisieren

Bei Datenmodelländerungen:

- DATA_MODEL.md aktualisieren

## 9. Abschluss jeder Aufgabe

Codex muss am Ende zusammenfassen:

- was geändert wurde
- welche Dateien betroffen sind
- welche Tests/Builds ausgeführt wurden
- was nicht gemacht wurde
- welche nächsten Schritte sinnvoll wären

## 10. Verbotene Muster

Codex soll vermeiden:

- „Ich habe zusätzlich noch...“
- unnötige Abstraktionsschichten
- unklare Helper-Dateien
- große Views mit zu viel Logik
- globale Zustände ohne Begründung
- direkte Datenbanklogik in Views
- UI-Polish ohne Datenvertrag

## Freigabe vom 2. November 2026

BonsaiBar-Masterprompt und anschließender Auftrag „mach alles“ geben die getrennte lokale AboLife-AI-Integration frei: Connector, ausdrücklich gefilterter Kontext, KI-Ansicht/Quick Action und bestätigte typisierte Aktionen. Bestehende Funktionen und Dashboardaufbau bleiben erhalten; keine Mail-/HealthKit-/Remote-Erweiterung ist damit aktiviert.
