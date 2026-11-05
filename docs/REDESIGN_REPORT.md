# Natives Redesign – Ergebnis und Prüfgrenzen

Freigabe und Umsetzung: 6. November 2026. Aktive App bleibt `AboLife.xcodeproj`, Schema AboLife, Bundle `com.private.AboLife`, Version 0.4.1.

## Ergebnis

Drei native Designs lassen sich unter Einstellungen wechseln: Spatial, Bento und Fieldnotes. Die Oberfläche verwendet dieselben vorhandenen Fachstores, dieselbe GRDB-Datenbank, denselben Sync und denselben lokalen KI-Assistenten. Darstellung und Akzent sind lokale Szeneinstellungen. Im Bento-Modus werden Widgets über Drag-and-drop oder Auf-/Ab-Aktionen sortiert. Unbekannte oder doppelte Widgetwerte werden repariert, ohne gültige Reihenfolgen zu verlieren.

Der App-Router verwendet stabile Inhalts-/Navigationsidentitäten beim Layoutwechsel. Der Wochenreview-Store bleibt bestehen. Die vorhandene KI öffnet weiter ihre echte Dialogansicht mit Connector, expliziten Freigaben, Kontextvorschau, Chat, Abbruch und separater Bestätigung von Aktionen. Keine zweite KI-Anbindung, kein Live-Modellaufruf im Test und keine neue Lernzeit-KI-Funktion.

Es wurden keine Migrationen und keine Änderungen an Finanzformeln eingeführt. Historische Ernährungstabellen und Backupmechanismen bleiben erhalten.

## Bereinigung und Struktur

- Sechs nachweislich unreferenzierte Placeholder-Views samt Xcode-Einträgen entfernt.
- Die tatsächlich funktionsfähige Schnellerfassung heißt jetzt `QuickAddSheet`.
- Frühere Iconentwürfe unter `docs/design-assets/icon-concepts`, alte Fensterbilder unter `docs/archive/screenshots-0.4`.
- Individuelle Planungsdokumente, ältere Story-/Videoarbeiten und nicht reproduzierbare Zwischenstände lokal unter `work/archive` erhalten.
- Rund **1,26 GB** reproduzierbare alte Build-/Analyseartefakte, doppelte Build-Bundles und veraltete Paket-ZIPs entfernt. Die aktuelle App/ZIP, aktuelle Testcaches und Quellstand-Sicherungen bleiben verfügbar. Exakte entfernte Pfade: [Bereinigungsprotokoll](reports/redesign-cleanup.json).
- Persönliches Designfeedback und die generierte Offline-HTML sind vom Git-Quellstand ausgeschlossen. Der Offlinebuilder wird vor den Lab-Tests ausgeführt.

## Tatsächliche Prüfungen

| Prüfung | Ergebnis |
|---|---|
| SwiftPM / native Verträge | 281 Tests entdeckt, 278 ausgeführt, 3 optionale echte KI-Livetests übersprungen, 0 Fehler |
| Node / privater Webteil | 26 bestanden, 0 Skips |
| Separates Design Lab | 19 bestanden |
| Format / SwiftLint / Publication-Scan | Erfolgreich; Baseline nicht neu erzeugt |
| Native Paketierung | Release-Build und Assets erfolgreich; Ad-hoc-Signatur verifiziert |
| Xcode-Projektdatei | Plist syntaktisch gültig; neue Quellen registriert, gelöschte entfernt |
| Native manuelle UI | Drei Designs, Darstellung, Widgetverschiebung und bestehender KI-Dialog in isolierter Demo angesehen |
| Bildreferenzen | 12 echte native Dashboard-Renderings, drei Designs × zwei Darstellungen × zwei Breiten |
| Automatisierte neue UI-Prüfung | Vorbereitet, nicht ausgeführt; Xcode-/Sandboxgrenze vor dem Testlauf |

Die Bildprüfung fand einen Fehler im ursprünglichen Render-Test: Die Übersicht wurde vor der Installation der Environment aufgebaut. Der Test rendert jetzt die tatsächlich gemountete Dashboard-View mit einem isolierten Übersichtsmodus. Dadurch stimmen neben Farben auch Layout und Typografie mit dem gewählten Design überein.

Die vorhandenen optionalen Dashboard-Referenzzustände wurden ebenfalls neu gerendert. Die [Bildgalerie](SCREENSHOTS.md) benennt ihre Grenzen. Kein Bild stammt aus der persönlichen Haupt-App.

## Performance

20 Wiederholungen im nativen Debug-Prüfaufbau, 5.000 synthetische Buchungen, 120 Workouts und temporäre SQLite. Dashboard veröffentlicht weiterhin genau einen konsistenten State pro Reload. Die festgelegten P95-Grenzen für Dashboard, Finanzen und Statistiken werden eingehalten. Rohwerte: [redesign-performance.json](reports/redesign-performance.json).

Diese Messungen sind keine FPS-, Speicher-, Startzeit- oder Instruments-Abnahme der grafischen Oberfläche.

## Offene Grenzen

`xcodebuild build-for-testing` wurde versucht, erreicht hier aber wegen gesperrter Benutzer-Caches bzw. der nicht startbaren SwiftPM-Manifestsandbox nicht den Projektbuild. Die erfolgreiche SwiftPM-Kompilierung ist dafür kein Ersatz. Der neue `testThreeDesignsAndAssistantScreenshots` ist vorbereitet, aber in dieser Sitzung nicht grafisch ausgeführt. Ältere bestandene grafische Tests aus der vorigen Oberfläche werden nicht als neue Abnahme gezählt.

Das macOS-Bildschirmfoto-Werkzeug ließ sich über die native Oberfläche nicht starten. Deshalb wurden keine vollständigen neuen Fensterbilder gespeichert; die zwölf veröffentlichten Bilder sind ausdrücklich als native View-Renderings gekennzeichnet. Die Demo war dagegen für die manuelle Sichtprüfung zugänglich.

Noch erforderlich: vollständiger aktueller Xcode-/XCTest-UI-Lauf in einer entsperrten Umgebung mit passenden Cache-/Automationrechten, interaktiver kurzer/schmaler Fensterdurchlauf, gesprochene VoiceOver-Prüfung und grafisches Performanceprofiling. Homelab-/iPhone-Betrieb und echte Modellinferenz wurden nicht erneut abgenommen.

## GitHub und lokaler Git-Stand

Ein sicherer Remote-Arbeitsbranch `codex/abolife-three-designs` wurde von dem zuvor geprüften `main`-Stand erstellt. Die Galerie, native Umsetzung, Bereinigung und abschließende Dokumentation werden als getrennte, aussagekräftig beschriebene Commits übertragen. Repository-Sichtbarkeit bleibt privat; kein Release und keine Zugangsdaten werden veröffentlicht.

Lokale `.git`-Metadaten sind in dieser Sitzung schreibgeschützt. Der lokale Branch konnte deshalb nicht gewechselt und die übertragenen Commits konnten nicht lokal eingetragen werden. Die Arbeitsdateien bleiben erhalten; die Remote-Übertragung erfolgt über die autorisierte GitHub-Verbindung. Ein späterer Abgleich sollte diesen lokalen Arbeitsstand zunächst sichern und nicht mit einem Reset verwerfen.
