# AboLife TODO

## Status
AboLife ist eine lokale macOS-App mit Dashboard, Quick Add, Ernährung, Training, Finanzen, Gewohnheiten, Wochenreview, Einstellungen, Backup/Export, Gewichtstracking und Statistik-Übersicht.

Phase 9A ist abgeschlossen: Gewicht & Statistiken laufen lokal mit Tests.
Phase 9C ist abgeschlossen: Ernährung hat lokale Favoriten und Mahlzeiten-Vorlagen, die als echte Mahlzeiten eingetragen werden können.
Phase 9B ist abgeschlossen: External Input / Quick Input ist als lokale, testbare Architektur umgesetzt.
Phase 10A ist vorbereitet: Telegram-Grundstruktur mit Buttons und Dialog-Mapping ist integriert, echter Bot-Token und Live-Test bleiben offen.
Phase 10B ist als Live-Code umgesetzt: Telegram Long Polling kann kontrolliert gestartet/gestoppt werden, optionaler Auto-Start ist sicher konfigurierbar, echter Bot-Test mit lokalem Token ist noch manuell offen.
Phase 10C ist umgesetzt: Telegram Daily Summary, Reminder-Scheduler, Reminder-Buttons, konfigurierbare Reminder-Zeiten und Telegram HTML Snapshot Export sind als entkoppelte Services integriert.
Telegram Barcode Food Scan ist umgesetzt: Barcode-Fotos werden temporär verarbeitet, über Open Food Facts nachgeschlagen und erst nach Mengenwahl plus Bestätigung als Mahlzeit gespeichert.
Die gemeinsame Tageslogik ist als kleine `TodaySnapshotService`-Schicht vorbereitet und wird von Dashboard und Telegram Daily Summary genutzt.
Restore/Import ist als sichere Vorprüfung für JSON, SQLite und CSV vorbereitet; ein schreibender Restore-Flow bleibt bewusst offen.

## Erledigt
- [x] Phase 0: Konzept und Spezifikation
- [x] Phase 1: UI-Prototyp mit Mock-Daten
- [x] Phase 2 / 3A: Lokale Persistenz mit SQLite/GRDB
- [x] Phase 3B: Quick Add schreibt erste echte Einträge
- [x] Phase 4A: Ernährung-Detailseite
- [x] Phase 4B: Training-Detailseite
- [x] Phase 4C: Finanzen-Detailseite
- [x] Phase 4D: Gewohnheiten-Detailseite
- [x] Phase 4E: Wochenreview-Detailseite
- [x] Phase 5: Einstellungen und zentrale Zielwerte
- [x] Phase 6: Backup/Export-Grundlage
- [x] Phase 7: Quick Add und Home-Workout-Ausbau
- [x] Phase 8: Verbesserte Wochenreviews und Trends
- [x] Phase 9A: Gewicht & Statistiken
- [x] Phase 9B: External Input / Quick Input Architektur
- [x] Phase 9C: Ernährung Favoriten & Meal Templates
- [x] Phase 10A: Telegram Bot Grundstruktur mit Buttons vorbereitet
- [x] Phase 10B: echter Telegram Live-Betrieb mit lokalem Token vorbereitet
- [x] Phase 10C: Telegram Daily Summary & Reminder Scheduler
- [x] Phase 10C: Telegram HTML Snapshot Export
- [x] Telegram Barcode Food Scan über Open Food Facts

## Aktuell
- [x] Nutzungsphase: Quick Input lokal gegen echte Alltagseingaben technisch testen und Parser robuster machen
- [ ] Telegram Live-Test mit lokal gesetztem Bot-Token und erlaubter Chat-ID durchführen
- [ ] Telegram Barcode Food Scan mit echtem Barcode-Foto live testen

## Als Nächstes geplant
- [x] Phase 11: bessere Finanz-Eingabe unterwegs

