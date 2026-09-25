#!/usr/bin/env bash
# Hyprland desktop on a barebone Arch Linux install.
# Installs the desktop packages plus the apps this repo themes (Dolphin,
# Firefox, Discord/Vesktop), links the configs from this repo into $HOME,
# and sets up services, the keyring and zsh.
# Safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m::\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m::\033[0m %s\n' "$*" >&2; }

if [[ $EUID -eq 0 ]]; then
    err "Don't run this as root. The script uses sudo when it needs to."
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    err "pacman not found. This script only supports Arch Linux."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1 || ! sudo -v; then
    err "This script needs sudo. Install it and add your user to sudoers first."
    exit 1
fi

# ---------------------------------------------------------------- packages

CORE=(
    hyprland
    xorg-xwayland # X11 apps
    qt5-wayland
    qt6-wayland
    polkit
    hyprpolkitagent # password prompts, started from hyprland.lua
)

PORTALS=(
    xdg-desktop-portal
    xdg-desktop-portal-hyprland # screen sharing, screenshots
    xdg-desktop-portal-gtk      # file picker
    xdg-user-dirs               # ~/Pictures, ~/Downloads, ...
)

NETWORK=(
    networkmanager
)

MIRRORS=(
    reflector # ranks pacman mirrors by speed (config/reflector), weekly timer
)

BLUETOOTH=(
    bluez       # daemon, the bar's Bluetooth popup talks to it over D-Bus
    bluez-utils # bluetoothctl (pairing devices that need a PIN)
)

KEYRING=(
    gnome-keyring
    libsecret
    seahorse # GUI to manage the keyring
)

TERMINAL=(
    kitty
)

SHELL_PKGS=(
    zsh
    zsh-completions
    zsh-autosuggestions
    zsh-syntax-highlighting
    fzf
    fd
    starship
    fastfetch
)

DESKTOP_SHELL=(
    quickshell            # bar/widgets, configured in QML
    qt6-multimedia        # video wallpaper
    qt6-multimedia-ffmpeg
    qt6-svg               # SVG icons
)

THEME=(
    gnome-themes-extra # Adwaita-dark for GTK3
    qt5ct
    qt6ct
    adwaita-icon-theme
    adwaita-cursors
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji
    noto-fonts-cjk # CJK/Korean glyphs: decorations like ﹒ ㅡ in names show as squares without it
)

AUDIO=(
    pipewire
    pipewire-alsa
    pipewire-pulse
    pipewire-jack
    wireplumber
    pavucontrol
)

SCREENSHOT=(
    grim         # capture
    slurp        # region select
    wl-clipboard # copy to clipboard
)

# Login screen: greetd runs a Quickshell greeter in a small Hyprland (greeter/)
GREETER=(
    greetd
)

BASICS=(
    brightnessctl
    playerctl
    upower # battery info for the bar (Battery.qml)
)

# Apps themed by this repo: Dolphin (config/kdeglobals), Firefox
# (config/firefox). Discord is Vesktop from the AUR, see AUR_PKGS.
APPS=(
    dolphin
    kio-extras   # Dolphin thumbnails, network places
    breeze-icons # Breeze Dark icons (config/kdeglobals)
    firefox
)

# Built with yay (installed below if missing); needs base-devel + git
AUR_BUILD=(
    base-devel
    git
)
AUR_PKGS=(
    vesktop # Discord client with Vencord (themes, transparent window)
    fzf-tab # zsh Tab completion in an fzf picker (home/.zshrc)
)

# Mesa + Vulkan, 64- and 32-bit (lib32-* is for Steam/Proton, needs multilib).
# The Vulkan driver is picked from the GPU vendors found in /sys.
GPU=(
    mesa
    lib32-mesa
    vulkan-icd-loader
    lib32-vulkan-icd-loader
)

vendors="$(cat /sys/class/drm/card*/device/vendor 2>/dev/null | sort -u || true)"
if grep -q 0x1002 <<<"$vendors"; then
    info "AMD GPU found."
    GPU+=(vulkan-radeon lib32-vulkan-radeon)
fi
if grep -q 0x8086 <<<"$vendors"; then
    info "Intel GPU found."
    GPU+=(vulkan-intel lib32-vulkan-intel)
fi
if grep -q 0x10de <<<"$vendors"; then
    warn "NVIDIA GPU found. Its driver is not installed by this script —"
    warn "install nvidia-open (or nouveau's vulkan-nouveau) yourself."
fi

