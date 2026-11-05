# Bestandsaufnahme – AboLife 0.4.1

Stand: 5. November 2026. Quellcodeanalyse des vorhandenen, bereits stark veränderten Arbeitsbaums auf `codex/abolife-quality-evolution`. Keine grafische Bewertung einer laufenden persönlichen App; keine privaten Daten eingesehen.

## Zweck und Technologie

AboLife ist ein persönlicher lokaler Alltagsbegleiter: Tagesstatus, Geld, Bewegung, Gewohnheiten, Zeitplanung und Reflexion sollen an einer Stelle erfassbar sein. Dashboard und Schnellerfassung sind die häufigen Einstiegspunkte. Der AppRouter führt zu neun Fachbereichen; Einstellungen öffnen systemtypisch über das App-Menü. Die Menüleiste ist ein zusätzlicher kurzer Zugang.

Die aktive App verwendet SwiftUI für macOS 14+, Swift-Sprachmodus 5, ObservableObject-Stores, GRDB/SQLite-Repositories und Swift Charts. `AppSession` koordiniert Datenbanköffnung und Recovery. Der separate Node/SQLite-Webteil dient dem privaten Homelab und revisionsgesichertem Datenabgleich. Dormante SwiftData-Typen sind keine zweite produktive Datenbank. `Features/AI` und der vorhandene Assistent gehören zum vorgefundenen Arbeitsstand; dieses Lab ergänzt keine KI-Anbindung.

Gelesene Kernquellen: `AGENTS.md`, `VERSION`, `AppRouter.swift`, `AboLifeTokens.swift`, `AboLifeColors.swift`, `docs/UI_SPEC.md`, `docs/MVP_SCOPE.md`, die zentralen Views und Komponenten aller Fachbereiche, `StatisticsStore.swift`, Habitdefinitionen, Web-Paketkonfiguration und die projektspezifische UI-Prüfanleitung. Architektur und Funktionen wurden aus diesen Quellen abgeleitet, nicht anhand einer älteren ZIP-Version angenommen.

## Screens, Aufgaben und Konsequenzen

| Bereich | Bestehende Aufgaben | Bedeutung für die Konzepte |
|---|---|---|
| Dashboard | Daily-Core-Ring, offene Tagespunkte, Training, Budget, Habits, Woche, Aktivitäten | Orientierung und eine schnelle nächste Aktion müssen sofort erkennbar sein. |
| Finanzen | Monat, Ausgaben/Einnahmen, Kategorien, Buchungen, Budget, Fixkosten, Planung | Restbudget und monatlich ausgegebener Anteil haben klare, getrennte Bedeutungen. Alle Konzepte verwenden dieselben Demo-Buchungen. |
| Training | Wochenziel, Heimtrainingsplan, Checkliste, detaillierte Übungen/Sätze, Verlauf, Fortschritt | Wochenstatus und Einstieg in eine Einheit sind zusammen erreichbar. Abschluss aktualisiert auch den abgeleiteten Trainings-Habit. |
| Gewicht | Messung, Ziel, Historie, Verlauf | Keine Messungen ergänzen oder fehlende Tage als gemessen darstellen; Diagramm mit einzelnen Punkten. |
| Gewohnheiten | Wasser, Lernen, Schlafroutine, abgeleitetes Training, Wochenübersicht | Kleine Änderungen sind direkt ausführbar. Training bleibt abgeleitet. |
| Kalender | Tag/Woche, Termine/Serien, ICS-Import, Themen, vorhandene Planungsengine | Termine als Zeitstruktur zeigen. Bestehende Planungsfunktionen nicht als neue KI-Funktion vermarkten. |
| Statistiken | Zeiträume, Training, Habits, Finanzen, Gewicht, aktive Tage | Zeitbezug und aktuelle Zielwerte nennen; Zahlen müssen aus derselben Fixture kommen. |
| Wochenreview | Zusammenfassung, Trends, drei Freitexte, Speichern | Lesbarer Reflexionsraum; Entwürfe bleiben bei internem Seitenwechsel erhalten. |
| Nachrichten | RSS, Kategorien/Quellen, Lesen/Merken, Lade-/Leer-/Fehlerzustände | Kategorie, Quelle und Lesezustand sichtbar; hier ausschließlich als fiktive Testartikel. |
| Einstellungen | Ziele, Darstellung, Daten, Sync, Backup/Restore | Kein Kontakt zu produktiven Datenmechanismen; Lab bietet nur Beispielbudget, Motion und Demo-Reset. |
| Menüleiste & Quick Add | Tagesstatus, Tagesbudget, Hauptfenster und Eingabedialoge | Das gemeinsame Quick-Add ist in jedem Konzept verfügbar. Ein systemweiter Menüleistenprozess wird im Browser nicht simuliert. |

