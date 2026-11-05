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

## AboLife AI · getrennte lokale Inferenz

`Features/AI` ergänzt den vorhandenen Aufbau. Foundation-Connector → authentifizierte BonsaiBar-API → gemeinsame Inferenzverwaltung. Die Verbindung liegt im Schlüsselbund. Der AIContextBuilder schneidet explizite Grants mit dem Zweck; Kalender-/Finanz-/Habit-Repositories liefern Primärdaten und deterministische Werte. Abgeleitete Lernfenster benötigen auch Kalenderfreigabe.

JSON-Schema begrenzt die Modellantwort. AIActionExecutor prüft Fach/ID, Zeiten, Fahrt-/Tagesregeln, Grant und Rohdaten-Fingerprint. Preview ist keine Ausführung; bestätigte Transaktion schreibt Fachänderung plus Replay-Receipt atomar. Es gibt keine Datenbank-/Shell-Ausführung aus Modelltext. Unlesbare KI-Historien werden nicht überschrieben.


## UI- und Qualitätsevolution · 5.11.2026

AppSession öffnet die bestehende Datenbank und stellt bei Fehlern eine Recovery-Ansicht bereit. Es gibt keinen beschreibbaren nil-Datenbank-Ersatzpfad in der echten App. Demo/Tests erhalten getrennte UserDefaults und temporäre Historie, damit eine bestehende Auto-Sync-Konfiguration nicht auf Fixture-Daten angewandt wird. Das bestehende KI-Modul bleibt fachlich unverändert.

DesignSystem bündelt adaptive Farben, Spacing/Radius, Motion und gemeinsame Status-/Zeitraumcontrols. Die vorhandenen ObservableObject-Stores bleiben angemessen; keine pauschale Observation-/Swift-6-Migration. Der Review-Store lebt oberhalb der Sidebar-Ziele, damit ungespeicherte Eingaben beim Navigieren erhalten bleiben. Zeitraumwechsel und Reload prüfen Änderungen.

NewsModels, NewsFeedParser, NewsFeedLoader, NewsStore, NewsArticleCard und NewsView trennen Verträge, Parsing, Netzwerk, Zustand und Darstellung. Höchstens vier bekannte Quellen laufen in strukturierten Tasks; pro Quelle sind zwei MB begrenzt. Generation und Quellenauswahl verhindern überholte Ergebnisse. Beschädigte Präferenzen werden nicht mit Defaults überschrieben. Kein neuer Cache.

Gewichtsauswertungen verwenden ausdrücklich Kalenderintervalle; die historische Repository-API mit Messungsanzahl bleibt kompatibel. Finanzansichten verwenden vorhandene deterministische Ergebnisse mehrfach statt sie mehrfach zu laden/berechnen. Dashboard-State wird einmal pro Reload veröffentlicht. Neue Analytics-/Review-/News-KI bleibt der [separate Plan](BONSAIBAR_ANALYTICS_PLAN.md), ohne zusätzliche Transport-/Inferenzimplementierung.

## Freigegebene Designauswahl (6. November 2026)

`AppSession` erzeugt einen `AboLifeDesignStore` mit derselben isolierten UserDefaults-Domain wie die übrigen Szenenpräferenzen. Ein beobachtender Szenenmodifier reicht `AboLifeStyle`, die Widgetreihenfolge und den Store an Hauptfenster, Einstellungen und Menüleiste weiter. Gemeinsame Karten und Fach-Views lesen die semantische Palette aus der SwiftUI-Environment. Es gibt keinen globalen Farbzustand und keine zweite Datenbank.

`AppRouter` verwendet `AnyLayout` mit stabil identifizierten Inhalts-/Navigationsslots: Spatial unten, Bento seitlich, Fieldnotes oben. Ein Designwechsel verändert Layout, Farbpalette und Schriftgestaltung, nicht Datenbank, Sync oder AI-Store. Der vorhandene Wochenreview-Store bleibt im Router; Navigation und KI-Sheet verwenden die bestehenden Koordinatoren.

Das Dashboard verwendet dieselben Karten und dieselbe konsistente Snapshotquelle in drei Kompositionen. Bento ordnet die semantisch identifizierten Widgets anhand der gespeicherten Reihenfolge an. Fieldnotes bündelt zusätzliche Details in einer Disclosure. Für Renderprüfungen wird dieselbe Dashboard-View mit einem reinen Übersichtsmodus in die Hierarchie eingebaut; ein vorzeitiger Zugriff auf die `.overview`-Property würde die Environment nicht korrekt übernehmen.
