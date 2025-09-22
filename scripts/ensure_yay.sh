#!/usr/bin/env bash
# scripts/ensure_yay.sh
# Ensures yay (AUR helper) is installed on Arch/Manjaro systems.

set -euo pipefail

# Only run on Arch-based systems
. /etc/os-release
case "${ID:-}" in
    arch|manjaro) ;;
    *)
        log "Not Arch/Manjaro; skipping yay installation."
        exit 0
        ;;
esac

# Exit if yay is already installed
if command -v yay >/dev/null; then
    exit 0
fi

log "Installing yay (AUR helper)..."

# Install dependencies
sudo pacman -S --needed --noconfirm base-devel git

# Clone and build yay
git clone https://aur.archlinux.org/yay.git /tmp/yay
(cd /tmp/yay && makepkg -si --noconfirm)

log "✅ yay installed successfully."