#!/bin/bash
# security_check.sh – Automated Linux Security Audit
# Author: Asterios Raptis
# Version: 1.1 (Enhanced for production use)

set -euo pipefail

REPORT="/var/log/security_check_$(date +%F).log"
HOSTNAME=$(hostname)
EMAIL="your@email.com"  # <-- REPLACE THIS WITH YOUR EMAIL

# Ensure log directory exists
sudo mkdir -p /var/log

# Start report
{
    echo "==== Security Report for $HOSTNAME ($(date)) ===="
    echo ""
} > "$REPORT"

log_section() {
    echo "" >> "$REPORT"
    echo "[+] $1" >> "$REPORT"
    echo "----------------------------------------" >> "$REPORT"
}

log_error() {
    echo "[!] $1" >> "$REPORT"
}

# 1. Lynis System Audit
log_section "Running Lynis Audit..."
if command -v lynis >/dev/null; then
    lynis audit system --quiet --report-file /var/log/lynis-report.dat 2>&1 | tee -a "$REPORT"
else
    log_error "Lynis not installed. Skipping audit."
fi

# 2. Rootkit Scans
log_section "Running rkhunter..."
if command -v rkhunter >/dev/null; then
    rkhunter --update 2>&1 | tee -a "$REPORT"
    rkhunter --cronjob --report-warnings-only 2>&1 | tee -a "$REPORT"
else
    log_error "rkhunter not installed. Skipping scan."
fi

log_section "Running chkrootkit..."
if command -v chkrootkit >/dev/null; then
    chkrootkit 2>&1 | tee -a "$REPORT"
else
    log_error "chkrootkit not installed. Skipping scan."
fi

# 3. Network & Process Inspection
log_section "Listing Open Network Ports..."
if command -v ss >/dev/null; then
    ss -tulpn 2>&1 | tee -a "$REPORT"
else
    log_error "ss command not available. Install iproute2."
fi

log_section "Active Processes with Network Connections..."
if command -v lsof >/dev/null; then
    lsof -i -n -P 2>&1 | grep ESTABLISHED | tee -a "$REPORT"
else
    log_error "lsof not installed. Skipping process network check."
fi

# 4. Falco Status Check (Check all possible service names)
log_section "Checking Falco Status..."
FALCO_ACTIVE=false
for svc in falco-modern-bpf.service falco-bpf.service falco.service; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo "✅ Falco is running (active service: $svc)" >> "$REPORT"
        FALCO_ACTIVE=true
        break
    fi
done

if [ "$FALCO_ACTIVE" = false ]; then
    log_error "Falco is NOT running. Please check installation and service status."
    echo "Suggested command: sudo systemctl status falco-modern-bpf.service falco-bpf.service falco.service" >> "$REPORT"
fi

# 5. Firewall Status (UFW)
log_section "Firewall Status (UFW)..."
if command -v ufw >/dev/null; then
    ufw status verbose 2>&1 | tee -a "$REPORT"
else
    log_error "UFW not installed or not available."
fi

# Finalize report
{
    echo ""
    echo "==== End of Report ===="
} >> "$REPORT"

# Optional: Send report via email
if command -v mail >/dev/null 2>&1 && [ "$EMAIL" != "your@email.com" ]; then
    echo "📧 Sending report to $EMAIL..."
    cat "$REPORT" | mail -s "Security Report for $HOSTNAME" "$EMAIL"
elif [ "$EMAIL" = "your@email.com" ]; then
    echo "ℹ️  Email notification configured but placeholder email 'your@email.com' still in use. Please update."
fi

echo "✅ Report saved to: $REPORT"
echo "To view: less $REPORT"