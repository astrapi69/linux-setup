#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/common.sh"

pm_install ufw fail2ban

# UFW-Konfiguration: Standardregeln setzen
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp || true  # SSH erlauben
sudo ufw --force enable

# Fail2ban aktivieren
sudo systemctl enable --now fail2ban