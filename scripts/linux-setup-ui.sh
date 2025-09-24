#!/usr/bin/env bash
set -euo pipefail

# linux-setup-ui.sh — TUI for linux-setup: verify, install, and manage security stack
# Requires: whiptail (or dialog), jq
# Uses your repo scripts: init_scripts.sh, verify-security-json.sh, install-*.sh

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SCRIPT_DIR"

# Source init (logging + $OS)
if [[ -f "./init_scripts.sh" ]]; then
  # shellcheck disable=SC1091
  source "./init_scripts.sh"
else
  echo "[ERROR] init_scripts.sh not found next to this script." >&2
  exit 1
fi

# Ensure deps
need_cmd() { command -v "$1" >/dev/null 2>&1 || return 1; }
die() { echo "[ERROR] $*" >&2; exit 1; }

WHIPTAIL_BIN=""
if need_cmd whiptail; then WHIPTAIL_BIN="whiptail"
elif need_cmd dialog; then WHIPTAIL_BIN="dialog"
else
  die "whiptail or dialog is required. Install 'whiptail' (newt) or 'dialog'."
fi

# jq is used to read JSON report; offer to install
if ! need_cmd jq; then
  if "$WHIPTAIL_BIN" --yesno "jq is required to parse JSON reports. Install jq now?" 10 60; then
    if [[ -x "./install-jq.sh" ]]; then
      bash ./install-jq.sh || die "jq installation failed"
    else
      die "install-jq.sh not found. Please run your package manager to install jq."
    fi
  else
    :
  fi
fi

JSON_DEFAULT="${HOME}/tmp/linux_setup_security_report.json"

# Helpers
run_cmd() {
  local title="$1"; shift
  local cmd=("$@")
  local output
  if output="$("${cmd[@]}" 2>&1)"; then
    "$WHIPTAIL_BIN" --title "$title" --msgbox "$output" 20 100
  else
    "$WHIPTAIL_BIN" --title "$title (FAILED)" --msgbox "$output" 20 100
  fi
}

tail_file_box() {
  local title="$1" file="$2"
  if [[ -s "$file" ]]; then
    "$WHIPTAIL_BIN" --title "$title" --textbox "$file" 25 100
  else
    "$WHIPTAIL_BIN" --title "$title" --msgbox "File not found or empty:\n$file" 12 80
  fi
}

# Actions
action_verify_security() {
  local json_out="$JSON_DEFAULT"
  if "$WHIPTAIL_BIN" --yesno "Run verify-security-json.sh now?\n\nJSON will be written to:\n${json_out}\n\nProceed?" 15 70; then
    run_cmd "Verify Security" bash ./verify-security-json.sh --json-out "$json_out"
  fi
}

action_show_summary() {
  local json="${JSON_DEFAULT}"
  if [[ ! -s "$json" ]]; then
    "$WHIPTAIL_BIN" --msgbox "No JSON found at:\n${json}\n\nRun 'Verify Security' first." 12 70
    return
  fi

  # Build a quick summary using jq (with symbols)
  local summary
  summary="$(
    jq -r '
      def join(xs): (xs | join(" "));
      "OS: \(.os)  |  PM: \(.package_manager)",
      "",
      (if (.packages.missing|length)>0 then "❌ Missing packages: " + ((.packages.missing) | join(" ")) else "✅ Packages OK" end),
      (if (.binaries.missing|length)>0 then "⚠ Missing binaries: " + ((.binaries.missing) | join(" ")) else "✅ Binaries OK" end),
      (if (.services.running|length)>0 then "✅ Running services: " + ((.services.running) | join(" ")) else "⚠ Running services: none" end),
      (if (.services.stopped|length)>0 then "❌ Stopped services: " + ((.services.stopped) | join(" ")) else "✅ No stopped services" end),
      (if (.services.not_installed|length)>0 then "⚠ Not installed services: " + ((.services.not_installed) | join(" ")) else "✅ All services present" end),
      "",
      "Falco rules validation: \(.falco_rules_validation)",
      "",
      "Install command:",
      (.commands.install_packages // "—")
    ' "$json"
  )" || summary="Failed to parse JSON with jq."

  "$WHIPTAIL_BIN" --title "Security Summary" --msgbox "$summary" 25 100
}

