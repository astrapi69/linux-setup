#!/usr/bin/env bash
# scripts/install-firewall.sh
# Installs and configures UFW and Fail2ban.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/common.sh"

log "Installing UFW and Fail2ban..."

pm_install ufw fail2ban

# Configure UFW
log "Configuring UFW firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'Allow SSH' || true
sudo ufw --force enable

# Configure Fail2ban
log "Configuring Fail2ban..."
sudo systemctl enable --now fail2ban 2>/dev/null || true

# Copy custom jail configuration if it exists
if [ -f "$DIR/../security/config/fail2ban/jail.local" ]; then
    sudo mkdir -p /etc/fail2ban/jail.d
    sudo cp "$DIR/../security/config/fail2ban/jail.local" /etc/fail2ban/jail.d/
    sudo systemctl restart fail2ban 2>/dev/null || true
    log "✅ Custom Fail2ban configuration deployed."
fi

log "✅ Firewall (UFW) and Fail2ban installed and configured."