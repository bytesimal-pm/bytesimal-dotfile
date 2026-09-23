#!/usr/bin/env bash
# Hyprland desktop on a barebone Arch Linux install.
# Installs the desktop packages (no user applications), links the configs
# from this repo into $HOME, and sets up services, the keyring and zsh.
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
    network-manager-applet # tray icon
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
    "${KEYRING[@]}"
    "${TERMINAL[@]}"
    "${SHELL_PKGS[@]}"
    "${DESKTOP_SHELL[@]}"
    "${THEME[@]}"
    "${AUDIO[@]}"
    "${SCREENSHOT[@]}"
    "${BASICS[@]}"
    "${GPU[@]}"
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
link config/starship.toml "$HOME/.config/starship.toml"
link home/.zshrc "$HOME/.zshrc"

# The keyring's systemd socket starts the daemon, so hide the XDG autostart
# entries — otherwise a second daemon starts alongside it. Linked one by
# one, since ~/.config/autostart may hold other entries.
for f in "$SCRIPT_DIR"/config/autostart/*.desktop; do
    link "config/autostart/$(basename -- "$f")" "$HOME/.config/autostart/$(basename -- "$f")"
done

mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers"
xdg-user-dirs-update || true

# ---------------------------------------------------------------- services

# Enable only (no --now): starting it now could fight with whatever
# brought the network up for this install. It starts on the next boot.
info "Enabling NetworkManager (starts on next boot)..."
sudo systemctl enable NetworkManager.service

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
  - Wallpaper: put a video at ~/Pictures/Wallpapers/anime-eye.mp4
    (path set in config/quickshell/Theme.qml). Without it the background is black.
  - Keys: Super+Q terminal, Super+R launcher, Print screenshot.
EOF
