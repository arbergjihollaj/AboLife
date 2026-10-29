# Produktbewertung und Umsetzung 0.4

Bewertungsgrundlage: aktueller Swift-/Web-Quellstand, vorhandene TODOs, laufende Mac-App mit Dashboard und Kalender sowie automatisierte Prüfungen. Die neue mobile Gestaltung konnte mangels erlaubter Browser-/Netzwerkumgebung nicht visuell abgenommen werden.

## Urteil

AboLife besitzt einen überzeugenden persönlichen Kern: Kalender/Lernen, Budget und kleine tägliche Einträge ergänzen sich sinnvoll. Die dunklen Flächen, zurückhaltenden Farben und wiederkehrenden Karten wirken konsistent. Ein vollständiger visueller Neustart hätte wenig Nutzen. Die größeren Lücken lagen bei verlässlichem geräteübergreifendem Verhalten, mobilen Eingaben und Wiederherstellung.

## Befunde und Konsequenzen

| Befund | Umsetzung |
|---|---|
| Mac-Anmeldung wird vom eigenen CSRF-Schutz abgewiesen | Erforderlicher Header ergänzt; Token wiederverwendet und bei abgelaufener Sitzung erneuert |
| Dokumentkonflikte verlangen schnell das Ersetzen eines gesamten Gerätestands | Drei-Wege-Zusammenführung unabhängiger Datensätze/Felder mit Schutz echter Widersprüche und Beziehungen |
| Neuer mobiler Termin kann alte Lernvorschläge ungültig machen | Derselbe Swift-Planer läuft zusätzlich auf dem Homelab; keine zweite Implementierung der Terminregeln |
| Tagesbudget reagiert auf eine Ausgabe nur mit einem Bruchteil des Betrags | Tagesanteil aus dem Stand vor heutigen Ausgaben berechnen, heutige Ausgaben vollständig abziehen |
| Große Fenster strecken das Dashboard unnötig | Inhaltsbreite begrenzt; Karten bleiben adaptiv |
| Verbindung kaum sichtbar; Einstellungen wenig auffindbar | Sidebarstatus und direkter Einstellungszugriff; letzte Synchronisierung und Weblink in Einstellungen |
| Aufzählung nennt zwei offene Gewohnheiten, obwohl weitere fehlen | Vollständiger Text |
| Mobile Navigation scrollt oben aus dem Blick, Abmelden ist verborgen | Leiste am unteren Rand, Safe Areas und mobile Abmeldung |
| Kleine Bedienflächen und iOS-Formularzoom | Größere Schaltflächen, 16-Pixel-Eingaben, scrollbare Dialoge |
| Webeingaben gehen ohne Verbindung verloren | Lokale Warteschlange mit expliziter Übertragung, Konfliktprüfung und dauerhafter Duplikatvermeidung |
| Trainingsplan und Wochenreview fehlen unterwegs | Varianten, Übungswahl, Satzhistorie und Wochenreview ergänzt |
| Backup ist exportierbar, aber nicht wiederherstellbar | Vorprüfung auf isolierter Datenbank, Bestätigung, automatische Sicherung und transaktionaler Restore |
| Homelab-Einrichtung ist eine lose Anleitung | Ausführbares Einrichtungsskript und Paket; private HTTPS-Adresse, Healthcheck und Onlinebackups |

## Grenzen der Bewertung

„Perfekt“ ist kein nachprüfbarer Abschlusszustand. Die technischen Tests decken die geänderten Abläufe ab; echte Safari-Darstellung, Offline-Lebenszyklen, Linux-Container und Heimnetzverbindung brauchen die in der TODO-Liste benannte Abnahme. Die hier verfügbaren Werkzeuge können diesen Server nicht erreichen. Kein Deployment und keine Handyverbindung werden als erledigt ausgegeben.

Die mobile Workout-Erfassung verwendet offen ausgewiesene Planvorgaben. Sie behauptet keine tatsächlich gemessenen Wiederholungen oder Gewichte. Für diese Details bleibt die native Bearbeitung verfügbar.

## Gestaltungsentscheidung des Nutzers

Die vorherige Optik wird bevorzugt. Deshalb sind die volle Dashboardbreite, die schlichte Sidebar und die mobile Navigation oben wiederhergestellt. Die funktionalen Verbesserungen bleiben bestehen; diese Präferenz hat Vorrang vor den ursprünglichen Gestaltungsempfehlungen dieser Bewertung.
