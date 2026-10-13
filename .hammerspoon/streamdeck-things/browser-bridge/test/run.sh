#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

NODE="node"
if ! node -e '' >/dev/null 2>&1; then
  NODE="$HOME/.local/share/mise/installs/node/24.18.0/bin/node"
fi

status=0
echo "== background.js =="
"$NODE" test/test-background.js || status=1
echo
echo "== content-scripts/google-meet.js =="
"$NODE" test/test-google-meet.js || status=1
echo
echo "== content-scripts/teams.js =="
"$NODE" test/test-teams.js || status=1
exit $status
