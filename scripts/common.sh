#!/usr/bin/env bash
set -euo pipefail

log() { printf "[%s] %s\n" "$(date +%F\ %T)" "$*" >&2; }

os_id() { . /etc/os-release; echo "${ID:-unknown}"; }
pm() {
  case "$(os_id)" in
    arch|manjaro) echo pacman ;;
    ubuntu|debian) echo apt ;;
    *) echo unknown ;;
  esac
}

pm_install() {
  case "$(pm)" in
    pacman) sudo pacman -Syu --needed --noconfirm "$@" ;;
    apt)    sudo apt-get update && sudo apt-get install -y "$@" ;;
    *) log "Unsupported distro"; exit 1 ;;
  esac
}
