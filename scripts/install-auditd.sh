#!/usr/bin/env bash
# scripts/install-auditd.sh
# Installs and enables auditd for system auditing.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/common.sh"

log "Installing auditd..."

case "$(pm)" in
    pacman)
        pm_install audit
        ;;
    apt)
        pm_install auditd audispd-plugins
        ;;
    *)
        log "Unsupported package manager for auditd installation."
        exit 1
        ;;
esac

# Enable and start the service
sudo systemctl enable --now auditd 2>/dev/null || true

# Copy custom rules if they exist
if [ -f "$DIR/../security/config/audit.rules" ]; then
    sudo mkdir -p /etc/audit/rules.d
    sudo cp "$DIR/../security/config/audit.rules" /etc/audit/rules.d/99-linux-setup.rules
    sudo systemctl restart auditd 2>/dev/null || true
    log "✅ Custom audit rules deployed."
fi

log "✅ auditd installed and enabled."