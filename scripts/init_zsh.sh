# scripts/init_zsh.sh — zsh-safe profile sourcing for linux-setup
# DO NOT use set -u / -e here; this runs in interactive shells.

# Nur unter zsh ausführen
if [ -z "$ZSH_VERSION" ]; then
  return 0 2>/dev/null || exit 0
fi

# Lokal 'nounset' ausschalten, damit OMZ/Theme nicht crasht
setopt LOCAL_OPTIONS
unsetopt nounset

# Double-source verhindern
if [[ -n "${LINUX_SETUP_PROFILE_SOURCED:-}" ]]; then
  return 0
fi
export LINUX_SETUP_PROFILE_SOURCED=1

# ~/.profile laden (hier liegen cleanup & Co.)
if [[ -r "$HOME/.profile" ]]; then
  . "$HOME/.profile"
fi

# (Optional) zsh-spezifische Extras kannst du hier ergänzen:
# autoload -Uz compinit && compinit -u
# setopt auto_cd
