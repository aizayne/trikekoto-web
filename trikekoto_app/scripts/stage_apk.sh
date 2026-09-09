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

echo "staged $(stat -c %s "$DEST") bytes -> $DEST"
echo "built  $(date -r "$SRC" '+%Y-%m-%d %H:%M')"
echo
echo "Next:  firebase deploy --only hosting"
