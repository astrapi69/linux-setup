#!/usr/bin/env bash

###############################################################################
# bootstrap.sh                                                                 #
# This script initializes the linux-setup directory structure with            #
# the required folders and empty files.                                       #
###############################################################################

set -e

ROOT_DIR="."

# Define subdirectories and files
declare -a FILES=(
  "dotfiles/.aliasesrc"
  "dotfiles/.aptrc"
  "dotfiles/.shell-aliases"
  "dotfiles/.zipping"
  "scripts/gen-profile.sh"
  "scripts/init_scripts.sh"
  "scripts/print_messages.sh"
  "scripts/detect_os.sh"
  "etc/cron.daily/chkrootkit.sh"
  "install.sh"
)

# Create each file and its parent directory if needed
for file in "${FILES[@]}"; do
  full_path="$ROOT_DIR/$file"
  dir_path=$(dirname "$full_path")
  mkdir -p "$dir_path"
  touch "$full_path"
  echo "✅ Created: $full_path"
done

echo "🎉 linux-setup structure initialized successfully in '$ROOT_DIR'"
