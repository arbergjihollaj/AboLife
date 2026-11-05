# AboLife AI · implementierter Integrationsvertrag

BonsaiBar und AboLife bleiben getrennte Anwendungen. AboLife 0.4 erhält einen zusätzlichen lokalen Assistenten; Dashboard, Sidebar, Kalender, Finanzen, Training, Habits, News und Sync behalten ihre bisherigen Funktionen. Ergänzt wurden ein kleiner Dashboard-Button, die globale AI-Toolbar-Aktion und eine Verbindungsoption in Einstellungen.

`AboLife → AboLifeAIConnector → BonsaiBar LocalAPIServer → RequestCoordinator → ModelManager → PrismML-Modell`.

## Verbindung

BonsaiBar API aktivieren, benannten Client erstellen, Verbindungsdatei exportieren. In AboLife **AboLife AI → Mit BonsaiBar verbinden** importieren. Der Connector akzeptiert ausschließlich HTTP zu localhost/127.0.0.1 ohne Benutzerinfo, Query oder fremde Pfade; Redirects und Proxies sind deaktiviert. AboLife speichert die Konfiguration im Schlüsselbund. Abbrechen überträgt die eigene Request-ID; Connection Refused, Auth, Busy, Kontextgrenze, Ausgabelimit und Streamabbruch besitzen verständliche Fehler.

Vertragsquelle: `Sources/BonsaiConnector/BonsaiClient.swift`. AboLife enthält eine identische Datei in `Features/AI`. `Scripts/sync-connector.py --check` prüft diese Übereinstimmung. Keine zusätzliche GRDB-/BonsaiCore-Abhängigkeit wird in AboLife eingebaut.

## Kontext und Datenschutz

Freigaben starten leer. Die Auswahl gilt pro Bereich und Anfrage; ein Finanzzweck kann auch bei früher erteilter Lernfreigabe keine Lerndaten übertragen. Die Vorschau zeigt die tatsächlich gesendeten Fakten. Bei einem Bereichswechsel oder Entzug benötigter Freigaben wird vor der nächsten Anfrage ein neuer Chat begonnen; alte Antworttexte werden nicht mit eingeschränkter Berechtigung erneut zum Modell geschickt.

Für „Was steht heute an?“ wähle **Mein Tag** und aktiviere **Kalender · Termine, Lernblöcke und Fahrten**. Die Vorschau zeigt das heutige Datum in der Zeitzone des AboLife-Kalenders und bis zu 16 Einträge ab heute, chronologisch sortiert. Details zu Lernthemen haben eine eigene Freigabe. Ohne Kalenderfreigabe erhält der Assistent einen Hinweis auf den fehlenden Zugriff.

| Zweck | Möglicher Kontext nach ausdrücklicher Freigabe |
|---|---|
| Tag | Relevante Termine, Lernaufgaben, Training und Habits |
| Finanzen | Deterministisch berechnete Budget-/Ausgabensummen und Kategorien; keine Einzelbuchungstitel |
| Lernen | Vorhandene Themen/IDs und Sitzungen; zukünftige freie Fenster nur mit zusätzlicher Kalenderfreigabe |
| Training/Habits | Tatsächliche siebentägige Einträge/Aggregate, keine erfundenen Gesundheitswerte |
| Wochenreview | Gewählte Wochenbereiche und gesondert freigegebene Review-Notizen |
| News | Bereits geladene RSS-Schlagzeilen mit Quelle/URL; kein behaupteter Volltextabruf |

Vorhandene Fachfunktionen rechnen Budget, Ausgaben und Lernverfügbarkeit. Das Modell interpretiert diese Daten und darf Vorschläge liefern. Freie Texte sind unzuverlässige Daten, keine Befehle. Fehlende Fakten müssen als fehlend erkennbar bleiben. KI-Antworten bleiben überprüfungsbedürftig.

Normaler AboLife-Assistent: Thinking standardmäßig aus, zuschaltbar. Strukturierte Aktionen: Thinking aus und passendes Nonthinking-Sampling, um das begrenzte Ausgabebudget für den Vorschlag zu verwenden.

## Bestätigte Aktionen

Erlaubt: `createStudyTask`, `createStudyBlock`, `saveWeeklyReview`, `saveBudgetAnalysis`. Das Backend begrenzt per JSON-Schema die erlaubten Felder; der Connector führt nichts aus. AboLife dekodiert nur diese typisierten Aktionen, verwirft unbekannte Felder/Arten und prüft Werte, Berechtigungen und bekannte IDs.

1. Modell erzeugt einen unbestätigten Vorschlag.
2. **Aktionsvorschlag prüfen** erzeugt eine konkrete Vorschau.
3. Nutzer übernimmt oder lehnt ab.
4. Beim Übernehmen prüft eine GRDB-Transaktion Berechtigung, Fingerprint, Termine/Fahrtregeln, freie Lernfenster, Tageslimit und vorhandene Action-Receipt erneut.
5. Erst danach wird geschrieben und dieselbe Aktion gegen Wiederholung gesperrt.

Lernblöcke werden fixiert gespeichert. Wochenreviews werden ergänzt; vorhandene Notizen bleiben erhalten. Budgetanalysen erscheinen als lokale gespeicherte Analysen. Es gibt keine Shell-/SQL-Ausführung aus Modelltext und keine automatische Datenänderung.

## Daten und Kompatibilität

Vorhandene AboLife-Arbeitsstände wurden vor Änderungen als Codearchiv und Patch gesichert. Additive Migration `v14_local_ai_actions` ergänzt nur `ai_action_receipts` und `ai_saved_notes`. Vor dem ersten Main-Upgrade entsteht eine konsistente Sicherung unter `AboLife-Main/Backups/AboLife-before-local-AI.sqlite`. Die beiden neuen Tabellen gehören nicht zur Web-Sync-Allowlist.

KI-Historie: `Application Support/AboLife-AI/Conversations.json`, Modus 0600 in Ordner 0700; während Streams höchstens alle zwei Sekunden gespeichert. Unlesbare Historien werden nicht überschrieben. Die Demo hat einen getrennten Ordner und temporäre Fachdaten. Verbindungsschlüssel werden weder in Chats noch Logs gespeichert.

AboLife bleibt ohne BonsaiBar vollständig nutzbar. Mobile/Homelab-Inferenz und Remotezugriff sind nicht aktiviert; Daten-Sync und lokale Inferenz bleiben getrennt.
