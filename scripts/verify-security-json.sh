#!/usr/bin/env bash
set -euo pipefail

# verify-security-json.sh — Checks packages, services, Falco rules
# and writes a machine-readable JSON summary with ready-to-run fix commands.
#
# Usage:
#   bash scripts/verify-security-json.sh [--json-out /path/to/report.json]
#
# Works on Manjaro/Arch (pacman) and Debian/Ubuntu (apt/dpkg).

# ---------- Pretty output ----------
COLOR_OK="\033[32m"; COLOR_WARN="\033[33m"; COLOR_ERR="\033[31m"; COLOR_DIM="\033[90m"; COLOR_OFF="\033[0m"
ok()   { printf "${COLOR_OK}✔${COLOR_OFF} %s\n" "$*"; }
warn() { printf "⚠ ${COLOR_WARN}%s${COLOR_OFF}\n" "$*"; }
err()  { printf "✘ ${COLOR_ERR}%s${COLOR_OFF}\n" "$*"; }
dim()  { printf "${COLOR_DIM}%s${COLOR_OFF}\n" "$*"; }

# ---------- Args ----------
JSON_OUT="${HOME}/tmp/linux_setup_security_report.json"
if [[ "${1:-}" == "--json-out" ]] && [[ -n "${2:-}" ]]; then
  JSON_OUT="$2"
fi
JSON_DIR="$(dirname -- "$JSON_OUT")"
mkdir -p -- "$JSON_DIR"

# Need python3 to emit JSON safely
if ! command -v python3 >/dev/null 2>&1; then
  err "python3 not found; cannot write JSON. Install python3 and rerun."
  exit 3
fi

# ---------- Helpers ----------
has()   { command -v "$1" >/dev/null 2>&1; }
os_id() { . /etc/os-release 2>/dev/null || true; echo "${ID:-unknown}"; }

pm_detect() {
  if has pacman; then echo pacman; return; fi
  if has apt-get && has dpkg; then echo apt; return; fi
  echo unknown
}

pm="$(pm_detect)"
distro="$(os_id)"

pkg_installed() {
  case "$pm" in
    pacman) pacman -Qi "$1" >/dev/null 2>&1 ;;
    apt)    dpkg -s "$1"    >/dev/null 2>&1 ;;
    *)      return 1 ;;
  esac
}
pkg_version() {
  case "$pm" in
    pacman) pacman -Qi "$1" 2>/dev/null | awk -F': *' '/^Version/{print $2; exit}' ;;
    apt)    dpkg -s "$1"    2>/dev/null | awk -F': *' '/^Version/{print $2; exit}' ;;
    *)      echo "" ;;
  esac
}
suggest_install_line() {
  case "$pm" in
    pacman) echo "sudo pacman -S --needed $*" ;;
    apt)    echo "sudo apt-get update && sudo apt-get install -y $*" ;;
    *)      echo "# Unsupported package manager" ;;
  esac
}

# ---------- Targets ----------
declare -a PKGS_BASE=(lynis rkhunter chkrootkit ufw fail2ban lsof iproute2 logrotate mailutils falco)
case "$pm" in
  pacman) PKG_AUDIT=(audit) ;;
  apt)    PKG_AUDIT=(auditd audispd-plugins) ;;
  *)      PKG_AUDIT=() ;;
esac
PKGS=("${PKGS_BASE[@]}" "${PKG_AUDIT[@]}")

SERVICES=(
  falco.service
  falco-bpf.service
  falco-modern-bpf.service
  auditd.service
  fail2ban.service
  security-check.timer
)

BINARIES=(falco lynis rkhunter chkrootkit ufw fail2ban-client auditctl ss lsof mail)

# ---------- Accumulators ----------
ok_pkgs=()
missing_pkgs=()
ok_bins=()
missing_bins=()
services_running=()
services_stopped=()
services_notfound=()
falco_rules_validation="skipped"

# ---------- Header ----------
echo "== linux-setup security verification =="
echo "OS: $distro   PM: $pm"
echo

# ---------- Packages ----------
echo "== Checking packages =="
if [[ "$pm" == "unknown" ]]; then
  err "Unsupported distro (need pacman or apt)"
