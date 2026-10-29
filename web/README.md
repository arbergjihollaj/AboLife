# AboLife auf deinem Homelab

AboLife 0.4 verbindet die lokale Mac-App mit einer privaten mobilen Weboberfläche. Der Server ist die gemeinsame Austauschstelle; der Mac bleibt offline nutzbar. SQLite wird **nicht** über ein Netzlaufwerk oder iCloud geteilt.

## Empfohlener Betrieb

Ein Docker-Dienst auf deinem Debian-Homelab speichert die gemeinsamen Daten in einem dauerhaften Volume. Tailscale Serve stellt ihn unter `https://<dein-server>.<dein-tailnet>.ts.net:8443` bereit. Auf Mac und iPhone ist Tailscale mit demselben Konto aktiv. Am Router wird kein Port geöffnet. Eine Anmeldung mit dem AboLife-Serverpasswort schützt die App zusätzlich; Tailnet-Zugriffsregeln gelten weiterhin.

Port 8443 lässt bestehende HTTPS-Dienste auf 443 unberührt. Port 3055 bleibt an `127.0.0.1` gebunden. Serve muss den ursprünglichen Host inklusive `:8443` weitergeben. Tailscale Funnel wird nicht verwendet.

Offizielle Referenz: https://tailscale.com/docs/reference/tailscale-cli/serve

## Einrichten

Voraussetzungen auf dem Server: Docker mit Compose, Python 3 und ein bereits angemeldetes Tailscale. Es muss weder Node noch Swift auf dem Host installiert sein. Beim ersten Serve-Aufruf kann Tailscale eine Freigabe für HTTPS im eigenen Konto verlangen.

Das fertige Paket `AboLife-0.4-Homelab.tar.gz` auf den Server kopieren und entpacken. Dann im entpackten Verzeichnis:

```sh
bash web/setup-homelab.sh
```

Alternativ im vollständigen Projekt denselben Befehl ausführen. **Den gesamten Paketordner behalten**: Der Docker-Build braucht zusätzlich die drei gemeinsamen Swift-Quelldateien in `AboLife/Features/Calendar/`.

Das Skript ermittelt die tatsächliche Tailnet-Adresse, erzeugt ein zufälliges Serverpasswort in `web/.env` mit Dateirechten 600, startet Docker einschließlich Gesundheitsprüfung und richtet die private HTTPS-Weiterleitung ein. Es überschreibt keine vorhandenen Zugangsdaten. Passwort lokal auf dem Server in `.env` nachsehen; nicht in Chats oder Git einfügen. Bei fehlenden Docker-/Tailscale-Rechten meldet das jeweilige Werkzeug den Fehler; das Skript ändert keine Systemberechtigungen.

Auf dem Handy die ausgegebene URL öffnen, anmelden und in Safari **Teilen → Zum Home-Bildschirm** wählen. Auf dem Mac unter **Einstellungen → Mac & Web verbinden** dieselbe URL und das Passwort eintragen und synchronisieren. Das Passwort landet im Schlüsselbund. Danach optional den Abgleich alle 30 Sekunden einschalten. Bei leerem Server wird der Macstand übertragen; bei bereits unterschiedlichen Daten ist eine ausdrückliche Entscheidung nötig.

## Was mobil verfügbar ist

- Heute, Gewohnheiten, Kalender mit Serien und Lernblöcken.
- Lernbewertungen und Neuplanung auf dem Server mit demselben Swift-Code wie am Mac. Neue Termine und Bewertungen lösen sofort eine Planung aus; zusätzlich wird alle 15 Minuten geprüft. Fixierte/laufende Konflikte bleiben sichtbar. Unter Lernen kann man den Plan manuell aktualisieren.
- Ausgaben, Monatsbudget, Fixkosten samt Aktivierung/Pause, monatliche Kategoriebudgets und neue Sparziele. Fixkosten sind Planung und werden nicht automatisch als Ausgabe gebucht.
- Trainingsplan mit Minimum/Normal/Stark. Absolvierte Übungen ausdrücklich auswählen; gespeicherte Sätze entsprechen den **Planvorgaben**. Tatsächliche individuelle Wiederholungen/Gewichte bearbeitet man am Mac. Gespeicherte Übungen und Sätze sind mobil lesbar.
- Gewicht, Wochenreview, RSS-News mit Quellen-/Themenfiltern, Suche, Ausschlusswörtern, Lesestatus und Merkliste.
- JSON-Download des gemeinsamen Stands.

ICS-Import, detailliertes Verschieben von Lernblöcken und individuelle Satzbearbeitung bleiben am Mac. Der Mac benötigt nach einem Serverimport für die meisten Bereiche ein erneutes Öffnen der Ansicht; das Dashboard aktualisiert sich spätestens nach 30 Sekunden.

## Offlineeingaben

Nach dem ersten Onlineaufruf hält der Service Worker die Oberfläche vor. Der letzte Datenstand und wartende Eingaben liegen lokal im Browser dieses Geräts. Erreichbarkeit des Servers, installierte Web-App und „offline bereit“ sind unterschiedliche Zustände: Der erste Seitenaufruf braucht immer eine Verbindung; Browser können gespeicherte Daten entfernen.

