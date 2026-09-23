# bytesimal-dotfile

Personal dotfiles for a Hyprland desktop on Arch Linux. `install.sh` turns a barebone Arch install (base + linux + a sudo user + network) into the full desktop.

## Layout

- The repo is the source of truth. `install.sh` symlinks it into `$HOME`, so editing `~/.config/...` edits the repo:
  - `config/{hypr,quickshell,kitty,fastfetch,qt5ct,qt6ct,gtk-3.0,gtk-4.0}` → `~/.config/<name>` (whole dirs)
  - `config/starship.toml` → `~/.config/starship.toml`, `home/.zshrc` → `~/.zshrc`
  - `config/autostart/*.desktop` → linked one by one into `~/.config/autostart`
- An existing file at a link target is moved to `<name>.bak.<date>`, never deleted. The `.bak` files are gitignored and outside the repo.
- `config/hypr/hyprland.lua`: Lua config format (Hyprland 0.56+).
- `config/quickshell/`: bar, launcher, volume/calendar popups, sound settings window (`Mixer.qml`), video wallpaper. Shared bits: `BarPopup.qml`, `VolumeRow.qml`, `Theme.qml`.
- Wallpaper video (`~/Pictures/Wallpapers/anime-eye.mp4`, 118 MB) is **not** in the repo (too big for git). Without it the background is black.

## install.sh

- Package groups are bash arrays (CORE, PORTALS, NETWORK, KEYRING, TERMINAL, SHELL_PKGS, DESKTOP_SHELL, THEME, AUDIO, SCREENSHOT, BASICS, GPU). Add new packages to the matching group.
- **Desktop only: no user applications** (browsers, chat apps, etc.).
- GPU: Mesa + Vulkan 32/64-bit. The Vulkan driver is picked from `/sys/class/drm/card*/device/vendor` (AMD → radeon, Intel → intel; NVIDIA prints a warning). Enables multilib in `/etc/pacman.conf` for the lib32-* packages.
- NetworkManager is enabled without `--now` (starts on next boot, so it doesn't fight the network used for the install).
- Keyring: `gnome-keyring-daemon.socket` starts the daemon; the autostart entries (`Hidden=true`) stop a second one. PAM lines in `/etc/pam.d/login` (unlock on TTY login) and `/etc/pam.d/passwd` (keep passwords in sync).
- Sets zsh as the login shell. Hyprland is started by hand from the TTY (no display manager, no auto-start).
- Official repos only (pacman). No AUR packages.

## Conventions

- Install with `sudo pacman -Syu --needed --noconfirm --ask 4`. Always `-Syu`, never `-Sy` (partial upgrades break Arch). `--ask 4` auto-accepts removing conflicting packages (e.g. `jack2` for `pipewire-jack`).
- Script must stay safe to re-run (`--needed`, the `link` helper skips existing links, `|| true` on optional steps).
- Don't run `install.sh` from Claude, because it uses sudo. Check with `bash -n install.sh`, or dry-run it with a scratch `HOME` and stub `sudo`/`systemctl`/`gsettings`/`xdg-user-dirs-update` on `PATH`. `shellcheck` isn't installed.

## Config notes

- Hyprland: check edits with `hyprctl reload && hyprctl configerrors`.
- Quickshell hot-reloads on save; check with `qs log | tail`. Popups use `grabFocus`, which only works when the popup opens from real input, so it can't be opened from a timer or IPC to test it.
- Screenshots: `Print` (region), `Shift+Print` (full), `Super+Print` (monitor) → `~/Pictures/Screenshots` + clipboard.
- Sound settings window: `qs ipc call mixer toggle`. Launcher: `qs ipc call launcher toggle` (Super+R).

## TODO

- Config references apps that aren't installed: `dolphin` (Super+E), `hyprshutdown` (Super+M falls back to exit).
- No notification daemon yet.
