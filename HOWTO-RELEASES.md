# HowTo: Neo-Plugins über GitHub veröffentlichen und in WordPress aktualisieren

Dieses Dokument beschreibt den vollständigen Veröffentlichungsweg für die Neo-Plugins. Er gilt derzeit für:

- `neo-plugin-manager`
- `neo-dashboard`
- `neo-calendar`
- `neo-surveys`
- `neo-surveys-extern`

Die GitHub-Repositories liegen unter [`neo-consult`](https://github.com/neo-consult). Der zentrale Katalog ist [`neo-plugin-catalog`](https://github.com/neo-consult/neo-plugin-catalog).

## Zielbild

Ein Release beginnt mit einem Git-Tag wie `v1.2.3`. GitHub Actions führt dann automatisch Folgendes aus:

1. Die Versionsnummer im WordPress-Plugin-Header wird gegen den Git-Tag geprüft.
2. Ein installierbares ZIP mit genau einem Plugin-Ordner wird erzeugt.
3. Für das ZIP wird eine SHA-256-Prüfsumme ermittelt.
4. GitHub veröffentlicht einen Release samt ZIP-Datei.
5. Der zentrale Katalog erhält automatisch Version, Download-Adresse und Prüfsumme.
6. Der **Neo Plugin Manager** erkennt die neue Version in WordPress als Update.

## Voraussetzungen

Für einen Release werden benötigt:

- Schreibzugriff auf das betreffende GitHub-Repository;
- Schreibzugriff auf `neo-consult/neo-plugin-catalog` über das GitHub-Actions-Secret;
- Git und eine aktuelle GitHub CLI (`gh`) für lokale Veröffentlichungen;
- eine WordPress-Version ab 6.0 und PHP ab 8.1 für die veröffentlichten Plugins.

## Einmalige Einrichtung

### 1. Repositories prüfen

Jedes Plugin benötigt ein eigenes Repository und eine Workflow-Datei:

```text
.github/workflows/release.yml
```

Die Datei basiert auf [`release-workflow.yml`](release-workflow.yml). Änderungen am zentralen Workflow müssen in alle fünf Plugin-Repositories übernommen werden.

### 2. Zugriff des Workflows auf den Katalog einrichten

Der Workflow eines Plugin-Repositories muss nach einem Release in `neo-plugin-catalog` schreiben dürfen. Dazu wird ein Fine-grained Personal Access Token verwendet.

1. Melde dich bei GitHub als `neo-consult` an.
2. Öffne **Settings → Developer settings → Personal access tokens → Fine-grained tokens**.
3. Erzeuge einen Token mit folgenden Einstellungen:
   - **Resource owner:** `neo-consult`
   - **Repository access:** `Only select repositories`
   - ausgewähltes Repository: `neo-plugin-catalog`
   - **Repository permissions → Contents:** `Read and write`
4. Speichere den Token als Actions Secret `NEO_CATALOG_TOKEN` in jedem Plugin-Repository:
   - `neo-dashboard`
   - `neo-calendar`
   - `neo-surveys`
   - `neo-surveys-extern`
   - `neo-plugin-manager`

Das Secret wird nicht im Quellcode, im Katalog oder in einem lokalen Repository gespeichert.

### 3. Katalogeintrag anlegen

Jedes Plugin muss genau einen Eintrag in [`plugins.json`](plugins.json) besitzen. Beispiel:

```json
{
  "slug": "neo-calendar",
  "plugin_file": "neo-calendar/neo-calendar.php",
  "name": "Neo Calendar",
  "version": "1.1.7",
  "package": "https://github.com/neo-consult/neo-calendar/releases/download/v1.1.7/neo-calendar.zip",
  "sha256": "<64-stellige-sha256-pruefsumme>",
  "homepage": "https://github.com/neo-consult/neo-calendar",
  "requires": "6.0",
  "requires_php": "8.1",
  "description": "Projektkalender, Termine und wiederkehrende Meetings."
}
```

Wichtig:

- `slug` muss dem GitHub-Repository und dem ZIP-Dateinamen entsprechen.
- `plugin_file` ist der Pfad zur Hauptdatei relativ zu `wp-content/plugins`.
- `sha256` muss 64 hexadezimale Zeichen enthalten.
- Nach der Ersteinrichtung pflegt der Release-Workflow `version`, `package` und `sha256` automatisch.

## Einen Release veröffentlichen

### 1. Version im Plugin erhöhen

Ändere in der Hauptdatei des Plugins den WordPress-Header:

```php
 * Version: 1.2.3
```

Falls das Plugin zusätzlich eine Versionskonstante besitzt, muss diese auf dieselbe Version gesetzt werden. Beispiele:

```php
define('NEO_CALENDAR_VERSION', '1.2.3');
```

oder:

```php
define('NEO_SURVEYS_EXTERN_VERSION', '1.2.3');
```

Die Version darf keinen führenden Buchstaben `v` enthalten. Der Git-Tag hingegen verwendet immer `v`, also `v1.2.3`.

### 2. Lokal prüfen

Führe mindestens den projektspezifischen Test- und Syntaxcheck aus. Für Neo Calendar beispielsweise:

```powershell
Set-Location C:\xampp\htdocs\wordpress\wp-content\plugins\neo-calendar
$env:XDEBUG_MODE = 'off'
php vendor\bin\phpunit
php -l neo-calendar.php
```

Für andere Plugins gelten deren `composer.json`, PHPUnit-Konfiguration und Qualitätsbefehle.

### 3. Änderungen committen und pushen

Im jeweiligen Plugin-Repository:

```powershell
git status
git add -A
git commit -m "Release 1.2.3"
git push origin main
```

Vergewissere dich vor dem Commit, dass keine lokalen ZIP-Dateien, Backups, Zugangsdaten oder Test-Caches aufgenommen werden.

### 4. Tag erstellen und veröffentlichen

```powershell
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
```

Das Pushen des Tags startet den Workflow **Release WordPress plugin**.

### 5. Workflow kontrollieren

Auf GitHub: **Repository → Actions → Release WordPress plugin**.

Der Workflow muss diese Schritte erfolgreich abschließen:

- `Validate release version`
- `Build installable ZIP and checksum`
- `Require catalog publishing credential`
- `Publish GitHub Release`
- `Update official plugin catalog`
- `Write release metadata to catalog`
- `Commit catalog update`

Alternativ mit der GitHub CLI:

```powershell
gh run list --repo neo-consult/neo-calendar --limit 1
```

## Was genau im ZIP enthalten ist

Das Release-ZIP enthält genau einen obersten Ordner mit dem Plugin-Slug, zum Beispiel:

```text
neo-calendar.zip
└── neo-calendar/
    ├── neo-calendar.php
    ├── src/
    ├── assets/
    └── templates/
```

Der Workflow schließt unter anderem aus:

- `.git` und `.github`;
- Tests;
- Composer-Entwicklungsabhängigkeiten in `vendor`;
- `node_modules`;
- Dokumentationsordner;
- lokale WordPress-Kopien unter `wp-content`;
- vorhandene ZIP-Dateien und PHPUnit-Caches.

## Installation in WordPress

### Neo Plugin Manager installieren

Der Neo Plugin Manager wird einmalig als ZIP installiert:

1. Lade `neo-plugin-manager.zip` aus dem aktuellen [GitHub Release](https://github.com/neo-consult/neo-plugin-manager/releases) herunter.
2. Öffne in WordPress **Plugins → Installieren → Plugin hochladen**.
3. Wähle das ZIP aus, installiere und aktiviere es.
4. Öffne **Werkzeuge → Neo Plugins**.

### Weitere Neo-Plugins installieren

Unter **Werkzeuge → Neo Plugins** zeigt der Manager die Einträge des offiziellen Katalogs. Installiere Abhängigkeiten in dieser Reihenfolge:

1. Neo Dashboard Core
2. Neo Calendar oder Neo Surveys
3. Neo Surveys Extern, falls externe Umfragen benötigt werden

Nach der Installation muss jedes Plugin über **Plugins** aktiviert werden.

## Updates in WordPress

Der Neo Plugin Manager erweitert die normale WordPress-Updateprüfung.

1. Öffne **Dashboard → Aktualisierungen**.
2. WordPress zeigt eine neue Version an, wenn die Katalogversion höher ist als die installierte Plugin-Version.
3. Starte das Update wie bei einem üblichen WordPress-Plugin.
4. Der Manager lädt das ZIP herunter und prüft dessen SHA-256-Prüfsumme vor dem Entpacken.

Bei einer abweichenden Prüfsumme wird die Installation abgebrochen. Das schützt vor beschädigten, vertauschten oder manipulierten Paketdateien.

## Fehlerbehebung

### Workflow meldet „Require catalog publishing credential“ fehlgeschlagen

Das Secret `NEO_CATALOG_TOKEN` fehlt, ist leer oder ungültig.

- Prüfe unter **Repository → Settings → Secrets and variables → Actions** den Secret-Namen.
- Setze den Token erneut.
- Stelle sicher, dass der Fine-grained Token für `neo-plugin-catalog` die Berechtigung **Contents: Read and write** besitzt.
- Starte den fehlgeschlagenen Workflow in GitHub Actions erneut.

### Workflow meldet einen Versionsfehler

Der Git-Tag und der Plugin-Header stimmen nicht überein.

Beispiel: Bei Tag `v1.2.3` muss der Header exakt `Version: 1.2.3` enthalten.

Korrigiere die Version, committe die Änderung und erstelle einen neuen, höheren Tag. Bereits veröffentlichte Release-Tags werden nicht wiederverwendet.

### Plugin erscheint nicht im Neo Plugin Manager

- Prüfe, ob der Katalog erreichbar ist:

  ```text
  https://raw.githubusercontent.com/neo-consult/neo-plugin-catalog/main/plugins.json
  ```

- Prüfe, ob der Eintrag ein gültiges `sha256`-Feld enthält.
- Leere gegebenenfalls den WordPress-Transient-Cache oder warte maximal 15 Minuten; der Manager cached den Katalog für diesen Zeitraum.

### Prüfsummenfehler bei Installation oder Update

Ein Release-Asset wurde nach der Prüfsummenberechnung geändert oder der Katalog verweist auf das falsche Paket.

- Veröffentliche kein vorhandenes Tag erneut.
- Erstelle einen neuen Tag mit einer höheren Version.
- Lasse den Workflow das ZIP und die Prüfsumme erneut erzeugen.

## Sicherheitsregeln

- Tokens niemals in Quellcode, `plugins.json`, Issues oder Chat-Nachrichten einfügen.
- Für `NEO_CATALOG_TOKEN` ausschließlich Fine-grained Tokens mit minimalen Rechten verwenden.
- Release-Tags nach Veröffentlichung nicht verschieben oder wiederverwenden.
- Prüfsummen im Katalog nur durch den Release-Workflow pflegen.
- Vor jedem Release die automatisierten Tests des jeweiligen Plugins ausführen.