PKGS=(
    "${CORE[@]}"
    "${PORTALS[@]}"
    "${NETWORK[@]}"
    "${MIRRORS[@]}"
    "${BLUETOOTH[@]}"
    "${KEYRING[@]}"
    "${TERMINAL[@]}"
    "${SHELL_PKGS[@]}"
    "${DESKTOP_SHELL[@]}"
    "${THEME[@]}"
    "${AUDIO[@]}"
    "${SCREENSHOT[@]}"
    "${GREETER[@]}"
    "${BASICS[@]}"
    "${GPU[@]}"
    "${APPS[@]}"
    "${AUR_BUILD[@]}"
)

# Copy a repo file to a system path (root-owned, so copied, not linked).
# A different existing file is kept as <name>.bak.<date>.
# Returns 1 if the destination already had the same file.
copy_root() {
    local src="$SCRIPT_DIR/$1" dest="$2"
    if sudo cmp -s -- "$src" "$dest"; then
        return 1
    fi
    if sudo test -e "$dest"; then
        sudo mv -- "$dest" "$dest.bak.$STAMP"
        warn "Backed up $dest -> $dest.bak.$STAMP"
    fi
    if ! sudo install -Dm644 -- "$src" "$dest"; then
        warn "Couldn't install $dest"
        return 1
    fi
    info "Installed $dest"
}

# Copy etc/<path> from this repo to /etc/<path>
copy_etc() { copy_root "etc/$1" "/etc/$1"; }

# Download 10 packages at a time (default 5)
if ! grep -q '^ParallelDownloads = 10$' /etc/pacman.conf; then
    info "Setting ParallelDownloads = 10 in /etc/pacman.conf..."
    sudo sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
fi

# lib32-* packages live in multilib, which is commented out by default.
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    info "Enabling multilib in /etc/pacman.conf..."
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
fi

# ---------------------------------------------------------------- mirrors

# Rank the mirrors before the big download (etc/xdg/reflector/reflector.conf)
info "Installing reflector..."
sudo pacman -Syu --needed --noconfirm reflector
copy_etc xdg/reflector/reflector.conf || true

MIRRORLIST=/etc/pacman.d/mirrorlist
info "Finding the fastest mirrors (this takes a minute)..."
sudo cp -a "$MIRRORLIST" "$MIRRORLIST.bak.$STAMP"
if ! sudo systemctl start reflector.service || ! sudo test -s "$MIRRORLIST"; then
    warn "reflector failed, keeping the old mirrorlist."
    sudo cp -a "$MIRRORLIST.bak.$STAMP" "$MIRRORLIST"
fi

# -Syu (not -Sy) to avoid partial upgrades.
# --ask 4 answers "yes" to removing conflicting packages (e.g. jack2 for
# pipewire-jack) — plain --noconfirm answers "no" and aborts the install.
info "Updating system and installing ${#PKGS[@]} packages..."
sudo pacman -Syu --needed --noconfirm --ask 4 "${PKGS[@]}"
ok "Packages installed."

# ---------------------------------------------------------------- AUR

if ! command -v yay >/dev/null 2>&1; then
    info "Installing yay (AUR helper)..."
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi

info "Installing AUR packages: ${AUR_PKGS[*]}..."
yay -S --needed --noconfirm --answerdiff None --answerclean None "${AUR_PKGS[@]}"

# ---------------------------------------------------------------- configs

# Symlink a file/dir from this repo into $HOME. An existing file is kept
# as <name>.bak.<date>; an existing link to the repo is left alone.
link() {
    local src="$SCRIPT_DIR/$1" dest="$2"
    if [[ -L $dest && "$(readlink -- "$dest")" == "$src" ]]; then
        return
    fi
    mkdir -p -- "$(dirname -- "$dest")"
    if [[ -e $dest || -L $dest ]]; then
        mv -- "$dest" "$dest.bak.$STAMP"
        warn "Backed up $dest -> $dest.bak.$STAMP"
    fi
    ln -s -- "$src" "$dest"
    info "Linked $dest"
}

info "Linking configs..."
for dir in hypr quickshell kitty fastfetch qt5ct qt6ct gtk-3.0 gtk-4.0; do
    link "config/$dir" "$HOME/.config/$dir"
done

# qt5ct/qt6ct don't expand ~ in the stylesheet path, so the repo stores a
# full path. Point it at this $HOME if the repo was made on another account.
for v in 5 6; do
    sed -i "s|^stylesheets=.*/\.config/qt${v}ct/|stylesheets=$HOME/.config/qt${v}ct/|" \
        "$SCRIPT_DIR/config/qt${v}ct/qt${v}ct.conf"
