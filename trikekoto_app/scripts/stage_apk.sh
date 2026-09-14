#!/usr/bin/env bash
# Put the release APK where `firebase deploy --only hosting` will serve it.
#
#   flutter build apk --release
#   flutter build web --release
#   bash scripts/stage_apk.sh          <-- after BOTH builds, from Git Bash
#
# From PowerShell, `bash` may not be Git Bash, and on 2026-09-14 the script
# printed nothing and staged nothing while the deploy after it succeeded.
# Run it from Git Bash, and read its "staged ... sha256" line before deploying.
#   firebase deploy --only hosting
#
# Order matters. `flutter build web` rewrites build/web and only copies a
# known set of files out of web/ — a download/ directory placed there is
# silently dropped, which is why this stages into the build output instead.
# Run it before the web build and the APK disappears with no error.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=build/app/outputs/flutter-apk/app-release.apk
DEST=build/web/download/trikekoto.apk

[ -f "$SRC" ] || { echo "No release APK. Run: flutter build apk --release" >&2; exit 1; }
[ -d build/web ] || { echo "No web build. Run: flutter build web --release" >&2; exit 1; }

mkdir -p "$(dirname "$DEST")"
cp "$SRC" "$DEST"

SRC_SUM=$(sha256sum "$SRC" | cut -d' ' -f1)
DEST_SUM=$(sha256sum "$DEST" | cut -d' ' -f1)

# Assert rather than announce, and by content, not size. This script once
# failed on Windows with "Class not registered", the deploy ran anyway, and a
# stale APK shipped. A size check was added — and on 2026-09-14 two
# consecutive builds (1.0.2 and 1.0.3) came out at exactly 62,408,748 bytes,
# so an outdated staged APK passed it and reached Hosting. A checksum cannot
# be fooled that way.
if [ "$SRC_SUM" != "$DEST_SUM" ]; then
  echo "STAGING FAILED: staged APK does not match the build (sha256 ${DEST_SUM:0:16} != ${SRC_SUM:0:16})" >&2
  exit 1
fi

echo "staged $(stat -c %s "$DEST") bytes -> $DEST  (sha256 ${DEST_SUM:0:16})"
echo "built  $(date -r "$SRC" '+%Y-%m-%d %H:%M')"
echo
echo "Next:  firebase deploy --only hosting"
