#!/usr/bin/env bash
# scripts/common.sh
# Shared functions for distro detection, logging, and package management.

set -euo pipefail

# Logging function
log() {
    printf '[%s] %s\n' "$(date '+%F %T')" "$*" >&2
}

# Detect OS ID (e.g., ubuntu, debian, arch, manjaro)
os_id() {
    . /etc/os-release
    echo "${ID:-unknown}"
}

# Detect package manager
pm() {
    case "$(os_id)" in
        arch|manjaro) echo "pacman" ;;
        ubuntu|debian) echo "apt" ;;
        *) echo "unknown" ;;
    esac
}

# Install packages based on detected package manager
pm_install() {
    case "$(pm)" in
        pacman)
            sudo pacman -Syu --needed --noconfirm "$@"
            ;;
        apt)
            sudo apt-get update && sudo apt-get install -y "$@"
            ;;
        *)
            log "Unsupported distro: $(os_id)"
            exit 1
            ;;
    esac
}

is_installed() {
  case "$(pm)" in
    pacman) pacman -Qi "$1" >/dev/null 2>&1 ;;
    apt)    dpkg -s "$1" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

is_running() {
  systemctl is-active --quiet "$1"
}

enable_and_start() {
  local unit="$1"
  if ! systemctl is-enabled --quiet "$unit"; then
    sudo systemctl enable "$unit"
  fi
  if ! is_running "$unit"; then
    sudo systemctl start "$unit"
  fi
}
