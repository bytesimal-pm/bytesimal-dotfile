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
    "${BLUETOOTH[@]}"
    "${KEYRING[@]}"
    "${TERMINAL[@]}"
    "${SHELL_PKGS[@]}"
    "${DESKTOP_SHELL[@]}"
    "${THEME[@]}"
    "${AUDIO[@]}"
    "${SCREENSHOT[@]}"
    "${BASICS[@]}"
    "${GPU[@]}"
    "${APPS[@]}"
    "${AUR_BUILD[@]}"
)

# lib32-* packages live in multilib, which is commented out by default.
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    info "Enabling multilib in /etc/pacman.conf..."
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
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

# ---------------------------------------------------------------- services

# Enable only (no --now): starting it now could fight with whatever
# brought the network up for this install. It starts on the next boot.
info "Enabling NetworkManager (starts on next boot)..."
sudo systemctl enable NetworkManager.service

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
  - Reboot, log in on the TTY and run `Hyprland`.
    The first login creates the keyring; PAM unlocks it from then on.
  - Keys: Super+Q terminal, Super+R launcher, Print screenshot.
EOF
