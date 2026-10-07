#!/usr/bin/env bash

set -euo pipefail

if [ ! -x /opt/homebrew/bin/brew ]; then
  echo "Installing brew... if something goes wrong, check the install instructions at https://brew.sh/"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# a fresh brew install isn't populated into the shell yet, this allows the current process to interact as if it were.

eval "$(/opt/homebrew/bin/brew shellenv)"
export PATH="$HOME/.local/bin:$PATH"


for f in ~/components/*; do
  # skip files which aren't executable
  [ -f "$f" ] && [ -x "$f" ] || continue

  echo "==========================Running $f=========================="

  "$f"
done
