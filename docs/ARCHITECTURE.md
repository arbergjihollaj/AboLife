# Architektur – AboLife 0.4

## Native Anwendung

SwiftUI/AppKit → ObservableObject-Stores → Repositories → GRDB/SQLite. Fachliche Einträge sind die Primärdaten; Summen und Fortschritte werden berechnet. Historische Migrationen bleiben erhalten. Newspräferenzen und Sync-Metadaten besitzen eigene Tabellen.

Die Haupt-App nutzt die Kennung `com.private.AboLife` und den stabilen Ordner `AboLife-Main`. Beim ersten Start wird eine konsistente, nur lesend geöffnete Kopie der Kalender-Preview übernommen; ohne Preview wird auf den älteren Stand zurückgegriffen. Vorhandene Hauptdaten werden niemals erneut überschrieben. Die isolierte Demo umgeht diese Übernahme vollständig.

## Gemeinsamer Planer

`StudyPlannerEngine` und `ModuleStudyPlanner` berechnen freie Fenster und Vor-/Nacharbeit unter Berücksichtigung von Uni, Fahrtwegen, Pausen, Tageslimits, Wochentagen und Fixierungen. Dieselben drei Foundation-basierten Swift-Dateien werden im Homelab in ein CLI kompiliert. Node tauscht Kalender-JSON über stdin/stdout aus und begrenzt Laufzeit und Ausgabe.

## Gemeinsamer Datenvertrag

`SharedDocument` enthält eine feste Tabellen-Allowlist, einen typisierten Kalender-Workspace und den statischen Trainingsplan. Foundation-Daten verwenden Sekunden seit 2001, Tabellen UTC-SQLite-Zeittexte. `web/schema.json` beschreibt die echten Spalten und Pflichtwerte; Tests vergleichen sie mit der nativen Datenbank. Ernährungsarchive und Zugangsdaten sind nicht Bestandteil der synchronisierten Einträge.

## Synchronisierung

Die Mac-App vergleicht lokalen Fingerabdruck, Serverrevision und den zuletzt bestätigten Ausgangsstand. Unveränderte/einseitige Änderungen werden bestätigt oder übertragen. Eine Drei-Wege-Zusammenführung verbindet unabhängige Datensätze/Felder. Widersprüche, Löschen gegen Bearbeiten, doppelte Tagesdatensätze und ungültige Trainingsbeziehungen bleiben Konflikte. Ein offener Konflikt pausiert den automatischen Abgleich.

Schreibzugriffe tragen eine Revision. Der Server prüft sie in einer SQLite-Transaktion erneut; ein asynchron berechneter Plan darf keinen neueren Stand überschreiben. Vor einem lokalen Import wird der erwartete Fingerabdruck ebenfalls innerhalb der Transaktion geprüft. Explizites Ersetzen erstellt eine lokale Sicherung; der Server hält bis zu 50 frühere Revisionen.

## Web und Offlineeingaben

Node-Standardbibliotheken stellen HTTP, SQLite, Sessionverwaltung und RSS-Abruf bereit. Browser-Schreibzugriffe benötigen denselben Ursprung und einen zusätzlichen Request-Header. Passwortprüfung nutzt Scrypt; Sitzungen verwenden zufällige Tokens und HttpOnly-/SameSite-Cookies mit Secure bei HTTPS. Die Mac-Zugangsdaten liegen im Schlüsselbund, Sitzungstoken im Prozess.

Der Service Worker cached nur Oberflächenassets. Persönliche Snapshots und ausstehende Eingaben liegen lokal im Browser und werden bei Abmeldung entfernt. Eine dauerhafte Anfragekennung verhindert doppelte Ausführung nach unklarem Netzwerkabbruch. Unabhängige neue Einträge können auf die neue Revision übertragen werden; veraltete Änderungen an Tageswerten bleiben zur Prüfung stehen.

## Betrieb und Wiederherstellung

Der Docker-Dienst läuft mit eingeschränkten Rechten und dauerhaftem SQLite-Volume hinter privatem HTTPS. `backup.mjs` verwendet die SQLite-Backup-API statt einer inkonsistenten Kopie der WAL-Hauptdatei. Historie und 30 Dateisicherungen im selben Volume ersetzen keine externe Serversicherung.

Lokale Restore-Daten werden auf einer isolierten Datenbank geprüft. Nach Bestätigung wird der bisherige Stand gesichert und transaktional ersetzt. Alte Sync-Ausgangsstände werden verworfen, damit eine Wiederherstellung keinen neueren Serverstand still überschreibt.

Prüfbare Grenzen und noch offene reale Geräte-/Linux-Abnahmen: [TESTING.md](../TESTING.md).
