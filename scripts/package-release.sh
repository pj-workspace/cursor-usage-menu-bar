#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>" >&2
  echo "Example: $0 v0.2.0" >&2
  exit 1
fi

cd "$ROOT"
"$ROOT/scripts/build-app.sh" release

ARCHIVE="$ROOT/dist/CursorUsageMenuBar-${VERSION}.zip"
rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$ROOT/dist/CursorUsageMenuBar.app" "$ARCHIVE"

echo "==> Release archive: $ARCHIVE"
