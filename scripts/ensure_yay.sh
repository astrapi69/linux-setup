#!/usr/bin/env bash
set -euo pipefail
. /etc/os-release
case "${ID:-}" in
  arch|manjaro) ;;
  *) echo "Not Arch/Manjaro; skipping yay"; exit 0 ;;
esac

if command -v yay >/dev/null; then exit 0; fi
sudo pacman -S --needed --noconfirm base-devel git
git clone https://aur.archlinux.org/yay.git /tmp/yay
(cd /tmp/yay && makepkg -si --noconfirm)
