# Eglantine Installer & Updater for Batocera (Switch 2)

*Created by DeLorean23* · [Deutsche Anleitung: LIESMICH.md](LIESMICH.md)

This installer adds a dedicated **"Switch 2"** system to Batocera using the experimental Eglantine emulator (https://github.com/Djihads80/Eglantine). You can launch games in fullscreen from the game list, just like with any other emulator. Besides Switch 2 games, the familiar Switch 1 formats and Eglantine's `.nup` format are supported as well.

## Download

Get the ZIP from the **[Releases](https://github.com/DeLorean23/Eglantine-Batocera-Installer/releases/latest)** page:

- **Eglantine Installer & Updater.zip** – installs the PGO build (recommended)
- **Eglantine Installer & Updater (non-PGO).zip** – installs the normal build, in case the PGO build causes problems

You can switch between the two at any time: just run the other installer. Settings, keys, firmware and games are kept.

## Requirements

- Batocera v43, x86_64 PC
- Internet connection (for downloads and updates)
- Keys and firmware from your own Switch 2

## Installation

1. Extract the contents of the ZIP archive to `/userdata`. This places the installer and its cover image in `/userdata/roms/ports/`.
2. In Batocera, refresh the game list and launch **Eglantine Installer & Updater** from **Ports**.
3. Read the warning and confirm with **y** or **A** on your controller.
4. The installer downloads the latest build and sets everything up.
5. At the end, it asks "Reboot now?". Press **y / A** to restart Batocera. After rebooting, the **Switch 2** system will appear in the console selection.

## Keys and Firmware

- Place the keys (`prod.keys`, `title.keys`) in: `/userdata/bios/switch2/keys/`
- Place the firmware in: `/userdata/bios/switch2/firmware/`

## Games (Important!)

All games must be placed in `/userdata/roms/switch2/`.

*Switch 2 games:* Each game must be a **folder ending in `.s2`**; otherwise, it will not be detected:

```text
/userdata/roms/switch2/
  GameName.s2/
    base/
      exefs/
        main
```

The game list displays the folder name without the extension, for example, "GameName".

*Switch 1 games:* The familiar Switch 1 formats are supported too. Simply place the file in the same folder:
`.nsp`, `.nsz`, `.xci`, `.xcz`, `.nca`, `.nro`, `.nso`, `.kip`

*`.nup` files:* Eglantine's own format that bundles a game with its update and DLC in a single file. Place it in the same folder; Eglantine automatically uses the newest update inside, so nothing has to be installed separately.

```text
/userdata/roms/switch2/
  GameName.s2/
  GameName.nsp
  GameName.xci
  GameName.nup
```

Tip: Don't put updates or DLCs (`.nsp`) in the games folder, or they will show up as separate games in the list. Install them once through Eglantine instead: **F1 → Applications → Eglantine → File → Install Files**.

## Controller and Settings

If the controller does not respond in a game (Eglantine initially uses keyboard and mouse input):

1. Press **F1** to open the file manager.
2. Select **Applications** on the left, then **Eglantine**.
3. In Eglantine, go to **Emulation → Configure → Controls** and configure the controller for Player 1 (and Players 2, 3, etc., if needed).

These settings apply to all games. You can also adjust graphics and other options there. Vulkan, asynchronous shaders, and the shader cache are already configured by default.

## Pop-up Windows Before a Game Starts

Some games (for example Mario Kart World and Ocarina of Time) ask "Use the recommended settings?" before they start. These windows can be answered with the controller:

- **D-pad left / right** – switch between Yes and No
- **A** – confirm the marked button
- **B** – No / Cancel

This only works while such a window is open, so it never interferes with the game.

## Exit a Game

Press **Select (or Guide) + Start** on the controller.

## Update

Simply launch the installer again from **Ports**. If a new build is available, it will be installed. Your settings, keys, firmware, and games will be preserved, and the previous version will be kept as a backup in `/userdata/system/eglantine/backup`. If no update is available, the installer displays "up to date". No reboot is required after an update.

## System Logo

The installer does not include a system logo. Whether the Switch 2 system shows a logo depends on your theme. Themes downloaded through Batocera are located in `/userdata/themes/` and can be extended with your own PNG named `switch2.png`. Put it next to the theme's other system logos, for example:

```text
/userdata/themes/one4all4one-fanartstar-bobmorane/_systemmedia/_logosyst/clearlogos/switch2.png
```

Preinstalled themes are read-only and cannot be extended.

## Notes

- Eglantine is highly experimental. Not every game will run.
- This project does not provide any games, keys or firmware.
- Log files for troubleshooting: `/userdata/system/logs/eglantine-installer.log` and `/userdata/system/logs/eglantine.log`

## Building

`./build.sh` creates both ZIP files in `dist/` from `src/installer.template.sh` and `assets/cover.jpg`.

## License

The installer is released under the [MIT License](LICENSE). Eglantine itself is a separate project by Djihads80 under its own license; this installer only downloads it from the official releases.
