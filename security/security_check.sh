#!/bin/bash
# security_check.sh – Automatisierte Linux-Sicherheitsprüfung
# Autor: Asterios Raptis
# Version: 1.0

REPORT="/var/log/security_check_$(date +%F).log"
HOSTNAME=$(hostname)
EMAIL="deine@mailadresse.de"  # Hier eigene Mail eintragen

echo "==== Sicherheitsreport für $HOSTNAME ($(date)) ====" > "$REPORT"
echo "" >> "$REPORT"

# 1. Lynis Audit
echo "[+] Starte Lynis Audit..." >> "$REPORT"
lynis audit system --quiet --report-file /var/log/lynis-report.dat >> "$REPORT" 2>&1

# 2. Rootkit-Suche
echo "" >> "$REPORT"
echo "[+] Starte rkhunter..." >> "$REPORT"
rkhunter --update >> "$REPORT" 2>&1
rkhunter --cronjob --report-warnings-only >> "$REPORT" 2>&1

echo "" >> "$REPORT"
echo "[+] Starte chkrootkit..." >> "$REPORT"
chkrootkit >> "$REPORT" 2>&1

# 3. Offene Ports und verdächtige Prozesse
echo "" >> "$REPORT"
echo "[+] Offene Netzwerkports:" >> "$REPORT"
ss -tulpn >> "$REPORT" 2>&1

echo "" >> "$REPORT"
echo "[+] Aktive Prozesse mit Netzwerkzugriff:" >> "$REPORT"
lsof -i -n -P | grep ESTABLISHED >> "$REPORT" 2>&1

# 4. Falco-Status prüfen
if systemctl is-active --quiet falco-modern-bpf.service 2>/dev/null || \
   systemctl is-active --quiet falco-bpf.service 2>/dev/null || \
   systemctl is-active --quiet falco.service 2>/dev/null; then
    echo "" >> "$REPORT"
    echo "[+] Falco läuft – Echtzeitüberwachung aktiv" >> "$REPORT"
else
    echo "" >> "$REPORT"
    echo "[!] Falco ist NICHT aktiv – bitte prüfen!" >> "$REPORT"
fi

# 5. Firewall-Status
echo "" >> "$REPORT"
echo "[+] Firewall-Status (ufw):" >> "$REPORT"
ufw status verbose >> "$REPORT" 2>&1

# Ende
echo "" >> "$REPORT"
echo "==== Report Ende ====" >> "$REPORT"

# Optional: Mail versenden (sendmail oder mailutils nötig)
if command -v mail >/dev/null 2>&1; then
    cat "$REPORT" | mail -s "Sicherheitsreport $HOSTNAME" "$EMAIL"
fi

echo "Report gespeichert unter: $REPORT"