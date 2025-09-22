#!/usr/bin/env bash
# scripts/install-security.sh
# Master script to install the full security stack.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/common.sh"

log "🚀 Starting installation of the Security Stack..."

# Step 1: Install core security tools
"$DIR/install-lynis.sh"
"$DIR/install-auditd.sh"
"$DIR/install-falco.sh"
"$DIR/install-firewall.sh"

# Step 2: Install additional helper tools
log "Installing helper tools (rkhunter, chkrootkit, btop, ...)..."
pm_install rkhunter chkrootkit lsof net-tools btop glances nethogs

# Step 3: Install and enable the automated security report timer
log "Setting up automated security reporting..."

# Ensure target directory exists
sudo install -d /usr/local/bin

# Copy the report script and systemd units
sudo install -m 0755 "$DIR/../security/security_check.sh" /usr/local/bin/security_check.sh
sudo install -m 0644 "$DIR/../security/systemd/security-check.service" /etc/systemd/system/
sudo install -m 0644 "$DIR/../security/systemd/security-check.timer"   /etc/systemd/system/

# Install logrotate configuration
sudo install -m 0644 "$DIR/../etc/logrotate.d/linux-setup" /etc/logrotate.d/linux-setup 2>/dev/null || log "ℹ️  Logrotate config not found (optional)."

# Reload systemd and enable the timer
sudo systemctl daemon-reload
sudo systemctl enable --now security-check.timer

log "✅ Security Stack installation completed."
log "📅 First automated report scheduled for: $(sudo systemctl list-timers security-check.timer --no-pager | tail -n +2 | awk '{print $2}')"
log "🧪 Manual test: sudo /usr/local/bin/security_check.sh"