action_apply_install_cmd() {
  local json="${JSON_DEFAULT}"
  if [[ ! -s "$json" ]]; then
    "$WHIPTAIL_BIN" --msgbox "No JSON found at:\n${json}\n\nRun 'Verify Security' first." 12 70
    return
  fi
  local cmd
  cmd="$(jq -r '.commands.install_packages // empty' "$json")" || cmd=""
  if [[ -z "$cmd" ]]; then
    "$WHIPTAIL_BIN" --msgbox "No install_packages command in JSON.\nEverything may already be installed." 12 70
    return
  fi
  if "$WHIPTAIL_BIN" --yesno "Run package install?\n\n${cmd}" 15 90; then
    run_cmd "Install Missing Packages" bash -lc "$cmd"
  fi
}

action_enable_start_services() {
  local json="${JSON_DEFAULT}"
  if [[ ! -s "$json" ]]; then
    "$WHIPTAIL_BIN" --msgbox "No JSON found at:\n${json}\n\nRun 'Verify Security' first." 12 70
    return
  fi

  local enables starts
  enables="$(jq -r '.commands.enable_services[]? ' "$json" 2>/dev/null || true)"
  starts="$(jq -r '.commands.start_services[]? ' "$json" 2>/dev/null || true)"

  if [[ -z "$enables$starts" ]]; then
    "$WHIPTAIL_BIN" --msgbox "No service actions needed." 10 60
    return
  fi

  if [[ -n "$enables" ]]; then
    if "$WHIPTAIL_BIN" --yesno "Enable services now?\n\n$(echo "$enables" | sed 's/^/ - /')" 20 90; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        run_cmd "Enable Service" bash -lc "$line"
      done <<< "$enables"
    fi
  fi

  if [[ -n "$starts" ]]; then
    if "$WHIPTAIL_BIN" --yesno "Start services now?\n\n$(echo "$starts" | sed 's/^/ - /')" 20 90; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        run_cmd "Start Service" bash -lc "$line"
      done <<< "$starts"
    fi
  fi
}

action_install_stack() {
  if "$WHIPTAIL_BIN" --yesno "Install full security stack now?\n\nThis runs:\n - install-jq.sh (if needed)\n - install-lynis.sh\n - install-auditd.sh\n - install-falco.sh\n - install-firewall.sh\n - pm_install rkhunter chkrootkit ...\n - install security-check timer" 18 90; then
    run_cmd "Install Security Stack" bash ./install-security.sh
  fi
}

action_install_single() {
  local choice
  choice=$("$WHIPTAIL_BIN" --title "Install Single Component" --menu "Select component to install:" 20 70 10 \
    "jq"           "JSON processor (helper)" \
    "ufw"          "Firewall (Uncomplicated Firewall)" \
    "fail2ban"     "Intrusion prevention (fail2ban-client)" \
    "chkrootkit"   "Rootkit scanner (AUR on Arch)" \
    "rkhunter"     "Rootkit Hunter" \
    "lynis"        "Security audit tool" \
    "falco"        "Runtime threat detection" \
    "auditd"       "Linux audit daemon" \
    "mailutils"    "Email for reports (Debian/Ubuntu)" \
    "back"         "Back to main menu" 3>&1 1>&2 2>&3) || return

  case "$choice" in
    jq)         [[ -x ./install-jq.sh ]]         && run_cmd "Install jq"         bash ./install-jq.sh         || die "install-jq.sh missing" ;;
    ufw)        [[ -x ./install-ufw.sh ]]        && run_cmd "Install ufw"        bash ./install-ufw.sh        || die "install-ufw.sh missing" ;;
    fail2ban)   [[ -x ./install-fail2ban.sh ]]   && run_cmd "Install fail2ban"   bash ./install-fail2ban.sh   || die "install-fail2ban.sh missing" ;;
    chkrootkit) [[ -x ./install-chkrootkit.sh ]] && run_cmd "Install chkrootkit" bash ./install-chkrootkit.sh || die "install-chkrootkit.sh missing" ;;
    rkhunter)   [[ -x ./install-rootkit-rkhunter.sh ]] && run_cmd "Install rkhunter" bash ./install-rootkit-rkhunter.sh || die "install-rootkit-rkhunter.sh missing" ;;
    lynis)      [[ -x ./install-lynis.sh ]]      && run_cmd "Install lynis"      bash ./install-lynis.sh      || die "install-lynis.sh missing" ;;
    falco)      [[ -x ./install-falco.sh ]]      && run_cmd "Install falco"      bash ./install-falco.sh      || die "install-falco.sh missing" ;;
    auditd)     [[ -x ./install-auditd.sh ]]     && run_cmd "Install auditd"     bash ./install-auditd.sh     || die "install-auditd.sh missing" ;;
    mailutils)  [[ -x ./install-mailutils.sh ]]  && run_cmd "Install mailutils"  bash ./install-mailutils.sh  || run_cmd "Install mailutils" bash -lc 'echo "No helper script. Using package manager..."; if command -v apt-get>/dev/null; then sudo apt-get update && sudo apt-get install -y mailutils; elif command -v pacman>/dev/null; then echo "mailutils not available on Arch; skipping"; else echo "Unsupported OS"; fi' ;;
    back) : ;;
  esac
}

