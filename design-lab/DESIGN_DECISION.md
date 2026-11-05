# Designentscheidung: drei umschaltbare Erscheinungsbilder

Quelle: ausdrückliche Rückmeldung des Nutzers nach dem Test der Galerie und dessen vorhandenes `DESIGN_FEEDBACK.md`.

B und D gefallen dem Nutzer besonders. Gewünscht sind B, D und E als auswählbare Designs unter Einstellungen. A und C gehören nicht in die Auswahl des personalisierten Konzepts. Die bisherigen Bewertungen werden nicht ersetzt und fehlende Noten nicht ergänzt.

## Konzept F im Lab

- Ausgangsdesign B; Wechsel in Einstellungen zwischen Spatial, Bento und Fieldnotes.
- Es wechselt die gesamte Designsprache einschließlich Navigation, Dashboardlayout und Typografie.
- Aktueller Bereich, Demo-Ausgaben, Habitwerte und Review-Entwürfe bleiben während des Wechsels erhalten.
- Auswahl, Akzentfarbe und Bento-Widgetreihenfolge werden im Browser gespeichert. Das enthält keine persönlichen Fachdatensätze. Lade-/Speicherfehler werden gemeldet.
- Vier Akzentoptionen: Original, Blau, Violett und Bernstein; für den dunklen Spatial-Modus helle Varianten, für helle Designs dunklere Varianten mit passender Buttonschrift.
- B: verständliche Titel Budget, Training, Gewohnheiten, Kalender. Keine Kopfzeile „Personal Space / 2026“.
- D: Widgetpositionen im Einstellungseditor per Drag-and-drop oder beschrifteten Auf-/Ab-Aktionen ändern. Das Dashboard folgt dieser Reihenfolge im fließenden Raster.
- E: reduzierter Überblick mit Tagesstand, Budget, Terminen und kurzen Zugängen zu Training und Review.
- A–E bleiben als ursprüngliche Vergleichsentwürfe erhalten. F ist als sechste Karte in der Galerie und separat bewertbar.

## Grenze

Diese Umsetzung gilt für das separate Design Lab. Sie ist keine Freigabe und keine Umsetzung im SwiftUI-Produktcode. Für das spätere native Produkt sind dieselben Stores und Datenquellen, ein gemeinsamer Darstellungszustand und eine lokale Darstellungseinstellung außerhalb des Datenbankschemas vorgesehen. Ein Wechsel darf dann keine Daten duplizieren, löschen oder neu initialisieren.

Die Browser- und Serverfeedbackspeicher bleiben getrennt; frühere Bewertungen werden beim Laden um einen leeren F-Eintrag ergänzt. Die bestehende Feedbackdatei wurde in diesem Schritt nicht überschrieben.

## Bestehende KI als fester Bestandteil

Der Nutzer hat ausdrücklich klargestellt, dass seine bereits implementierte KI in allen gewählten Designs Platz benötigt. Grundlage für den Entwurf ist die vorhandene `Features/AI/AIAssistantView.swift`, keine neue KI-Fachfunktion.

| Design | Ständiger Zugang | Assistent |
|---|---|---|
| B · Spatial | Beschrifteter Button in der Kopfzeile | Räumlicher Dialog mit getrenntem Kontext- und Gesprächsbereich |
| D · Bento | Eigener Eintrag in der Werkzeugleiste | Derselbe Ablauf in der Bento-Designsprache |
| E · Fieldnotes | Button neben dem Bereichsregister | Ruhiger Dialog mit Journal-Typografie |

Der Zugang bleibt auf jedem Bildschirm verfügbar. Für die Vergleichbarkeit besitzen auch A und C einen Zugang. Konzept F übernimmt die Platzierung des jeweils gewählten Designs. Auf schmalen Ansichten wird die sichtbare Beschriftung zu „AI“ verkürzt; das semantische Label bleibt „AboLife AI öffnen“.

Der Dialog zeigt den aktuellen App-Bereich, explizite Datenfreigaben ohne Standardauswahl, eine Kontextvorschau, Fragefeld und Gesprächsverlauf. Draft und Gespräch bleiben während eines Designwechsels im Arbeitsspeicher erhalten. Der Beispielaktionsvorschlag für den Wochenreview benötigt zuerst die Review-Freigabe, dann eine ausdrückliche Bestätigung; Ablehnen schreibt nichts.

Das Lab simuliert ausschließlich den Ablauf, ruft kein Modell auf und kennzeichnet seine vorbereitete Antwort ausdrücklich als Demonstration. Kein Import von Zugangsdaten, keine Verbindung zu BonsaiBar und keine Speicherung persönlicher Chats. Native Verbindung, Streaming, Abbruch, Historie und reale Aktionsprüfung bleiben bestehende App-Funktionen, die bei einer späteren freigegebenen Umsetzung weiterverwendet werden.


## Produktive Umsetzung freigegeben

Am 6. November 2026 hat der Nutzer die Übernahme in die echte App, Projektbereinigung, GitHub-Meilensteine und die aktualisierte Repository-Präsentation ausdrücklich freigegeben. Die nativen Designs sind unter `AboLife/` implementiert; die Galerie bleibt ein separates Werkzeug. Aktueller Prüfstand und Grenzen: `../docs/REDESIGN_REPORT.md`.
