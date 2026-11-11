CE PROZESSAUDIT · Öffentliche GitHub-Pages-Dateien (Version 0.4)

Diesen PUBLIC_GITHUB_PAGES-Ordner hochladen: index.html, style.css, app.js, fragen.json, sw.js, manifest.webmanifest, icon-192.png, icon-512.png.
ACHTUNG: NIEMALS Dateien aus PRIVAT_NICHT_HOCHLADEN hochladen. Auch nicht in ein privates Repository: Git-Verlauf und Veröffentlichungen können Daten später offenlegen.

GitHub-Weboberfläche:
1. Repository anlegen, z. B. ce-prozessaudit.
2. Dateien aus PUBLIC_GITHUB_PAGES direkt im Stammverzeichnis des Repository hochladen (Add file > Upload files).
3. Settings > Pages > Build and deployment > Deploy from a branch > main / (root) > Save.
4. GitHub zeigt eine HTTPS-Adresse https://BENUTZER.github.io/ce-prozessaudit/ an.
5. Diese Adresse auf dem iPhone in Safari öffnen und die Anzeige 'Offline bereit' abwarten.
6. Safari > Teilen > Zum Home-Bildschirm hinzufügen.
7. Private JSON-Datei getrennt über einen intern freigegebenen Weg auf das iPhone übertragen, dort in der App importieren.
8. Im Flugmodus App erneut starten und Fragen/Import/Export prüfen.

Es werden keine vertraulichen Stationsdaten in öffentlichen Code geladen. Alle privaten Inhalte gelangen ausschließlich über den lokalen Dateiauswahldialog in die App und werden in IndexedDB gespeichert. Keine Webanalyse, kein CDN, keine externen Bibliotheken. Browser und GitHub können gewöhnliche technische Zugriffsmetadaten verarbeiten.

HINWEIS: Auditergebnisse regelmäßig als JSON exportieren; iOS kann lokalen Speicher löschen. Auch die lokale Ablage von Krankenhausunterlagen auf dem iPhone muss organisatorisch zulässig sein. Standorte/Zeiten anhand aktueller freigegebener Stationsunterlagen überprüfen.