## Phase 9B umgesetzt
- [x] Typisierte `ExternalInputIntent` ohne UI- oder Telegram-Abhängigkeit
- [x] Deterministischer `ExternalInputParser` für Gewicht, Ausgaben, Mahlzeiten, Training, Habits, Start/Hilfe/Abbrechen
- [x] `ExternalInputService` nutzt bestehende Repositories für Gewicht, Finanzen, Ernährung, Vorlagen, Training und Habits
- [x] `ExternalInputResult` ist UI- und Telegram-freundlich mit Messages, Menüs und Actions
- [x] `ExternalInputDialogManager` verwaltet getrennte Session-States und Button/Text-Flows
- [x] Tests für Parser, Service und Dialoge ergänzt

## Phase 10A umgesetzt
- [x] `TelegramBotConfiguration` liest Token aus `ABOLIFE_TELEGRAM_BOT_TOKEN`
- [x] Telegram bleibt ohne Token deaktiviert und blockiert Build/Tests nicht
- [x] Telegram-Modelle, Button-Mapping, Response-Mapping und Fake-Client ergänzt
- [x] Hauptmenü, Gewicht, Ausgabe, Mahlzeit, Vorlage, Training, Habit, Speichern und Abbrechen als stabile Callback-Actions vorbereitet
- [x] Keine Secrets im Code, keine Netzwerkcalls in Unit Tests
- [ ] Echter Telegram-Bot-Token lokal konfigurieren
- [ ] Live-Test mit echtem Bot durchführen
- [x] Kontrolliertes Long Polling oder anderer Start/Stop-Mechanismus in Phase 10B ergänzen

## Phase 10B umgesetzt
- [x] Echter `TelegramLiveClient` für `getUpdates`, `sendMessage` und `answerCallbackQuery`
- [x] Kontrollierter `TelegramPollingController` mit Start/Stop, Offset-Pflege, Fehlerstatus und Backoff
- [x] Telegram-Statuskarte in Einstellungen mit Start/Stop und letzter Update-ID
- [x] Live-Updates werden an `ExternalInputDialogManager` weitergeleitet
- [x] Antworten und Button-Menüs werden als Telegram-Nachrichten gesendet
- [x] Chat-Schutz über `ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID`
- [x] Optionaler Telegram-Auto-Start beim App-Launch, nur wenn Token und erlaubte Chat-ID lokal vorhanden sind
- [x] Schließen des Hauptfensters beendet die App nicht; Telegram läuft bis zum echten App-Quit weiter
- [x] Beim App-Quit wird Telegram-Polling gestoppt
- [x] Tests mit Fake-Client ohne echte Netzwerkcalls
- [ ] Manueller Live-Test mit echtem lokal gesetztem Bot-Token

## Phase 10C umgesetzt
- [x] Daily Morning Summary um 09:00 Uhr
- [x] Medikamenten-Erinnerungen über bestehende Habit-Datenstruktur
- [x] Proteinshake-Erinnerungen über bestehende Habit-Datenstruktur
- [x] Trainings-Erinnerung um 17:00 Uhr, falls kein Training eingetragen wurde
- [x] Abendlicher Tagescheck um 21:00 Uhr für Kalorien, Protein und Training
- [x] Telegram-Buttons für Proteinshake, Medikamente, Training, Mahlzeit, Ausgabe und später erinnern
- [x] Scheduler ist vom Telegram-Polling entkoppelt
- [x] Reminder-Services enthalten die Businesslogik, Telegram routet nur Callbacks
- [x] Versand-Logging im Scheduler ergänzt
- [x] Konfigurierbare Reminder-Zeiten

