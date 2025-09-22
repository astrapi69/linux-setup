#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/common.sh"

case "$(pm)" in
  pacman) pm_install audit ;;
  apt)    pm_install auditd audispd-plugins ;;
  *)      echo "unsupported"; exit 1 ;;
esac

sudo systemctl enable --now auditd || true
