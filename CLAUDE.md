# bytesimal-dotfile

Personal dotfiles for a Hyprland desktop on Arch Linux. `install.sh` turns a barebone Arch install (base + linux + a sudo user + network) into the full desktop.

## Layout

- The repo is the source of truth. `install.sh` symlinks it into `$HOME`, so editing `~/.config/...` edits the repo:
  - `config/{hypr,quickshell,kitty,fastfetch,qt5ct,qt6ct,gtk-3.0,gtk-4.0}` → `~/.config/<name>` (whole dirs)
  - `config/starship.toml` → `~/.config/starship.toml`, `home/.zshrc` → `~/.zshrc`
  - `local/share/fonts/sarabun/` → `~/.local/share/fonts/sarabun`, `config/fontconfig/fonts.conf` → `~/.config/fontconfig/fonts.conf`
  - `config/kdeglobals` → `~/.config/kdeglobals`, `local/share/color-schemes/Monochrome.colors` → `~/.local/share/color-schemes/`
  - `wallpapers/shizuku-monochrome-4k.mp4` → `~/Pictures/Wallpapers/`
  - `config/autostart/*.desktop` → linked one by one into `~/.config/autostart`
- An existing file at a link target is moved to `<name>.bak.<date>`, never deleted. The `.bak` files are gitignored and outside the repo.
- `config/hypr/hyprland.lua`: Lua config format (Hyprland 0.56+).
- `config/quickshell/`: bar, launcher, volume/calendar/internet/bluetooth/battery popups, sound settings window (`Mixer.qml`), video wallpaper. Shared bits: `BarPopup.qml`, `VolumeRow.qml`, `Theme.qml`.
- KDE apps (Dolphin) outside Plasma: colors come from the scheme named in `kdeglobals` `[UiSettings] ColorScheme` (the `.colors` file); the font comes from qt6ct/qt5ct `[Fonts]`, not kdeglobals. Hyprland rule `dolphin-opacity` adds see-through + blur.
- Vesktop (Discord): `config/vesktop/themes/monochrome.theme.css`, linked by `install.sh`. Needs Vencord settings `transparent: true` + the theme enabled (in `~/.config/vesktop/settings/settings.json`, edit only while Vesktop is closed). Vencord doesn't notice edits made through the symlink: re-create the link (or Ctrl+R in Vesktop) to reload.
- Firefox: `config/firefox/{user.js,chrome/}` linked into the profile named by `Default=` in `installs.ini` (`~/.config/mozilla/firefox`). `user.js` turns on userChrome/userContent and transparency; UI + new tab are themed, websites are not. Firefox reads them only at startup.
- Thai font: Google Sarabun (16 styles, OFL, files in the repo). `fonts.conf`: Sarabun is the Thai fallback for JetBrains Mono / Noto / Adwaita, and first choice for `lang=th` sans-serif/serif (appended for monospace so Latin stays monospace). Don't put `accept` rules on the generic names (`sans-serif`...) — user config runs before the system defaults, so that made Sarabun the Latin font too. Chromium/Electron (Discord) look up missing glyphs with no family (only the character), which picked FreeSerif for Thai; the `append_last` Sarabun rule fixes that, and the Discord/Firefox CSS font stacks list Sarabun too. Check with `fc-match 'sans-serif:lang=th:weight=bold:slant=italic'` and `fc-match ':charset=0e2d'`. `noto-fonts-cjk` covers CJK/Korean decorations (`﹒ ㅡ`) that otherwise show as squares.
- Plain Qt apps (e.g. `hyprland-share-picker`, the Screen/Window/Region picker): qt5ct/qt6ct `colors/Monochrome.conf` palette (`color_scheme_path` accepts `~`) + `qss/monochrome.qss` stylesheet (`stylesheets` needs a full path — `install.sh` rewrites it to the current `$HOME`). Hyprland rule `share-picker-opacity`. Vesktop's own Screen Share Picker is styled in the Vesktop theme (`.vcd-screen-picker-*`).
- Wallpaper video: `wallpapers/shizuku-monochrome-4k.mp4` (63 MB, 4K60 H.264, an upscale of the 1080p moewalls.com video; path set in `Theme.qml`; avoid AV1, the AMD iGPU can't hardware-decode it). Over GitHub's 50 MB warning size, under its 100 MB limit.

## install.sh

- Package groups are bash arrays (CORE, PORTALS, NETWORK, BLUETOOTH, KEYRING, TERMINAL, SHELL_PKGS, DESKTOP_SHELL, THEME, AUDIO, SCREENSHOT, BASICS, GPU, APPS, AUR_BUILD, AUR_PKGS). Add new packages to the matching group.
- Apps: only the ones this repo themes: Dolphin + Firefox (APPS, pacman) and Vesktop (AUR_PKGS). No other user applications.
- GPU: Mesa + Vulkan 32/64-bit. The Vulkan driver is picked from `/sys/class/drm/card*/device/vendor` (AMD → radeon, Intel → intel; NVIDIA prints a warning). Enables multilib in `/etc/pacman.conf` for the lib32-* packages.
- `bluetooth.service` (BlueZ) is enabled with `--now`.
- NetworkManager is enabled without `--now` (starts on next boot, so it doesn't fight the network used for the install).
- Keyring: `gnome-keyring-daemon.socket` starts the daemon; the autostart entries (`Hidden=true`) stop a second one. PAM lines in `/etc/pam.d/login` (unlock on TTY login) and `/etc/pam.d/passwd` (keep passwords in sync).
- Sets zsh as the login shell. Hyprland is started by hand from the TTY (no display manager, no auto-start).
- Official repos (pacman) for everything except `vesktop` and `fzf-tab`, which are AUR-only: the script builds `yay-bin` if `yay` is missing, then `yay -S --needed --noconfirm` the AUR_PKGS.
- Firefox profile: on a fresh install there is none until first start, so the script runs `firefox --headless --no-remote` once (15 s timeout) to create it, then links the theme. Vencord settings: a fresh install gets a minimal `settings.json` (transparent + theme); an existing one is only checked (warns if off).

## Conventions

- Install with `sudo pacman -Syu --needed --noconfirm --ask 4`. Always `-Syu`, never `-Sy` (partial upgrades break Arch). `--ask 4` auto-accepts removing conflicting packages (e.g. `jack2` for `pipewire-jack`).
- Script must stay safe to re-run (`--needed`, the `link` helper skips existing links, `|| true` on optional steps).
- Don't run `install.sh` from Claude, because it uses sudo. Check with `bash -n install.sh`, or dry-run it with a scratch `HOME` and stub `sudo`/`systemctl`/`gsettings`/`xdg-user-dirs-update`/`yay`/`makepkg` on `PATH`. `shellcheck` isn't installed.

## Config notes

- Hyprland: check edits with `hyprctl reload && hyprctl configerrors`.
- Quickshell hot-reloads on save; check with `qs log | tail`. If `~/.config/quickshell` itself is replaced (e.g. re-linked), the running `qs` keeps watching the old dir: restart it.
- Tray (`Tray.qml`): right-click menus are drawn by `TrayMenu.qml` (QsMenuOpener in a `BarPopup`) because `QsMenuAnchor` needs QApplication mode. Drag icons to reorder; order saved in `Quickshell.statePath("tray-order.json")`. Popups use `grabFocus`, which only works when the popup opens from real input, so it can't be opened from a timer or IPC to test it.
- Screenshots: `Print` (region), `Shift+Print` (full), `Super+Print` (monitor) → `~/Pictures/Screenshots` + clipboard.
- Sound settings window: `qs ipc call mixer toggle`. Launcher: `qs ipc call launcher toggle` (Super+R).
- Battery (`Battery.qml` + `BatteryPopup.qml`): `Quickshell.Services.UPower` display device (needs `upower`, D-Bus activated). Only shown when it's a laptop battery (`isLaptopBattery`), so desktops don't get it. Blinks below 15% while discharging; click for status/time left/power/health.
- Bluetooth (`BluetoothIcon.qml` + `BluetoothPopup.qml`; not `Bluetooth.qml`, that name shadows the `Quickshell.Bluetooth` singleton): built-in `Quickshell.Bluetooth` module (BlueZ over D-Bus). Hidden without an adapter/BlueZ. `qs` only looks for BlueZ at startup (a config reload isn't enough): if `bluetooth.service` started after it, restart `qs` (`pkill -x qs; setsid -f qs`). Right-click the icon toggles Bluetooth; scans only while the popup is open. No pairing agent, so only "Just Works" pairing (headphones, mice, speakers); devices that need a PIN/passkey: `bluetoothctl`.
- Wallpaper (`Wallpaper.qml` + `shaders/wallpaper.frag`): the video and the clock are drawn into one texture, then one shader adds cursor parallax (Shizuku moves more than the spiral, using `assets/shizuku-depth.png` as a depth mask: her outline has a red/cyan fringe the grey spiral lacks, so it was traced from the chroma, max over all frames, then flood-filled from the background), the vacuum (shrinks into the spiral center and springs back, no spin; only by IPC), the glasses glint (every 6–12 s) and the dim. Blur + dim + no clock while the workspace has windows; the video pauses under a fullscreen window. Positions (spiral center, lenses) and the depth mask are measured on this video, so a different video needs new ones. After editing the shader, recompile the committed `.qsb`: `/usr/lib/qt6/bin/qsb --qt6 -o shaders/wallpaper.frag.qsb shaders/wallpaper.frag`, then restart `qs` (hot reload misses it). Test: `qs ipc call wallpaper vacuum` / `glint`. Hyprland dispatch in the Lua config: `hyprctl dispatch "hl.dsp.focus({ workspace = 9 })"`.
- Popup building blocks shared by the Internet and Bluetooth popups: `ListRow.qml`, `TextButton.qml`, `Switch.qml`.
- Internet popup (`Network.qml` icon + `NetworkPopup.qml`): Ethernet and Wi-Fi through the built-in `Quickshell.Networking` module (talks to NetworkManager over D-Bus, no nmcli). Right-click the icon toggles Wi-Fi. Scans only while the popup is open. The list freezes while a row is expanded, so a half-typed password survives rescans. Enterprise (EAP) networks aren't supported there (use nmcli).

## TODO

- Config references apps that aren't installed: `dolphin` (Super+E), `hyprshutdown` (Super+M falls back to exit).
- No notification daemon yet.