## Phase 10C — Telegram HTML Snapshot Export
- [x] Telegram-Menüs enthalten den Button `📤 Export`.
- [x] Der Export-Callback wird bestätigt und erzeugt über `HtmlSnapshotExportService` eine temporäre mobile HTML-Datei.
- [x] `TelegramLiveClient` unterstützt `sendDocument(chatId:fileURL:caption:)` über Telegram `sendDocument` mit Multipart/Form-Data.
- [x] Enthalten sind Kopfbereich, Heute, Ernährung, Training, Finanzen, Habits, Gewicht, Wochenstatus und regelbasierte nächste Schritte, soweit lokale Daten vorhanden sind.
- [x] Fehlende Daten werden als ruhige Empty States dargestellt.
- [x] Sicherheitsregeln: nur erlaubte Chat-ID wird verarbeitet, Token und Chat-ID werden nicht exportiert, keine lokalen Pfade im HTML, temporäre Datei wird nach Versand bestmöglich gelöscht.
- [x] Bekannte Grenzen: Snapshot ist ein statischer lokaler Stand ohne Cloud, Server, externe Libraries oder KI-Auswertung; Live-Test mit echtem Bot bleibt manuell.

## Telegram Barcode Food Scan
- [x] Telegram-Fotos werden erkannt und die größte Foto-Variante wird per `getFile`/Dateidownload geladen.
- [x] Barcode-Erkennung ist als eigener `BarcodeScannerService` über Apple Vision gekapselt.
- [x] Produktdaten kommen über `FoodProductLookupService` von Open Food Facts, ohne Mock-Daten im Runtime-Pfad.
- [x] `FoodQuantityParser` extrahiert eindeutige Grammangaben wie `55g`, `1 x 55g` und `4 x 100 g`; Milliliter werden nicht automatisch als Gramm behandelt.
- [x] `ExternalInputDialogManager` führt Produktvorschau, Mengenwahl, manuelle Gramm-Eingabe, finale Bestätigung und Abbruch.
- [x] Mahlzeiten werden erst nach `Speichern` über die bestehende Ernährungslogik persistiert.
- [x] Bei fehlendem Barcode, fehlendem Produkt oder fehlenden Kalorien/Proteinwerten wird verständlich abgebrochen statt Werte zu erfinden.
- [x] Temporäre Barcode-Bilder werden nach Verarbeitung bestmöglich gelöscht.
- [x] Tests decken Parser, Open-Food-Facts-Parsing, fehlende Daten, Foto-Flow, manuelle Menge, Abbruch und Save-after-confirm ab.

## Telegram-Konfiguration
- Lokaler Token per Environment setzen: `ABOLIFE_TELEGRAM_BOT_TOKEN=<token>`
- Erlaubten Telegram-Chat lokal setzen: `ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID=<chat-id>`
- Ohne erlaubte Chat-ID werden eingehende Chats nicht verarbeitet. Das ist bewusst streng, damit der private Bot nicht versehentlich von anderen Chats genutzt wird.
- Der Auto-Start-Schalter speichert nur die lokale Präferenz und startet Telegram beim App-Launch nur, wenn Token und erlaubte Chat-ID vorhanden sind.
- Keine echten Tokens in Repository-Dateien schreiben.
- Lokale Secret-Dateien wie `.env`, `.env.*`, `.abolife-telegram.env` und `telegram.local.json` sind in `.gitignore` ausgeschlossen.
- Backups enthalten aktuell keine Telegram-Konfiguration, weil der Token nicht in der App-Datenbank gespeichert wird.
- Barcode-Scan benötigt Internetzugang für Open Food Facts. Produkte oder Nährwerte können dort fehlen, und das Foto muss lesbar sein.
- Barcode-Fotos werden nur temporär lokal verarbeitet und danach bestmöglich gelöscht; der Telegram-Token wird nicht gespeichert, geloggt oder exportiert.
- Manueller Live-Test:
  1. Token und erlaubte Chat-ID nur lokal setzen, zum Beispiel über eine nicht versionierte Shell-Umgebung.
  2. App starten und in Einstellungen prüfen, ob Telegram als verfügbar angezeigt wird.
  3. Telegram starten, `/start` an den Bot senden und prüfen, ob nur die erlaubte Chat-ID Antworten erhält.
  4. Alltagseingaben testen: `Gewicht 82,4`, `Ausgabe Döner 4,50€`, `Essen Skyr 250kcal 25g Protein`.
  5. Für Barcode ein scharfes Foto eines echten EAN-Barcodes senden, Produktvorschau prüfen, Gramm bestätigen und erst danach speichern.
  6. Nach dem Test prüfen, dass Token/Chat-ID nicht in Git-Diff, Exporten, Logs oder Screenshots enthalten sind.

