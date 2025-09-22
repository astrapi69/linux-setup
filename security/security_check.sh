#!/usr/bin/env bash
set -euo pipefail

# Configuration
REPORT_DIR="/var/log/linux-setup"
mkdir -p "$REPORT_DIR" 2>/dev/null || true
STAMP="$(date +%F_%H%M%S)"
REPORT="$REPORT_DIR/security_check_${STAMP}.log"

# Load optional environment config
SECURITY_ENV="/etc/linux-setup/security.env"
if [[ -f "$SECURITY_ENV" ]]; then
    source "$SECURITY_ENV"
fi

# Helper functions
section() { printf "\n===== %s =====\n" "$1" >&2; }
have()    { command -v "$1" >/dev/null 2>&1; }

# Start report
{
    echo "==== Security Report: $(hostname) — $(date -Is) ===="

    section "LYNIS SYSTEM AUDIT"
    if have lynis; then
        lynis audit system --quiet --report-file /var/log/lynis-report.dat 2>/dev/null || true
        if [[ -f /var/log/lynis-report.dat ]]; then
            tail -n +1 /var/log/lynis-report.dat 2>/dev/null | sed 's/^/[lynis] /'
        else
            echo "[lynis] Report file not found."
        fi
    else
        echo "[!] Lynis not installed. Skipping audit."
    fi

    section "RKHUNTER SCAN"
    if have rkhunter; then
        rkhunter --update --nocolors 2>/dev/null || true
        rkhunter --cronjob --report-warnings-only --nocolors 2>/dev/null || true
    else
        echo "[!] rkhunter not installed. Skipping scan."
    fi

    section "CHKROOTKIT SCAN"
    if have chkrootkit; then
        chkrootkit 2>/dev/null || true
    else
        echo "[!] chkrootkit not installed. Skipping scan."
    fi

    section "NETWORK: OPEN PORTS (ss)"
    if have ss; then
        # Use --no-header if available, else fall back to tail
        if ss --help 2>&1 | grep -q -- '--no-header'; then
            ss --no-header -tulpn 2>/dev/null || echo "[ss] No open ports or error occurred."
        else
            ss -tulpn 2>/dev/null | tail -n +2 || echo "[ss] No open ports or error occurred."
        fi
    else
        echo "[!] 'ss' command not found. Install 'iproute2'."
    fi

    section "PROCESSES WITH NETWORK CONNECTIONS (lsof)"
    if have lsof; then
        lsof -n -P -i 2>/dev/null | grep -E "(ESTABLISHED|SYN_SENT)" || echo "[lsof] No active connections found."
    else
        echo "[!] 'lsof' not installed. Skipping network process check."
    fi

    section "FIREWALL STATUS (ufw)"
    if have ufw; then
        ufw status verbose 2>/dev/null || echo "[ufw] Status command failed."
    else
        echo "[!] UFW not installed. Skipping firewall check."
    fi

    section "FALCO STATUS & RECENT ALERTS"
    FALCO_ACTIVE=false
    for unit in falco-modern-bpf.service falco-bpf.service falco.service; do
        if systemctl is-enabled "$unit" >/dev/null 2>&1 && systemctl is-active "$unit" >/dev/null 2>&1; then
            echo "[systemd] Active Falco unit: $unit"
            FALCO_ACTIVE=true
            break
        fi
    done

    if [[ "$FALCO_ACTIVE" == false ]]; then
        echo "[!] Falco is not active. Please check installation."
    else
        # Fetch recent Falco alerts based on minimum severity
        MIN_LEVEL="${FALCO_MIN_LEVEL:-WARNING}"
        echo "[falco] Recent alerts (min level: $MIN_LEVEL) from last 24 hours:"
        journalctl -u falco-modern-bpf.service -u falco-bpf.service -u falco.service --since "24 hours ago" --no-pager 2>/dev/null | \
        awk -v min_level="$MIN_LEVEL" '
        BEGIN {
            levels = "INFO,WARNING,ERROR,CRITICAL"
            split(levels, level_array, ",")
            min_index = 0
            for (i in level_array) {
                if (level_array[i] == min_level) {
                    min_index = i
                    break
                }
            }
        }
        {
            for (i = min_index; i <= length(level_array); i++) {
                if ($0 ~ "\\[" level_array[i] "\\]") {
                    print
                    next
                }
            }
        }' || echo "[falco] No alerts found at or above level $MIN_LEVEL."
    fi

    section "END OF REPORT"
} | tee "$REPORT" >/dev/null

# Optional: Send report via email
if [[ -n "${EMAIL:-}" ]] && have mail; then
    echo "📧 Sending report to: $EMAIL"
    mail -s "Security Report: $(hostname) - $STAMP" "$EMAIL" < "$REPORT" 2>/dev/null || echo "[!] Failed to send email. Check 'mail' configuration."
fi

echo "✅ Report saved to: $REPORT"