# bytesimal-dotfile

Personal dotfiles for a Hyprland desktop on Arch Linux.

## Current state

- `install.sh` installs packages only. It does not deploy any config yet.
- `config/hypr/hyprland.lua` is a copy of `~/.config/hypr/hyprland.lua` (Lua config format, Hyprland 0.56+). The live file is the one Hyprland uses — keep the two in sync when editing.
- The live system has changes that aren't in the repo yet — only add them when asked:
  - Dark mode: `~/.config/qt5ct/qt5ct.conf` and `~/.config/qt6ct/qt6ct.conf` (Fusion + darker palette), `~/.config/gtk-3.0` and `gtk-4.0/settings.ini`, gsettings `prefer-dark`
  - Packages not in `install.sh` yet: `gnome-themes-extra`, `qt6ct`, `qt5ct`, `fuzzel`
- Package groups are bash arrays in `install.sh` (CORE, PORTALS, KEYRING, TERMINAL, AUDIO, SCREENSHOT, BASICS). Add new packages to the matching group.
- Official repos only (pacman). No AUR helper yet.

## Conventions

- Install with `sudo pacman -Syu --needed --noconfirm` — always `-Syu`, never `-Sy` (partial upgrades break Arch).
- Script must stay safe to re-run (`--needed`, `|| true` on optional steps).
- Don't run `install.sh` from Claude — it uses sudo. Check with `bash -n install.sh` and `shellcheck install.sh` (shellcheck not installed yet).

## Known issues

- **`pipewire-jack` conflicts with `jack2`.** If `jack2` is installed, `--noconfirm` defaults to "No" on the removal prompt and the whole transaction aborts. Fix: run `sudo pacman -S pipewire-jack` manually and answer `y`, or drop `pipewire-jack` from the AUDIO group.

## Hyprland config notes

- Screenshots: `Print` (region), `Shift+Print` (full), `Super+Print` (monitor) → `~/Pictures/Screenshots` + clipboard.
- Check edits with `hyprctl reload && hyprctl configerrors`.

## TODO

- Autostart `hyprpolkitagent` and unlock `gnome-keyring` at login.
- Config references apps that aren't installed: `dolphin` (Super+E), `hyprlauncher` (Super+R), `hyprshutdown` (Super+M falls back to exit).
- No notification daemon yet.