Offlineeingaben werden erst nach erfolgreicher lokaler Speicherung als vorgemerkt bestätigt. Über **Jetzt übertragen** werden sie später gesendet. Unabhängige neue Ausgaben, Termine und Trainings lassen sich auf den aktuellen Stand übertragen. Änderungen an Tageswerten/Reviews bleiben bei widersprüchlichen Revisionen stehen; man kann sie nach Prüfung übernehmen oder verwerfen. Mehrfache Offlineänderungen desselben Tageswerts werden blockiert, damit ein alter Bildschirm keine Zählerstände verliert. Bis zur Übertragung zeigen die Übersichten den letzten Serverstand.

Jede Eingabe erhält eine dauerhafte Anfragekennung. Eine erneut gesendete Anfrage erzeugt auch nach Verbindungsabbruch oder Serverneustart keine zweite Buchung. Abmelden löscht lokale persönliche Daten und offene Eingaben nach Rückfrage. Bei fehlender Verbindung wird das Beenden der Serversitzung beim nächsten Verbindungsaufbau nachgeholt. Für gemeinsam benutzte Geräte daher immer online abmelden.

## Synchronisierung und Konflikte

Mac und Server vergleichen Revisionen und den zuletzt gemeinsam bestätigten Stand. Unabhängige Datensätze und verschiedene Felder werden automatisch zusammengeführt. Widersprüchliche Änderungen, Löschen gegen Bearbeiten, doppelte Tagesdatensätze und ungültige Beziehungen werden nicht still überschrieben. Ältere Verbindungen ohne gespeicherten Ausgangsstand erhalten die Zusammenführung erst nach einem erfolgreichen Abgleich.

Bei einem echten Konflikt hält der automatische Mac-Abgleich an. Erst nach Prüfung Mac- oder Serverstand wählen. Eine lokale Sicherung und die Serverhistorie sichern den ersetzten Stand. Der Server hält 50 frühere Revisionen. `GET /api/history` listet sie nach Anmeldung; `POST /api/history/restore` erwartet `{revision,restoreRevision,confirm:true}`. Diese Serverhistorie enthält aktive gemeinsame Daten; lokale Ernährungsarchive und Zugangsdaten werden nie hochgeladen.

## Betrieb und Sicherungen

```sh
cd web
docker compose ps
docker compose logs --tail 100 abolife
tailscale serve status
docker compose exec -T abolife node backup.mjs
```

Der Server erstellt nach jeweils 24 Stunden Laufzeit zusätzlich eine konsistente Online-SQLite-Sicherung und hält die letzten 30 Sicherungsdateien unter `/app/data/backups`. Das Zeitintervall startet nach jedem Neustart neu; bei häufigen Neustarts den obigen Befehl über den vorhandenen Homelab-Backupplan ausführen. Serverhistorie und Sicherungen im selben Volume schützen nicht gegen den Verlust des Servers: Das Volume zusätzlich mit deinem bestehenden Homelab-Backup auf ein anderes Gerät sichern. Bei WAL-Datenbanken niemals allein die Hauptdatei im laufenden Betrieb kopieren.

Docker verwendet einen Benutzer ohne Rootrechte, ein schreibgeschütztes Dateisystem außerhalb des Datenvolumes und minimale Rechte. Die Images enthalten Node 24 und eine schlanke Swift-Laufzeit; der Compiler liegt ausschließlich in der Buildstufe. Der Linux-Imagebuild muss einmal auf dem Zielhost geprüft werden.

## Entwicklung ohne Docker

Node ≥22.13 erforderlich; keine npm-Pakete. `ABOLIFE_PASSWORD` mit mindestens 16 Zeichen setzen und `node web/server.mjs` starten. Ohne `ABOLIFE_PUBLIC_URL` sind ausschließlich localhost-Hostnamen erlaubt. Für HTTPS den exakten Ursprung inklusive Port setzen.

Der einfache `web/Dockerfile` stellt einen Node-Dienst ohne Swift-Planer bereit. Mit `ABOLIFE_PLANNER_BINARY` kann man einen für das Hostsystem kompilierten Planer aktivieren. Der empfohlene Compose-Build erledigt das automatisch. `scripts/check-native.sh` kompiliert ihn lokal aus den gemeinsamen Quellen und prüft den Swift↔Web-Vertrag.

```sh
node --test web/test/*.test.mjs
scripts/check-native.sh
```

Die automatisierten Webtests öffnen keine Netzwerkports. Die Clienttests führen die echte Clientlogik mit einer kleinen DOM-Testumgebung aus; sie prüfen keine Pixel, Safari-Eigenheiten oder Service-Worker-Lebenszyklen. Ein echter iPhone-/HTTPS-/Docker-Test bleibt erforderlich.

## Aktueller Status

Quellcode, lokale native Prüfung und Bereitstellungspaket sind vorbereitet. In der Arbeitsumgebung sind SSH zum Homelab, lokale TCP-Listener und Docker-Ausführung nicht verfügbar. Es wurde **kein Server eingerichtet**, keine URL reserviert und kein echter Geräteabgleich durchgeführt. Auch der Linux-Imagebuild sowie die mobile Browserprüfung sind noch offen.
