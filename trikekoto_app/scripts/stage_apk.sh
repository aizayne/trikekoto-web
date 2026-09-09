#!/usr/bin/env bash
# Put the release APK where `firebase deploy --only hosting` will serve it.
#
#   flutter build apk --release
#   flutter build web --release
#   bash scripts/stage_apk.sh          <-- after BOTH builds
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

SRC_SIZE=$(stat -c %s "$SRC")
DEST_SIZE=$(stat -c %s "$DEST")

# Assert rather than announce. This script once failed on Windows with
# "Class not registered", the deploy ran anyway, and a stale APK shipped —
# the failure its header warns about, made by the script itself. A size
# mismatch here now stops the pipeline instead of printing into a log
# nobody reads.
if [ "$SRC_SIZE" != "$DEST_SIZE" ]; then
  echo "STAGING FAILED: source $SRC_SIZE bytes, staged $DEST_SIZE" >&2
  exit 1
fi

echo "staged $DEST_SIZE bytes -> $DEST"
echo "built  $(date -r "$SRC" '+%Y-%m-%d %H:%M')"
echo
echo "Next:  firebase deploy --only hosting"
