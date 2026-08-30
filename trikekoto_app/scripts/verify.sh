#!/usr/bin/env bash
# ============================================================
# Run everything CI runs, locally, in one command.
#   bash scripts/verify.sh
# ============================================================
#
# This exists because the full suite was three commands, each needing a
# TEMP prefix that only matters on one machine. A check that is awkward to
# run is a check that gets skipped — and the one most likely to be skipped
# is the emulator suite, which is the only thing standing between a rules
# edit and a production data leak.
#
# Mirrors .github/workflows/trikekoto-app.yml. If you change one, change
# both — a local pass that CI then fails teaches people to ignore CI.

set -uo pipefail

cd "$(dirname "$0")/.."
APP_DIR="$PWD"

# Java's NIO selector opens an AF_UNIX socket pair inside java.io.tmpdir.
# On this machine that fails inside %LOCALAPPDATA%\Temp, which breaks Gradle
# and the Firestore emulator with an error naming neither. Harmless
# elsewhere. See docs/RUNBOOK.md.
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
  mkdir -p /c/Temp 2>/dev/null || true
  export TEMP='C:\Temp'
  export TMP='C:\Temp'
fi

FAILED=()
PASSED=()

step() {
  local name="$1"; shift
  printf '\n\033[1m── %s ─────────────────────────────────────\033[0m\n' "$name"
  if "$@"; then
    PASSED+=("$name")
  else
    FAILED+=("$name")
    printf '\033[31m   FAILED: %s\033[0m\n' "$name"
  fi
}

# Every step runs even if an earlier one fails. Stopping at the first
# failure means finding them one round-trip at a time.
step "Analyze"          bash -c "cd '$APP_DIR' && flutter analyze --fatal-infos"
step "Dart tests"       bash -c "cd '$APP_DIR' && flutter test"
step "Firestore rules"  bash -c "cd '$APP_DIR/test_rules' && npm test --silent"
step "Functions"        bash -c "cd '$APP_DIR/functions' && npm run --silent typecheck"

printf '\n\033[1m═══ Summary ═══════════════════════════════\033[0m\n'
for s in "${PASSED[@]:-}"; do [[ -n "$s" ]] && printf '  \033[32mpass\033[0m  %s\n' "$s"; done
for s in "${FAILED[@]:-}"; do [[ -n "$s" ]] && printf '  \033[31mFAIL\033[0m  %s\n' "$s"; done

if [[ ${#FAILED[@]} -gt 0 ]]; then
  printf '\n\033[31m%d of 4 checks failed.\033[0m Do not deploy rules or ship an APK.\n' "${#FAILED[@]}"
  exit 1
fi

printf '\n\033[32mAll 4 checks passed.\033[0m\n'
