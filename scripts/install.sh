#!/usr/bin/env bash
# scripts/install.sh — core installer
# Safe for zsh: do NOT source ~/.profile directly in .zshrc.
# ~/.profile bleibt die zentrale Datei (gen-profile.sh schreibt dort rein).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log() { echo "$@"; }

append_once() {
  # usage: append_once <file> <marker-string> <block...>
  local f="$1" marker="$2"; shift 2
  mkdir -p "$(dirname "$f")"
  touch "$f"
  if ! grep -Fq -- "$marker" "$f"; then
    {
      echo
      printf '%s\n' "$@"
    } >> "$f"
    log "🔗 Appended block to $f"
  else
    log "✅ Block already present in $f"
  fi
}

remove_bad_zsh_profile_source() {
  local zrc="$HOME/.zshrc"
  [[ -f "$zrc" ]] || return 0
  # Entferne alten Block "# Source generated profile" + folgende Zeile
  if grep -Fq '# Source generated profile' "$zrc"; then
    sed -i '/^# Source generated profile$/,+1d' "$zrc"
    log "🧹 Removed legacy '# Source generated profile' block from $zrc"
  fi
  # Entferne verbleibende direkte `source .../.profile`-Zeilen (nur in .zshrc!)
  if grep -Eq '^[[:space:]]*source[[:space:]]+.*/\.profile[[:space:]]*$' "$zrc"; then
    sed -i '/^[[:space:]]*source[[:space:]]\+.*\/\.profile[[:space:]]*$/d' "$zrc"
    log "🧹 Removed direct 'source ~/.profile' lines from $zrc"
  fi
}

log "🚀 Running linux-setup installer"

# Optional: Profil generieren (schreibt nach ~/.profile)
if [[ -x "$SCRIPT_DIR/gen-profile.sh" ]]; then
  "$SCRIPT_DIR/gen-profile.sh" || true
fi

SHELL_NAME="$(basename "${SHELL:-}")"
log "ℹ️ Detected shell: ${SHELL_NAME:-unknown}"

# Sicherstellen, dass unser init_zsh.sh existiert
INIT_ZSH="$SCRIPT_DIR/init_zsh.sh"
if [[ ! -f "$INIT_ZSH" ]]; then
  cat > "$INIT_ZSH" <<'EOF'
# scripts/init_zsh.sh — created by installer (will be overwritten if repo version exists)
# Intentionally minimal; real content provided separately.
if [ -n "$ZSH_VERSION" ]; then
  setopt LOCAL_OPTIONS
  unsetopt nounset
  # Prevent double-sourcing
  if [[ -z "${LINUX_SETUP_PROFILE_SOURCED:-}" ]]; then
    export LINUX_SETUP_PROFILE_SOURCED=1
    [[ -r "$HOME/.profile" ]] && . "$HOME/.profile"
  fi
fi
EOF
  chmod +x "$INIT_ZSH"
fi

case "$SHELL_NAME" in
  zsh)
    ZRC="$HOME/.zshrc"
    remove_bad_zsh_profile_source

    # Unser init_zsh.sh NACH oh-my-zsh laden (Marker; Reihenfolge beachten!)
    append_once "$ZRC" "# linux-setup: init_zsh" \
'# linux-setup: init_zsh (must come AFTER oh-my-zsh)
if [ -f "$HOME/linux-setup/scripts/init_zsh.sh" ]; then
  source "$HOME/linux-setup/scripts/init_zsh.sh"
elif [ -f "'"$SCRIPT_DIR"'/init_zsh.sh" ]; then
  source "'"$SCRIPT_DIR"'/init_zsh.sh"
fi'

    log "✅ zsh configured (safe sourcing via init_zsh.sh; no direct .profile in .zshrc)"
    ;;

  bash)
    BRC="$HOME/.bashrc"
    append_once "$BRC" "# linux-setup: source-profile" \
'# linux-setup: source-profile (bash-safe)
if [ -f "$HOME/.profile" ]; then
  . "$HOME/.profile"
fi'
    log "✅ bash configured to source ~/.profile"
    ;;

  *)
    log "⚠️ Unsupported shell '${SHELL_NAME:-}'. No RC changes applied."
    ;;
esac

log "🎯 Done."
