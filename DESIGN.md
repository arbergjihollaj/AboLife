# AboLife – natives Designsystem

AboLife bleibt eine ruhige persönliche Mac-App. Die vorhandene Dashboard-Hierarchie ist die gestalterische Basis: Tagesstand mit Daily-Core-Ring, offene Punkte, Training/Budget, danach Gewohnheiten, letzte Aktivitäten und Woche. Keine neue Dashboard-Metapher und keine wieder eingeführten Ernährungs-/Telegrambereiche.

## Flächen und Farbe

`AboLifeColors` besitzt die semantischen Farben. Dunkel verwendet matte Graphitstufen, Hell neutrale sehr helle Flächen mit weißen Karten. Primär-/Sekundärtext und Konturen passen sich an; Kategorien behalten zurückhaltende funktionale Akzente. Blau markiert Aktionen und Auswahl, Türkis Finanzen, Orange Gewohnheiten, Violett Training. Zeichen, Beschriftung und Werte ergänzen Farbe; Farbe allein trägt keine Aussage.

Keine Blur-/Glow-Schichten oder dekorative Schattenketten. `AboLifeCard` liefert Padding, Kontur und kontinuierliche Rundung; bei erhöhtem Systemkontrast wird die Kontur deutlicher. Der historische Typname GlassCapsule bleibt aus Kompatibilitätsgründen, die Darstellung ist eine matte Statusfläche.

## Tokens

| Gruppe | Quelle | Werte / Rolle |
|---|---|---|
| Abstände | AboLifeSpacing | 8 / 12 / 16 / 24 / 32 pt; Seite 24, Karte 16, prominente Karte 24 |
| Radien | AboLifeRadius | Control 8, Karte 12, prominent 16 pt |
| Typografie | AboLifeTypography | SF-Systemschrift, bewusst vorhandene Rollen; Titel 32, Kennzahl 28, Body 14, Caption 12 pt; Monospaced Digits nur für Werte |
| Flächen | AboLifeColors | page/sidebar/card/elevated sowie quietFill/subtleFill; keine eigenen Flächenfarben pro Seite |
| Motion | AboLifeMotion | Interaktion 120 ms, Navigation 180 ms, Metrik 350 ms, jeweils wertgebunden; bei Reduce Motion keine Animation |

Neue oder substanziell umgebaute Komponenten verwenden Tokens. Ältere lokale Layoutwerte werden bei gezielter Überarbeitung übernommen; kein riskanter globaler Austausch gleich aussehender Zahlen mit unterschiedlicher Bedeutung.

## Hierarchie und Interaktion

Eine Karte besitzt eine Hauptaussage. Der Finanzüberblick zeigt Restbudget; Tagesverfügbarkeit und Fixkosten sind sekundär und klar beschriftet. Kategorieplanung liegt hinter Disclosure, Monats-/Wochenwechsel ist direkt erreichbar. Eine spätere KI ergänzt belegte Erkenntnisse unter den Primärdaten, keine parallelen fiktiven Kennzahlen.

Native Formulare/Buttons behalten Tastaturverhalten. Dock und Sidebar besitzen eigenes dezentes Hover-/Druckfeedback. Ringe, Balken und numerische Werte animieren Änderungen; Sparklines verwenden Swift Charts. Kein dauerhaft laufender Effekt. Dashboard-Einblendung ist kurz und entfällt bei Reduce Motion.

## Zustände, Fenster und Accessibility

Detailinhalte unterstützen mindestens 660 pt Breite und 460 pt Höhe zusätzlich zur Sidebar. Karten umbrechen; Formulare scrollen, Kopf und Aktionen bleiben erreichbar. Schnellerfassung hat adaptive Maße statt eines starren 560×600-Rechtecks. Trainingseingaben bleiben bei Fehlern offen. Einstellungen erlauben System/Hell/Dunkel, ohne Datenmigration.

Symbole haben Textlabels, dekorative Bilder sind ausgeblendet, Auswahl wird als ausgewählt vorgelesen. Fehler nennen eine Handlung, Erfolg erscheint erst nach erfolgreichem Speichern. Finanzbuchungen behalten Centbeträge und unterscheidbare Vorzeichen für Einnahmen/Ausgaben. Fehlende Daten und unbekannte RSS-Daten bleiben erkennbar.

Die automatisierten Referenzen rendern die tatsächliche Dashboard-Kartenkomposition in Hell/Dunkel, 760/1100 pt und verschiedenen Datenzuständen. ImageRenderer erfasst keine native Fenster-/Formular- oder VoiceOver-Abnahme. Live-Prüfung und Animationen müssen auf einem entsperrten Mac geprüft werden; Details im Abschlussbericht.

## Freigegebene Designs: Spatial, Bento und Fieldnotes

Seit der ausdrücklichen Freigabe vom 6. November 2026 ersetzt die lokale Designauswahl die frühere einzelne Dashboard-Komposition. `AboLifeDesignStore` und `AboLifeStyle` koordinieren die Darstellung über alle Szenen, ohne Fachstores neu anzulegen. `AboLifePalette` liefert adaptive Oberflächen und lesbare Akzente. Hell/Dunkel/System bleibt eine unabhängige Wahl; die Systemeinstellung wird standardmäßig respektiert.

- Spatial: räumlicher Daily-Core-Mittelpunkt, dezent transparente Panels, Navigation unten.
- Bento: kompakte Seitenleiste, großzügig gerundete Module und Widgeteditor in Einstellungen. Drag-and-drop wird durch beschriftete Auf-/Ab-Aktionen ergänzt.
- Fieldnotes: Papierfarben bzw. dunkle Journalflächen, Serifenschrift, Navigation oben, weniger gleichzeitig sichtbare Tagesdetails.

Die bestehenden Motiontokens bleiben 120/180/350 ms mit Reduce-Motion-Unterstützung. Alle Designs öffnen denselben vorhandenen KI-Assistenten über einen beschrifteten Headerbutton. Verbindung, Kontextfreigaben, Streaming, Abbruch, Chatverlauf und Aktionsbestätigung werden nicht durch eine zweite KI-Implementierung ersetzt.

Die lokale [Bildgalerie](docs/SCREENSHOTS.md) zeigt zwölf native Dashboard-Referenzen. Für die tatsächliche Fensterbedienung gelten die im [Redesign-Bericht](docs/REDESIGN_REPORT.md) benannten Prüfgrenzen.

## Wortbildmarke a.

Die freigegebene Wortbildmarke ist das kleingeschriebene `a.` aus dem Design Lab. Das feste macOS-/Web-Icon übernimmt den mintgrünen Kreis aus Spatial auf einer dunklen, abgerundeten Iconfläche. In der Oberfläche zeichnet `AboLifeBrandMark` dieselben Zeichen direkt: Kreis bei Spatial, gerundete Fläche bei Bento und Serifenschrift bei Fieldnotes. Die Menüleiste verwendet eine systemtypisch lesbare monochrome Textmarke.

`scripts/render-brand-assets.swift` erzeugt alle zehn macOS-Iconauflösungen, die drei AppMark-Skalierungen, das Web-Icon und das Dokumentationsbild mit der vorhandenen macOS-Systemschrift. Quelle ist die Typografie des Prototyps, keine neue Illustration. Reproduzieren im Projektverzeichnis:

```sh
swiftc -module-cache-path work/cache scripts/render-brand-assets.swift -o work/render-brand-assets
work/render-brand-assets
```