action_services_menu() {
  local choice
  choice=$("$WHIPTAIL_BIN" --title "Services" --menu "Service actions" 18 70 10 \
    "status"  "Show status of key services" \
    "start"   "Start a service" \
    "stop"    "Stop a service" \
    "enable"  "Enable a service at boot" \
    "disable" "Disable a service at boot" \
    "back"    "Back to main menu" 3>&1 1>&2 2>&3) || return

  local svc
  case "$choice" in
    status)
      run_cmd "Services Status" bash -lc 'systemctl --no-pager --plain status falco.service falco-bpf.service falco-modern-bpf.service auditd.service fail2ban.service 2>&1'
      ;;
    start|stop|enable|disable)
      svc=$("$WHIPTAIL_BIN" --inputbox "Enter systemd unit (e.g., fail2ban.service):" 10 70 "" 3>&1 1>&2 2>&3) || return
      [[ -z "$svc" ]] && return
      run_cmd "systemctl $choice $svc" bash -lc "sudo systemctl $choice \"$svc\""
      ;;
    back) : ;;
  esac
}

action_logs_menu() {
  local choice
  choice=$("$WHIPTAIL_BIN" --title "Logs & Reports" --menu "View logs" 18 70 10 \
    "security_report" "Show last weekly security report (if exists)" \
    "falco"           "journalctl -u falco*" \
    "fail2ban"        "journalctl -u fail2ban" \
    "auditd"          "journalctl -u auditd" \
    "back"            "Back to main menu" 3>&1 1>&2 2>&3) || return

  case "$choice" in
    security_report)
      # Show most recent linux-setup report
      local last
      last="$(ls -1 /var/log/linux-setup/security_check_*.log 2>/dev/null | tail -n1 || true)"
      if [[ -n "$last" ]]; then
        tail_file_box "Security Report: $(basename "$last")" "$last"
      else
        "$WHIPTAIL_BIN" --msgbox "No reports found in /var/log/linux-setup/ yet.\nRun the report script:\n  sudo /usr/local/bin/security_check.sh" 12 90
      fi
      ;;
    falco)    run_cmd "Falco logs"    bash -lc 'journalctl -u "falco*" --no-pager -n 300' ;;
    fail2ban) run_cmd "Fail2ban logs" bash -lc 'journalctl -u fail2ban --no-pager -n 300' ;;
    auditd)   run_cmd "auditd logs"   bash -lc 'journalctl -u auditd --no-pager -n 300' ;;
    back) : ;;
  esac
}

action_validate_falco_rules() {
  local rule="/etc/falco/falco_rules.local.yaml"
  if [[ ! -f "$rule" ]]; then
    "$WHIPTAIL_BIN" --msgbox "Local Falco rules not found:\n$rule" 10 70
    return
  fi
  run_cmd "Falco Rules Validation" bash -lc "falco --validate \"$rule\""
}

# Main loop
while true; do
  CHOICE=$("$WHIPTAIL_BIN" --title "linux-setup TUI" --menu "Select an action:" 20 80 12 \
    "verify"     "Run pre-install security verification (JSON)" \
    "summary"    "Show last JSON summary (pretty)" \
    "apply"      "Apply fixes (install missing packages, enable/start services)" \
    "install"    "Install full security stack" \
    "single"     "Install a single component" \
    "services"   "Service actions (status/start/stop/enable/disable)" \
    "logs"       "View security/falco/fail2ban logs" \
    "falco-val"  "Validate local Falco rules" \
    "exit"       "Quit" 3>&1 1>&2 2>&3) || exit 0

  case "$CHOICE" in
    verify)   action_verify_security ;;
    summary)  action_show_summary ;;
    apply)    action_apply_install_cmd; action_enable_start_services ;;
    install)  action_install_stack ;;
    single)   action_install_single ;;
    services) action_services_menu ;;
    logs)     action_logs_menu ;;
    falco-val)action_validate_falco_rules ;;
    exit)     exit 0 ;;
  esac
done