## Offene technische Punkte
- [ ] Manuellen Telegram-Live-Test mit echtem Token und erlaubter Chat-ID durchführen.
- [ ] Barcode-Scan live mit echtem Telegram-Foto prüfen.
- [ ] Optional lokale External-Input-Testfläche im Dashboard oder Dev-Bereich ergänzen, falls nach echter Nutzung weitere Eingaben häufig unklar bleiben.
- [ ] Prüfen, ob Quick Add mittelfristig intern auf `ExternalInputService` aufsetzen soll.
- [x] Import/Restore-Konzept für neue Tabellen prüfen und sichere Vorprüfung ergänzen.
- [ ] Schreibenden Restore-Flow mit Preview, Konflikterkennung und ausdrücklicher Nutzerbestätigung ergänzen.
- [ ] Xcode-User-State-Dateien nicht als fachliche Projektänderung behandeln.
- [ ] Prüfen, ob Favoriten/Vorlagen nach echter Nutzung sortiert, gesucht oder gruppiert werden sollten.

## Architektur / Node-Graph Audit
- [x] Interaktive HTML-Graph-Ansicht erstellen.
- [x] Markdown-Audit-Report erstellen.
- [ ] Zentrale Dateien aus dem Audit beobachten.
- [x] Mögliche `DailyState`-/`TodaySnapshot`-Schicht prüfen.
- [x] Kleine `TodaySnapshotService`-Schicht für Dashboard und Telegram Daily Summary ergänzen.
- [ ] Export, Backup, Menüleistenfenster und Statistiken weiter auf gemeinsame Tageslogik prüfen.

## Telegram Automatisierung
- [x] Daily Morning Summary
- [x] Medikamenten-Erinnerungen
- [x] Proteinshake-Erinnerungen
- [x] Trainings-Erinnerungen
- [x] Abendlicher Tagescheck
- [x] Konfigurierbare Reminder-Zeiten

## Finanzplaner Verbesserungen
- [x] Monatliche Budgetplanung
- [x] Fixkosten-Verwaltung
- [x] Sparziele
- [x] Budget-Prognose bis Monatsende
- [x] Kategorien mit Auswertungen
- [x] Diagramme für Einnahmen und Ausgaben
- [x] Wöchentliche Finanzübersicht
- [x] Telegram-Ausgaben direkt erfassen
- [x] CSV-/Numbers-Export verbessern
- [x] Finanzanalyse im Wochenreview integrieren

## Offene Sicherheits-/Konfigurationspunkte
- [ ] Telegram-Token niemals in Git committen.
- [x] Keine privaten Telegram-Nachrichten unnötig loggen: Scheduler speichert nur Reminder-Art, nicht den kompletten Nachrichtentext.
- [ ] Keine Analytics ergänzen.
- [ ] Keine geheimen lokalen Config-Dateien exportieren.
- [ ] Fehlerberichte ohne sensible Inhalte halten.

## Geplante spätere Verbesserungen
- [x] Phase 9D: optionale Open Food Facts Produktsuche für Telegram Barcode Food Scan
- [ ] Ernährung: optionale Food-Datenbank außerhalb des Telegram-Flows
- [ ] Ernährung: optionale KI-Schätzung
- [x] Ernährung: Barcode/Food-Scan über Telegram implementieren
- [x] Gewicht: Zielgewicht und Zielkorridor
- [x] Statistiken: tiefere Trends
- [x] Finanzen: bessere Kategorien
- [x] Finanzen: bessere Monats- und Trend-Auswertung
- [x] Export/Backup weiter verbessern
- [x] Menüleisten-Quick-Add prüfen
- [ ] iPhone-App langfristig prüfen