## Bestehende Gestaltung

Adaptive matte Flächen, Systemschrift, gemeinsame Karten, Textrollen, Abstände und Radien. Akzente orientieren sich an den Bereichen. Die Sidebar gruppiert Training/Gewicht unter Gesundheit. Das Dashboard kombiniert einen prominenten Ring mit mehreren ähnlich aufgebauten Karten. Gemeinsame Motiontokens: Interaktion 120 ms, Navigation 180 ms, Metriken 350 ms, reduziert bei Reduce Motion. Dialoge verwenden feste Köpfe und scrollbare Inhalte. Mutationsergebnisse und Fehler werden berücksichtigt.

**Stärken:** lokale Datenhoheit, klar benannte Bereiche, direkte Schnellerfassung, konsistentes System, gut etablierte Tagesmetapher, vorhandene barrierearme Systemsteuerung.

**Gestalterische Hypothesen für Verbesserungen:** Viele ähnlich gewichtete Karten können Prioritäten verdecken. Die feste Sidebar beansprucht Raum; die Gesundheitsgruppierung kann häufige Aktionen verstecken. Die Informationsdichte steigt mit Woche, Aktivitäten und Detailmetriken. Eine alternative Navigation und gezieltere visuelle Hierarchie könnten das Gefühl stärker verändern als neue Farben allein. Diese Punkte sind Hypothesen zur Bewertung durch den Nutzer, keine Ergebnisse einer Usability-Studie.

## Fünf unabhängige Experimente

A behält die Vertrautheit nativer Werkzeuge. B macht Tagesstatus zum räumlichen Zentrum, mit Dock und Instrumenten am Rand. C priorisiert typografisch und setzt einen nummerierten Index sowie asymmetrische Datenraster ein. D behandelt die App als anpassbaren Arbeitsplatz mit kompaktem Werkzeugband und rotierbarer Widgetreihenfolge. E verändert die Grundmetapher: statt einer Metrikzentrale ein Tagebuch mit chronologischem Tagespfad, Kapitelregister und Randnotizen.

Layouts, Navigationsformen und typografische Hierarchien sind verschieden, während Daten und Testaktionen gleich bleiben. B darf in dieser ausdrücklich freigegebenen Konzeptphase Transparenz und räumliche Effekte ausprobieren; die Vorgaben für die bestehende native Produktoberfläche werden dadurch nicht geändert.

## Datengrenze und spätere Entscheidung

Der gesamte neue Code liegt in `design-lab`. Es besteht weder ein Import aus nativen Repositories noch ein Zugriff auf persönliche Dateien. Finanzdarstellung zeigt nur den monatlichen Ausgabenanteil; keine neue Tagesbudgetformel. Kalender, Gewicht und Artikel sind als fiktiv markiert. Ernährung und Telegram werden nicht zurückgebracht. Es gibt keine neue KI-Lernzeitfunktion.

Das Lab evaluiert Informationsarchitektur und repräsentative Interaktionen. Es ist keine Neuimplementierung aller fachlichen Engines. Erst nach den Bewertungen werden Zielkonflikte gemeinsam geklärt und Konzept F gestaltet. Für die produktive Implementierung ist eine separate ausdrückliche Freigabe erforderlich.
