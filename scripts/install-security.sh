#!/usr/bin/env bash
# scripts/install-security.sh
# Installiert den vollständigen Security-Stack und richtet den automatisierten Report-Timer ein.

set -euo pipefail

# Basisverzeichnis ermitteln und gemeinsame Funktionen laden
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/common.sh"

log "🚀 Starte Installation des Security-Stacks..."

# Schritt 1: Installiere die Kern-Security-Tools
"$DIR/install-lynis.sh"
"$DIR/install-auditd.sh"
"$DIR/install-falco.sh"
"$DIR/install-firewall.sh"

# Schritt 2: Installiere zusätzliche Hilfs-Tools für Monitoring und Analyse
log "Installiere Hilfstools (rkhunter, chkrootkit, btop, ...)..."
pm_install rkhunter chkrootkit lsof net-tools btop glances nethogs

# Schritt 3: Kopiere die Konfigurationsdateien für die Tools
log "Kopiere Konfigurationsdateien..."

# Für Falco
sudo mkdir -p /etc/falco
sudo cp "$DIR/../security/config/falco_rules_local.yaml" /etc/falco/ || log "⚠️  Warnung: falco_rules_local.yaml nicht gefunden"
sudo systemctl restart falco 2>/dev/null || true

# Für Auditd
sudo mkdir -p /etc/audit/rules.d
sudo cp "$DIR/../security/config/audit.rules" /etc/audit/rules.d/99-linux-setup.rules || log "⚠️  Warnung: audit.rules nicht gefunden"
sudo systemctl restart auditd 2>/dev/null || true

# Für Fail2ban
sudo mkdir -p /etc/fail2ban/jail.d
sudo cp "$DIR/../security/config/fail2ban/jail.local" /etc/fail2ban/jail.d/ || log "⚠️  Warnung: fail2ban jail.local nicht gefunden"
sudo systemctl restart fail2ban 2>/dev/null || true

# Schritt 4: Installiere und aktiviere den automatisierten Security-Report-Timer
log "Richte automatisierten Security-Report ein..."

# Sicherstellen, dass das Zielverzeichnis existiert
sudo install -d /usr/local/bin

# Skript und Systemd-Units kopieren
sudo install -m 0755 "$DIR/../security/security_check.sh" /usr/local/bin/security_check.sh
sudo install -m 0644 "$DIR/../security/systemd/security-check.service" /etc/systemd/system/
sudo install -m 0644 "$DIR/../security/systemd/security-check.timer"   /etc/systemd/system/

# Logrotate-Konfiguration für die Reports
sudo install -m 0644 "$DIR/../etc/logrotate.d/linux-setup" /etc/logrotate.d/linux-setup 2>/dev/null || log "ℹ️  Hinweis: Logrotate-Konfiguration nicht gefunden (optional)."

# Systemd neu laden und Timer aktivieren
sudo systemctl daemon-reload
sudo systemctl enable --now security-check.timer

log "✅ Installation des Security-Stacks abgeschlossen."
log "Der wöchentliche Report wird automatisch generiert. Erster Lauf: $(sudo systemctl list-timers security-check.timer --no-pager | tail -n +2 | awk '{print $2}')"
log "Manueller Test: sudo /usr/local/bin/security_check.sh"