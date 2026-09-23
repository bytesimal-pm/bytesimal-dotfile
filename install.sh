#!/usr/bin/env bash
# Base install for a Hyprland desktop on Arch Linux.
# Installs packages only — no Hyprland customization yet.
set -euo pipefail

info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m::\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m::\033[0m %s\n' "$*" >&2; }

if [[ $EUID -eq 0 ]]; then
    err "Don't run this as root. The script uses sudo when it needs to."
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    err "pacman not found. This script only supports Arch Linux."
    exit 1
fi

CORE=(
    hyprland
    qt5-wayland
    qt6-wayland
    hyprpolkitagent
)

PORTALS=(
    xdg-desktop-portal
    xdg-desktop-portal-hyprland # screen sharing, screenshots
    xdg-desktop-portal-gtk      # file picker
)

KEYRING=(
    gnome-keyring
    libsecret
    seahorse # GUI to manage the keyring
)

TERMINAL=(
    kitty
)

DESKTOP_SHELL=(
    quickshell # bar/widgets, configured in QML
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
    network-manager-applet
    brightnessctl
    playerctl
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji
)

PKGS=(
    "${CORE[@]}"
    "${PORTALS[@]}"
    "${KEYRING[@]}"
    "${TERMINAL[@]}"
    "${DESKTOP_SHELL[@]}"
    "${AUDIO[@]}"
    "${SCREENSHOT[@]}"
    "${BASICS[@]}"
)

# -Syu (not -Sy) to avoid partial upgrades
info "Updating system and installing ${#PKGS[@]} packages..."
sudo pacman -Syu --needed --noconfirm "${PKGS[@]}"
ok "Packages installed."

info "Enabling audio services..."
systemctl --user enable --now pipewire pipewire-pulse wireplumber

info "Enabling keyring..."
systemctl --user enable --now gnome-keyring-daemon.socket || true

# Portals that started before PipeWire have no screen sharing.
# Restart them now that PipeWire is up (only works inside Hyprland).
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    info "Restarting desktop portals..."
    systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal || true
fi

ok "Done!"
cat <<'EOF'

Next steps:
  - Log out and choose Hyprland in your display manager,
    or run `Hyprland` from a TTY.
  - Keyring will be unlocked at login once Hyprland autostart is configured.
  - Screenshot test (inside Hyprland): grim -g "$(slurp)" - | wl-copy
EOF
