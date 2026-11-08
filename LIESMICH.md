# Eglantine Installer & Updater für Batocera (Switch 2)

*Created by DeLorean23* · [English: README.md](README.md)

Mit diesem Installer bekommt Batocera ein eigenes System **„Switch 2“** mit dem experimentellen Emulator [Eglantine](https://github.com/Djihads80/Eglantine). Die Spiele startest du wie bei jedem anderen Emulator aus der Spieleliste, im Vollbild. Neben Switch-2-Spielen werden auch die gewohnten Switch-1-Formate und das Eglantine-Format `.nup` unterstützt.

## Download

Die ZIP gibt es unter **[Releases](https://github.com/DeLorean23/Eglantine-Batocera-Installer/releases/latest)**:

- **Eglantine Installer & Updater.zip** – installiert die PGO-Version (empfohlen)
- **Eglantine Installer & Updater (non-PGO).zip** – installiert die normale Version, falls die PGO-Version Probleme macht

Du kannst jederzeit wechseln, indem du den jeweils anderen Installer startest. Einstellungen, Keys, Firmware und Spiele bleiben erhalten.

## Voraussetzungen

- Batocera v43, x86_64-PC
- Internetverbindung (für Download und Updates)
- Keys und Firmware von deiner eigenen Switch 2

## Installation

1. Den Inhalt der ZIP nach `/userdata` entpacken, damit landen der Installer und das Cover in `/userdata/roms/ports/`.
2. In Batocera die Spieleliste aktualisieren und unter **Ports** den Eintrag **Eglantine Installer & Updater** starten.
3. Den Warnhinweis lesen und mit **y** bzw. **A** am Controller bestätigen.
4. Der Installer lädt den neuesten Build herunter und richtet alles ein.
5. Am Ende fragt er „Reboot now?“. Mit **y / A** startet Batocera neu, danach ist das System **Switch 2** in der Konsolenauswahl.

## Keys und Firmware

- Keys (`prod.keys`, `title.keys`) nach: `/userdata/bios/switch2/keys/`
- Firmware nach: `/userdata/bios/switch2/firmware/`

## Spiele (wichtig!)

Alle Spiele gehören nach `/userdata/roms/switch2/`.

*Switch-2-Spiele:* Jedes Spiel ist ein **Ordner mit der Endung `.s2`**, sonst wird es nicht erkannt:

```
/userdata/roms/switch2/
  Spielname.s2/
    base/
      exefs/
        main
```

In der Spieleliste steht dann der Ordnername ohne Endung, z. B. „Spielname“.

*Switch-1-Spiele:* Die gewohnten Switch-1-Formate werden ebenfalls unterstützt und einfach als Datei in denselben Ordner gelegt:
`.nsp`, `.nsz`, `.xci`, `.xcz`, `.nca`, `.nro`, `.nso`, `.kip`

*`.nup`-Dateien:* Das eigene Format von Eglantine, das ein Spiel mit Update und DLC in einer einzigen Datei bündelt. Einfach in denselben Ordner legen; Eglantine nimmt automatisch das neueste Update daraus, es muss also nichts extra installiert werden.

```
/userdata/roms/switch2/
  Spielname.s2/
  Spielname.nsp
  Spielname.xci
  Spielname.nup
```

Tipp: Updates und DLCs (`.nsp`) nicht in den Spieleordner legen, sonst erscheinen sie als eigenes Spiel in der Liste. Installiere sie stattdessen einmal über Eglantine: **F1 → Anwendungen → Eglantine → File → Install Files**.

## Controller und Einstellungen

Falls der Controller im Spiel nicht reagiert (Eglantine ist anfangs auf Tastatur und Maus eingestellt):

1. Mit **F1** den Dateimanager öffnen.
2. Links auf **Anwendungen** → **Eglantine** gehen.
3. In Eglantine unter **Emulation → Configure → Controls** den Controller für Player 1 (und bei Bedarf 2, 3 …) einrichten.

Die Einstellungen gelten danach für alle Spiele. Dort kannst du auch Grafik und Ähnliches anpassen. Vulkan, asynchrone Shader und der Shader-Cache sind bereits voreingestellt.

## Fenster vor dem Spielstart

Manche Spiele (z. B. Mario Kart World und Ocarina of Time) fragen vor dem Start „Use the recommended settings?“. Diese Fenster lassen sich mit dem Controller beantworten:

- **Steuerkreuz links / rechts** – zwischen Yes und No wechseln
- **A** – markierte Auswahl bestätigen
- **B** – No / Abbrechen

Das funktioniert nur, solange so ein Fenster offen ist, und stört das Spiel daher nicht.

## Spiel beenden

**Select (oder Guide) + Start** am Controller.

## Update

Den Installer einfach erneut unter Ports starten. Gibt es einen neuen Build, wird er installiert. Einstellungen, Keys, Firmware und Spiele bleiben erhalten, und die vorherige Version wird als Backup in `/userdata/system/eglantine/backup` aufgehoben. Ist nichts Neues da, steht „up to date“. Nach einem Update ist kein Neustart nötig.

## System-Logo

Der Installer bringt kein System-Logo mit. Ob beim System Switch 2 ein Logo erscheint, hängt vom Theme ab. Über Batocera heruntergeladene Themes liegen in `/userdata/themes/` und lassen sich mit einem eigenen PNG namens `switch2.png` ergänzen. Leg es neben die anderen Systemlogos des Themes, zum Beispiel:

```
/userdata/themes/one4all4one-fanartstar-bobmorane/_systemmedia/_logosyst/clearlogos/switch2.png
```

Vorinstallierte Themes sind schreibgeschützt und lassen sich nicht ergänzen.

## Hinweise

- Eglantine ist sehr experimentell. Nicht jedes Spiel läuft.
- Dieses Projekt stellt keine Spiele, Keys oder Firmware bereit.
- Log-Dateien bei Problemen: `/userdata/system/logs/eglantine-installer.log` und `/userdata/system/logs/eglantine.log`

## Bauen

`./build.sh` erstellt beide ZIPs in `dist/` aus `src/installer.template.sh` und `assets/cover.jpg`.

## Lizenz

Der Installer steht unter der [MIT-Lizenz](LICENSE). Eglantine selbst ist ein eigenes Projekt von Djihads80 mit eigener Lizenz; dieser Installer lädt es nur aus den offiziellen Releases herunter.
