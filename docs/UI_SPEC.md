# Oberfläche – Hauptversion 0.4

Die Mac-App nutzt matte Graphitflächen, dezente Konturen und Blau als Akzent. Im Dashboard bündelt der Daily-Core-Ring den Tagesfortschritt. Darunter folgen offene Tagespunkte, Training, Budget, Gewohnheiten, Aktivitäten und das Wochenraster. Die Schnellerfassung bleibt beim Scrollen am unteren Fensterrand erreichbar. Die Gestaltung folgt der Methode von [Unslop von Damir Sokolovsky](https://github.com/heydamir/unslop).

Kalender, Training, Gewicht, Finanzen, Gewohnheiten, Statistiken, Wochenreview und Nachrichten verwenden dieselben Seitenränder, Textrollen und Karten. Im Kalender tragen Termine und Lernblöcke die Farbe. Finanzen zeigen das Restbudget und die Auslastung in einer Karte, Gewohnheiten die erreichten Tagesziele. Einstellungen, Schnellerfassung, Menüleiste und Assistent verwenden dieselben matten Flächen und blauen Aktionen.

Die Sidebar führt zu Dashboard, Kalender, Nachrichten, Finanzen, Gewohnheiten, Statistiken und Wochenreview. Training/Gewicht liegen unter Gesundheit. Einstellungen öffnen ausschließlich über das App-Menü oder ⌘,. Die Menüleiste zeigt Tagesstatus, Budgetring und einen ausklappbaren Quick-Actions-Button; das App-Logo öffnet das Hauptfenster.

Quick-Add-Formulare besitzen einen festen Kopf und einen scrollbaren Inhalt. Kategorien verwenden ein Menü. Zustände und Fehler werden sichtbar; ungespeicherte Eingaben bleiben bei einem Revisionskonflikt im Formular erhalten.

Die mobile Oberfläche verwendet die Navigation oben und denselben ruhigen Farbcharakter. Neue Bereiche ergänzen bestehende Abläufe. Offlinestatus, vorgemerkte Eingaben und die ausdrückliche Übertragung bleiben erkennbar.

Screenshots werden nur mit einer getrennten, fiktiven Demo erstellt. Die Demo verändert keine persönliche Datenbank. Siehe [SCREENSHOTS.md](SCREENSHOTS.md).

## AboLife AI

Kleiner Zugang mit Sprechblasen-Symbol im Dashboard und in der Toolbar; eigener schließbarer Assistentendialog. Bestehende Karten, Sidebar und Dashboardstruktur bleiben erhalten. Links Bereich, Verbindung, explizite Grants und Kontextvorschau; rechts Streaming-Chat, Denkmodus, Abbruch, Kopieren und Aktionsvorschläge. Konkrete Änderungen erscheinen in einem zweiten Dialog mit Ablehnen/Übernehmen. Thinking standardmäßig aus; bei strukturierten Aktionen immer aus.


## Evolution vom 5. November 2026

Die bisherige Karten-/Ringhierarchie bleibt. System/Hell/Dunkel lässt sich in Einstellungen wählen. Gemeinsame Motiontokens animieren Metriken, Fortschritt, Sidebar und kurze Einblendung; Reduce Motion deaktiviert diese. Finanzbalken besitzen eine gemeinsame Skala. Buchungen zeigen Centbeträge, klare Vorzeichen und Filter; Planung/Kategorien liegen hinter Disclosure. Monats- und Reviewwochen sind direkt erreichbar.

Newsfilter umbrechen bei kleineren Fenstern; Quellen, Veröffentlichungsdatum oder dessen Fehlen sowie Lese-/Merkstatus bleiben sichtbar. Schnellerfassung und detailliertes Training behalten Eingaben bei Fehlern, liefern echtes Speicherfeedback und scrollen bei geringerer Höhe. Neue Symbolaktionen und zentrale Headercontrols besitzen lesbare Accessibility-Labels. Das vollständige System ist in [DESIGN.md](../DESIGN.md) beschrieben.
