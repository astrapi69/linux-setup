#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/common.sh"

pm_install ufw fail2ban

# UFW configuration: Set default rules
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp || true  # allow SSH
sudo ufw --force enable

# Enable Fail2ban
sudo systemctl enable --now fail2ban