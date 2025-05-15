#!/usr/bin/env bash

################################################################################
# gen-profile.sh                                                               #
# Merges modular dotfiles into ~/.profile                                      #
################################################################################

INPUT_FILES=(
  ../dotfiles/.aliasesrc
  ../dotfiles/.dirrc
  ../dotfiles/.shell-aliases
  ../dotfiles/.tweak.sh
  ../dotfiles/.zipping
)

TARGET_PROFILE="$HOME/.profile"

echo "🔧 Generating $TARGET_PROFILE"
> "$TARGET_PROFILE"

for file in "${INPUT_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    echo "  ✅ Including $file"
    cat "$file" >> "$TARGET_PROFILE"
    echo -e "\n" >> "$TARGET_PROFILE"
  else
    echo "  ⚠️  Skipping missing file: $file"
  fi
done

echo "✅ Profile written to $TARGET_PROFILE"