else
  for p in "${PKGS[@]}"; do
    if pkg_installed "$p"; then
      v="$(pkg_version "$p")"
      ok_pkgs+=("${p}${v:+@$v}")
      ok "$p installed${v:+ (version $v)}"
    else
      missing_pkgs+=("$p")
      err "$p missing"
    fi
  done
  if ((${#missing_pkgs[@]})); then
    echo
    warn "Install missing packages with:"
    echo "$(suggest_install_line "${missing_pkgs[@]}")"
  fi
fi
echo

# ---------- Binaries ----------
echo "== Checking key binaries =="
for b in "${BINARIES[@]}"; do
  if has "$b"; then ok_bins+=("$b"); ok "$b found"; else missing_bins+=("$b"); warn "$b not found in PATH"; fi
done
echo

# ---------- Services ----------
echo "== Checking services =="
for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files "$svc" >/dev/null 2>&1; then
    if systemctl is-active --quiet "$svc"; then
      services_running+=("$svc")
      ok "$svc is running"
    else
      services_stopped+=("$svc")
      err "$svc is not running"
    fi
  else
    services_notfound+=("$svc")
    warn "$svc not installed"
  fi
done
echo

# ---------- Falco rules validation ----------
echo "== Validating Falco local rules =="
RULE="/etc/falco/falco_rules.local.yaml"
if has falco; then
  if [[ -f "$RULE" ]]; then
    if falco --validate "$RULE" >/dev/null 2>&1; then
      falco_rules_validation="ok"
      ok "Falco local rules validate ($RULE)"
    else
      falco_rules_validation="failed"
      err "Falco rule validation failed ($RULE)"
      falco --validate "$RULE" || true
    fi
  else
    falco_rules_validation="no_rules"
    warn "No local rules at $RULE (optional)"
  fi
else
  falco_rules_validation="no_falco"
  warn "Falco binary not present; skipping validation"
fi
echo

# ---------- Summary ----------
echo "== Summary =="
((${#ok_pkgs[@]}))          && ok   "Installed packages: ${ok_pkgs[*]}"
((${#missing_pkgs[@]}))     && err  "Missing packages: ${missing_pkgs[*]}"
((${#ok_bins[@]}))          && ok   "Binaries present: ${ok_bins[*]}"
((${#missing_bins[@]}))     && warn "Missing binaries: ${missing_bins[*]}"
((${#services_running[@]})) && ok   "Running services: ${services_running[*]}"
((${#services_stopped[@]})) && err  "Stopped services: ${services_stopped[*]}"
((${#services_notfound[@]}))&& warn "Not installed services: ${services_notfound[*]}"

# ---------- Build fix commands ----------
install_cmd=""
enable_cmds=()
start_cmds=()
if ((${#missing_pkgs[@]})); then
  install_cmd="$(suggest_install_line "${missing_pkgs[@]}")"
fi
for s in "${services_stopped[@]}"; do
  enable_cmds+=("sudo systemctl enable $s")
  start_cmds+=("sudo systemctl start $s")
done

# ---------- Emit JSON via python (temp files, no NUL pitfalls) ----------
TMPDIR="$(mktemp -d)"
cleanup() { rm -rf -- "$TMPDIR"; }
trap cleanup EXIT

write_list() { : >"$1"; shift || true; for item in "$@"; do printf '%s\n' "$item" >>"$1"; done; }

printf '%s' "$distro" > "$TMPDIR/distro.txt"
printf '%s' "$pm"     > "$TMPDIR/pm.txt"

write_list "$TMPDIR/ok_pkgs.txt"          "${ok_pkgs[@]}"
write_list "$TMPDIR/missing_pkgs.txt"     "${missing_pkgs[@]}"
write_list "$TMPDIR/ok_bins.txt"          "${ok_bins[@]}"
write_list "$TMPDIR/missing_bins.txt"     "${missing_bins[@]}"
write_list "$TMPDIR/services_running.txt" "${services_running[@]}"
write_list "$TMPDIR/services_stopped.txt" "${services_stopped[@]}"
write_list "$TMPDIR/services_none.txt"    "${services_notfound[@]}"

printf '%s' "$falco_rules_validation" > "$TMPDIR/falco_val.txt"
printf '%s' "$install_cmd"            > "$TMPDIR/install_cmd.txt"
write_list "$TMPDIR/enable_cmds.txt"  "${enable_cmds[@]}"
write_list "$TMPDIR/start_cmds.txt"   "${start_cmds[@]}"

python3 - "$JSON_OUT" "$TMPDIR" <<'PY'
import json, sys, os

out_path = sys.argv[1]
tmpdir   = sys.argv[2]

def read_str(name):
    p = os.path.join(tmpdir, name)
    try:
        with open(p, 'r', encoding='utf-8') as f:
            return f.read().replace('\r', '').strip()
    except FileNotFoundError:
        return ""

def read_list(name):
    p = os.path.join(tmpdir, name)
    if not os.path.exists(p):
        return []
    with open(p, 'r', encoding='utf-8', errors='replace') as f:
        return [line.rstrip('\n') for line in f if line.rstrip('\n') != ""]

doc = {
  "os":               read_str("distro.txt"),
  "package_manager":  read_str("pm.txt"),
  "packages": {
    "installed": read_list("ok_pkgs.txt"),
    "missing":   read_list("missing_pkgs.txt"),
  },
  "binaries": {
    "present": read_list("ok_bins.txt"),
    "missing": read_list("missing_bins.txt"),
  },
  "services": {
    "running":       read_list("services_running.txt"),
    "stopped":       read_list("services_stopped.txt"),
    "not_installed": read_list("services_none.txt"),
  },
  "falco_rules_validation": read_str("falco_val.txt") or "skipped",
  "commands": {
    "install_packages": (read_str("install_cmd.txt") or None),
    "enable_services":  read_list("enable_cmds.txt"),
    "start_services":   read_list("start_cmds.txt"),
  }
}

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(doc, f, ensure_ascii=False, indent=2)
PY

if [[ -s "$JSON_OUT" ]]; then
  ok "JSON written to: $JSON_OUT"
else
  err "Failed to write JSON to: $JSON_OUT"
  exit 2
fi

# ---------- Exit code ----------
rc=0
if ((${#missing_pkgs[@]})) || ((${#services_stopped[@]})); then
  rc=1
fi
exit "$rc"
