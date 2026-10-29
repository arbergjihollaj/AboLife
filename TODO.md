# AboLife – Aufgabenstatus 0.4

## Erledigt

- [x] 0.4 zur Haupt-App mit stabiler Kennung machen; Preview-/Legacy-Daten einmalig und ohne Überschreiben übernehmen.
- [x] Isolierten Demomodus, aktuelle Projektbeschreibung und CI-Konfiguration für das Portfolio ergänzen.

- [x] Ursprünglichen detaillierten Dashboard-Aufbau aus der gesicherten Version nach Nutzerwunsch wiederherstellen; Ernährung bleibt entfernt.

- [x] Bestehende Mac-Oberfläche und aktuellen Quellstand prüfen; Produktbewertung in `docs/PRODUCT_REVIEW_0_4.md` festhalten.
- [x] Lernplanung übernehmen; Ernährung und Telegram entfernen; App-Icon und News ergänzen (0.3).
- [x] Quick-Add-Ausgabenformular mit Menü, fester Größe und Scrollbereich korrigieren (0.3).
- [x] Fehlenden Anmeldeheader der Mac-App korrigieren und Serversitzung zwischen Abgleichen wiederverwenden.
- [x] Unabhängige Datensätze/Felder anhand eines gemeinsamen Ausgangsstands automatisch zusammenführen. Echte Konflikte, doppelte Tagesdatensätze und ungültige Beziehungen schützen.
- [x] Automatischen Abgleich bei offenem Konflikt anhalten; Verbindungsstatus und Einstellungszugriff in der Sidebar ergänzen.
- [x] Dashboard regelmäßig aktualisieren und Habit-Texte korrigieren. Vorherige volle Dashboardbreite und Sidebar nach Nutzerwunsch wiederhergestellt.
- [x] Heutige Ausgaben vollständig vom heutigen Budget abziehen, konsistent in Dashboard, Menüleiste, Finanzen und Web.
- [x] Mobile Funktionen und Abmelden ergänzen; die ursprüngliche Navigation oben nach Nutzerwunsch beibehalten.
- [x] Übernachttermine und ausgeblendete Vorkommen im Webkalender korrekt anzeigen.
- [x] Lernbewertungen und Wochenreviews mobil erfassen.
- [x] Mac-Trainingsplan mit Varianten mobil teilen; ausgewählte absolvierte Übungen und vorgeschriebene Sätze speichern; Übungs-/Satzhistorie anzeigen.
- [x] Weboberfläche für Monatsbudget, Fixkosten, Kategoriebudgets und neue Sparziele ergänzen.
- [x] Offlineoberfläche, letzten lokalen Stand und dauerhafte Eingabewarteschlange ergänzen. Wiederholte Übertragung durch Anfragekennungen absichern; Konflikte prüfbar machen.
- [x] Lokale persönliche Browserdaten beim Abmelden entfernen; ausstehende Serverabmeldung nach Verbindungsrückkehr nachholen.
- [x] Denselben Swift-Lernplaner für Homelab kompilierbar machen; Planung nach Kalenderänderungen, manuell und alle 15 Minuten ausführen.
- [x] Homelab-Compose mit Node, schlanker Swift-Laufzeit, persistentem Volume, Gesundheitscheck und eingeschränkten Containerrechten vorbereiten.
- [x] Private Einrichtung über Tailscale Serve auf eigenem HTTPS-Port 8443 skripten; vorhandene Passwörter erhalten, neue zufällig erzeugen.
- [x] Konsistente Online-SQLite-Sicherungen mit 30 Dateiständen und täglichem Intervall ergänzen.
- [x] Lokale JSON-/SQLite-Wiederherstellung und neue CSV-Backup-Ordner mit vollständigem Begleitstand implementieren; Vorprüfung, Bestätigung, Sicherung und Transaktion vorsehen.
- [x] Native Tests, Web-/Clienttests und Swift↔Web-Vertrag einschließlich mobilem Workout prüfen; siehe `TESTING.md`.

## Durch die Umgebung blockiert – noch nicht erledigt

- [ ] Paket auf das Homelab übertragen und dort den Linux-Docker-Build samt dauerhaftem Volume prüfen. SSH zu `192.168.178.21` ist hier gesperrt; lokaler Docker-Daemon fehlt.
- [ ] Auf dem Homelab Tailscale anmelden, private HTTPS-Adresse einrichten und Mac/iPhone verbinden. Die Adresse darf erst nach erfolgreicher Einrichtung als nutzbar gelten.
- [ ] Tatsächlichen Mac↔Server↔Handy-Abgleich, Sitzungsablauf und Konfliktauflösung über das Netzwerk prüfen.
- [ ] Mobile Safari-/iPad-Ansicht und Service Worker einschließlich Flugmodus/Rückkehr in echter Browserumgebung prüfen. Lokale TCP-Listener sind gesperrt; die Browserrichtlinie erlaubt keine lokalen Dateivorschauen.
- [ ] Alle RSS-Quellen im bereitgestellten Webserver live abrufen. Parser, Cache und Fehlerfälle sind getestet; früherer nativer Liveabruf ersetzt diesen Test nicht.
- [ ] Regulären Xcode-Projektbuild außerhalb der eingeschränkten Paket-/Cache-Umgebung prüfen. Die native Alternative kompiliert und testet denselben Swift-Quellstand.

## Bewusste Produktgrenzen

- Satzvorgaben lassen sich mobil als absolviert speichern; individuelle Satzwerte und detaillierte Lernblockverschiebungen bearbeitet man am Mac.
- Ältere CSV-Exporte ohne vollständigen Begleitstand sind nicht verlustfrei restaurierbar. Dafür das damalige JSON-/SQLite-Backup verwenden.
- Das tägliche Serverbackup startet sein Zeitintervall nach einem Neustart neu; externe Sicherung des Volumes bleibt Aufgabe des vorhandenen Homelab-Backupplans.
- Mailseite, native iPhone-App, Apple Health und KI-Auswertung bleiben zurückgestellt.