done
link config/starship.toml "$HOME/.config/starship.toml"
link config/kdeglobals "$HOME/.config/kdeglobals" # KDE apps (Dolphin) colors/font/icons
link local/share/color-schemes/Monochrome.colors "$HOME/.local/share/color-schemes/Monochrome.colors"
link home/.zshrc "$HOME/.zshrc"

# Thai font: Sarabun (all weights + italics, in the repo) and the fontconfig
# rules that make Thai text use it
link local/share/fonts/sarabun "$HOME/.local/share/fonts/sarabun"
link config/fontconfig/fonts.conf "$HOME/.config/fontconfig/fonts.conf"
# Grey Dolphin app icon (bar, launcher); the user hicolor dir wins over /usr/share
link local/share/icons/hicolor/scalable/apps/org.kde.dolphin.svg "$HOME/.local/share/icons/hicolor/scalable/apps/org.kde.dolphin.svg"
fc-cache -f >/dev/null 2>&1 || true

# The keyring's systemd socket starts the daemon, so hide the XDG autostart
# entries — otherwise a second daemon starts alongside it. Linked one by
# one, since ~/.config/autostart may hold other entries.
for f in "$SCRIPT_DIR"/config/autostart/*.desktop; do
    link "config/autostart/$(basename -- "$f")" "$HOME/.config/autostart/$(basename -- "$f")"
done

# Discord (Vesktop): theme + Vencord settings (transparent window, theme on).
# A fresh install gets a minimal settings file; Vencord fills in the rest.
# An existing one is left alone (Vesktop may be running and would overwrite it).
link config/vesktop/themes/monochrome.theme.css "$HOME/.config/vesktop/themes/monochrome.theme.css"
VENCORD="$HOME/.config/vesktop/settings/settings.json"
if [[ ! -s $VENCORD ]]; then
    mkdir -p "$(dirname -- "$VENCORD")"
    printf '{\n    "transparent": true,\n    "enabledThemes": ["monochrome.theme.css"]\n}\n' >"$VENCORD"
    info "Turned on Vesktop transparency + theme"
elif ! grep -q '"transparent": true' "$VENCORD" || ! grep -q monochrome.theme.css "$VENCORD"; then
    warn "Vesktop: turn on Settings -> Vencord -> Transparent window,"
    warn "and Themes -> monochrome.theme.css"
fi

# Firefox: the profile in use is the Default= line in installs.ini
ff_profile() {
    local ffdir profile
    for ffdir in "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox"; do
        [[ -f $ffdir/installs.ini ]] || continue
        profile="$(sed -n 's/^Default=//p' "$ffdir/installs.ini" | head -n1)"
        if [[ -n $profile && -d $ffdir/$profile ]]; then
            echo "$ffdir/$profile"
            return
        fi
    done
}

# A fresh install has no profile until Firefox's first start: start it
# headless once so it creates one.
if [[ -z "$(ff_profile)" ]] && ! pgrep -x firefox >/dev/null; then
    info "Creating the Firefox profile..."
    timeout 15 firefox --headless --no-remote about:blank >/dev/null 2>&1 || true
fi

FF_PROFILE="$(ff_profile)"
if [[ -n $FF_PROFILE ]]; then
    link config/firefox/chrome "$FF_PROFILE/chrome"
    link config/firefox/user.js "$FF_PROFILE/user.js"
else
    warn "No Firefox profile found. Start Firefox once, then re-run install.sh."
fi

mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers"
link wallpapers/shizuku-monochrome-4k.mp4 "$HOME/Pictures/Wallpapers/shizuku-monochrome-4k.mp4" # Wallpaper.qml
xdg-user-dirs-update || true
# Breeze's user-desktop icon is full color; folder-desktop follows the color scheme
desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
if [[ -d $desktop_dir && ! -e $desktop_dir/.directory ]]; then
    printf '[Desktop Entry]\nIcon=folder-desktop\n' > "$desktop_dir/.directory"
fi

# ---------------------------------------------------------------- login screen

# The greeter runs as the `greeter` user, which can't read $HOME, so its
# files are copied (not linked): re-run this script after editing them.
info "Setting up the login screen (greetd)..."
copy_etc greetd/config.toml || true
copy_root greeter/hyprland.lua /etc/greetd/hyprland.lua || true
GREETER_QS=/etc/greetd/quickshell
for f in greeter/*.qml; do
    copy_root "$f" "$GREETER_QS/$(basename -- "$f")" || true
done
# Shared with the desktop shell (config/quickshell)
for f in Theme.qml Wallpaper.qml GlitchReveal.qml TextButton.qml \
         shaders/wallpaper.frag.qsb shaders/windowglitch.frag.qsb assets/shizuku-depth.png; do
    copy_root "config/quickshell/$f" "$GREETER_QS/$f" || true
done
# greeter/hyprland.lua points QS_WALLPAPER here
copy_root wallpapers/shizuku-monochrome-4k.mp4 /usr/local/share/wallpapers/shizuku-monochrome-4k.mp4 || true

# Unlock the login keyring when logging in through the greeter. With no
# /etc/pam.d/greetd-greeter, greetd uses this file for the `greeter` user too:
# skip the keyring for it (no password, so "couldn't unlock the login keyring").
PAM_GREETD=/etc/pam.d/greetd
SKIP_GREETER='[success=1 default=ignore] pam_succeed_if.so quiet user = greeter'
if sudo test -e "$PAM_GREETD" && ! sudo grep -q pam_gnome_keyring.so "$PAM_GREETD"; then
    info "Adding gnome-keyring to $PAM_GREETD..."
    printf '%s\n' \
        "auth       $SKIP_GREETER" \
        'auth       optional     pam_gnome_keyring.so' \
        "session    $SKIP_GREETER" \
        'session    optional     pam_gnome_keyring.so auto_start' |
        sudo tee -a "$PAM_GREETD" >/dev/null
elif sudo test -e "$PAM_GREETD" && ! sudo grep -q 'user = greeter' "$PAM_GREETD"; then
    # Added by an older version of this script, without the skip
    info "Skipping gnome-keyring for the greeter user in $PAM_GREETD..."
    sudo sed -i \
        -e "s/^auth\( *\)optional\( *\)pam_gnome_keyring.so/auth       $SKIP_GREETER\n&/" \
        -e "s/^session\( *\)optional\( *\)pam_gnome_keyring.so/session    $SKIP_GREETER\n&/" \
        "$PAM_GREETD"
fi

# Quiet boot: no kernel messages or text cursor on tty1, which shows for a
# moment between the greeter and the session (the splash takes over after).
QUIET_FLAGS=(quiet loglevel=3 vt.global_cursor_default=0)
missing_flags() { local f; for f in "${QUIET_FLAGS[@]}"; do [[ " $1 " == *" $f "* ]] || printf '%s ' "$f"; done; }
if sudo test -f /etc/kernel/cmdline && grep -qs '^[^#]*_uki=' /etc/mkinitcpio.d/*.preset; then
    # Unified kernel image (e.g. Limine / systemd-boot): cmdline is baked in by mkinitcpio
    add="$(missing_flags "$(sudo cat /etc/kernel/cmdline)")"
    if [[ -n $add ]]; then
        info "Adding '${add% }' to /etc/kernel/cmdline and rebuilding the UKI..."
        sudo cp -a /etc/kernel/cmdline "/etc/kernel/cmdline.bak.$STAMP"
        sudo sed -i "1s/\$/ ${add% }/" /etc/kernel/cmdline
        if ! sudo mkinitcpio -P; then
            warn "mkinitcpio failed, restoring /etc/kernel/cmdline."
            sudo cp -a "/etc/kernel/cmdline.bak.$STAMP" /etc/kernel/cmdline
            sudo mkinitcpio -P || true
        fi
    fi
    # A cmdline in limine.conf replaces the one in the UKI
    for conf in /boot/limine.conf /boot/limine/limine.conf /boot/EFI/limine/limine.conf /boot/EFI/BOOT/limine.conf; do
        if sudo grep -qs '^[[:space:]]*cmdline:' "$conf"; then
            warn "$conf sets its own cmdline: add ${QUIET_FLAGS[*]} there too."
        fi
    done
elif sudo test -f /boot/grub/grub.cfg && grep -qs '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
    add="$(missing_flags "$(sed -n 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/\1/p' /etc/default/grub)")"
    if [[ -n $add ]]; then
        info "Adding '${add% }' to GRUB_CMDLINE_LINUX_DEFAULT..."
        sudo cp -a /etc/default/grub "/etc/default/grub.bak.$STAMP"
        sudo sed -i "s/^\(GRUB_CMDLINE_LINUX_DEFAULT=\".*\)\"/\1 ${add% }\"/" /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg || true
    fi
else
    warn "Unknown bootloader: add ${QUIET_FLAGS[*]} to the kernel command line yourself."
fi

# No --now: it would take over tty1 (and this session) right away.
# Starts on the next boot; Ctrl+Alt+F2 still gives a text login.
sudo systemctl enable greetd.service || true

# ---------------------------------------------------------------- services

# Enable only (no --now): starting it now could fight with whatever
# brought the network up for this install. It starts on the next boot.
info "Enabling NetworkManager (starts on next boot)..."
sudo systemctl enable NetworkManager.service

# ---------------------------------------------------------------- network tuning

# TCP: BBR + bigger buffers for far-away servers (etc/sysctl.d/99-network.conf)
info "Tuning TCP (BBR, buffers)..."
copy_etc modules-load.d/bbr.conf || true
copy_etc sysctl.d/99-network.conf || true
sudo modprobe tcp_bbr || true
sudo sysctl --system >/dev/null || warn "sysctl --system failed."

# Wi-Fi power saving off; NetworkManager reads it on the next (re)start
copy_etc NetworkManager/conf.d/wifi-powersave.conf || true

# DNS: systemd-resolved as a local cache with encrypted DNS. resolv.conf
# only moves to its stub once it's running, so DNS never goes dead mid-install.
info "Setting up systemd-resolved (DNS cache, DNS over TLS)..."
copy_etc systemd/resolved.conf.d/dns.conf && sudo systemctl restart systemd-resolved.service || true
sudo systemctl enable --now systemd-resolved.service || true
STUB=/run/systemd/resolve/stub-resolv.conf
if systemctl is-active --quiet systemd-resolved.service && [[ -e $STUB ]]; then
    if [[ "$(readlink /etc/resolv.conf)" != "$STUB" ]]; then
        if [[ -e /etc/resolv.conf || -L /etc/resolv.conf ]]; then
            sudo mv /etc/resolv.conf "/etc/resolv.conf.bak.$STAMP"
        fi
        sudo ln -s "$STUB" /etc/resolv.conf
        info "Linked /etc/resolv.conf -> $STUB"
    fi
    copy_etc NetworkManager/conf.d/dns.conf || true
else
    warn "systemd-resolved isn't running; leaving DNS as it is."
fi
# Apply the NetworkManager files now if it's running (a reload keeps the connection)
if systemctl is-active --quiet NetworkManager.service; then
    sudo nmcli general reload || true
fi

info "Enabling weekly mirror refresh..."
sudo systemctl enable reflector.timer || true

info "Enabling Bluetooth..."
sudo systemctl enable --now bluetooth.service || true

info "Enabling audio services..."
systemctl --user enable --now pipewire pipewire-pulse wireplumber || true

info "Enabling keyring..."
systemctl --user enable --now gnome-keyring-daemon.socket || true

# Unlock the login keyring with the TTY login password.
PAM_LOGIN=/etc/pam.d/login
if ! grep -q pam_gnome_keyring.so "$PAM_LOGIN"; then
    info "Adding gnome-keyring to $PAM_LOGIN..."
    printf '%s\n' \
        'auth       optional     pam_gnome_keyring.so' \
        'session    optional     pam_gnome_keyring.so auto_start' |
        sudo tee -a "$PAM_LOGIN" >/dev/null
fi

# Change the keyring password along with the login password (passwd).
PAM_PASSWD=/etc/pam.d/passwd
if ! grep -q pam_gnome_keyring.so "$PAM_PASSWD"; then
    info "Adding gnome-keyring to $PAM_PASSWD..."
    echo 'password	optional	pam_gnome_keyring.so' | sudo tee -a "$PAM_PASSWD" >/dev/null
fi

# ---------------------------------------------------------------- shell & theme

if [[ "$(getent passwd "$USER" | cut -d: -f7)" != /usr/bin/zsh ]]; then
    info "Setting zsh as the login shell..."
    sudo chsh -s /usr/bin/zsh "$USER"
fi

# Dark mode for apps that read gsettings. Can fail outside a desktop
# session; gtk settings.ini and GTK_THEME in hyprland.lua cover that.
gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark 2>/dev/null || true

# Portals that started before PipeWire have no screen sharing.
# Restart them now that PipeWire is up (only works inside Hyprland).
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    info "Restarting desktop portals..."
    systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal || true
fi

ok "Done!"
cat <<'EOF'

Next steps:
  - Reboot and log in on the login screen (greetd); it starts Hyprland.
    The first login creates the keyring; PAM unlocks it from then on.
    Text login fallback: Ctrl+Alt+F2 (`sudo systemctl disable greetd` to go back).
  - Keys: Super+Q terminal, Super+R launcher, Print screenshot.
EOF
