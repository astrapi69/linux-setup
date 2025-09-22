#!/usr/bin/env bash
# scripts/install-security.sh
# Installs the full security stack and sets up the automated report timer.

set -euo pipefail

# Determine base directory and load common functions
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/common.sh"

log "🚀 Start installing the security stack..."

# Step 1: Install the core security tools
"$DIR/install-lynis.sh"
"$DIR/install-auditd.sh"
"$DIR/install-falco.sh"
"$DIR/install-firewall.sh"

# Step 2: Install additional tools for monitoring and analysis
log "Install helper tools (rkhunter, chkrootkit, btop, ...)..."
pm_install rkhunter chkrootkit lsof net-tools btop glances nethogs

# Step 3: Copy the configuration files for the tools
log "Copy configuration files..."

# for Falco
sudo mkdir -p /etc/falco
sudo cp "$DIR/../security/config/falco_rules_local.yaml" /etc/falco/ || log "⚠️  Warning: falco_rules_local.yaml not found"
sudo systemctl restart falco 2>/dev/null || true

# for Auditd
sudo mkdir -p /etc/audit/rules.d
sudo cp "$DIR/../security/config/audit.rules" /etc/audit/rules.d/99-linux-setup.rules || log "⚠️  Warning: audit.rules not found"
sudo systemctl restart auditd 2>/dev/null || true

# for Fail2ban
sudo mkdir -p /etc/fail2ban/jail.d
sudo cp "$DIR/../security/config/fail2ban/jail.local" /etc/fail2ban/jail.d/ || log "⚠️  Warning: fail2ban jail.local not found"
sudo systemctl restart fail2ban 2>/dev/null || true

# Step 4: Install and enable the automated security report timer
log "Richte automatisierten Security-Report ein..."

# Ensure that the target directory exists
sudo install -d /usr/local/bin

# Copy script and systemd units
sudo install -m 0755 "$DIR/../security/security_check.sh" /usr/local/bin/security_check.sh
sudo install -m 0644 "$DIR/../security/systemd/security-check.service" /etc/systemd/system/
sudo install -m 0644 "$DIR/../security/systemd/security-check.timer"   /etc/systemd/system/

# Logrotate configuration for the reports
sudo install -m 0644 "$DIR/../etc/logrotate.d/linux-setup" /etc/logrotate.d/linux-setup 2>/dev/null || log "ℹ️  Note: Logrotate configuration not found (optional)."

# Reload systemd and enable timer
sudo systemctl daemon-reload
sudo systemctl enable --now security-check.timer

log "✅ Installation of the security stack completed."
log "The weekly report is generated automatically. First run: $(sudo systemctl list-timers security-check.timer --no-pager | tail -n +2 | awk '{print $2}')"
log "Manual test: sudo /usr/local/bin/security_check.sh"