#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CLI="$ROOT/bin/cmux4justn"
SHELL_RC="${CMUX4JUSTN_SHELL_RC:-$HOME/.zshrc}"
ALIAS_LINE="alias c4j='$CLI'"
MARKER_START="# >>> cmux4justn >>>"
MARKER_END="# <<< cmux4justn <<<"

usage() {
  cat <<'USAGE'
Usage: scripts/install.sh [--dry-run]

Adds the c4j alias to ~/.zshrc by default.
Set CMUX4JUSTN_SHELL_RC=/path/to/rc to target another shell rc file.
USAGE
}

DRY_RUN=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown option: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

[ -x "$CLI" ] || chmod +x "$CLI"

if [ "$DRY_RUN" -eq 1 ]; then
  printf 'would-update\t%s\n' "$SHELL_RC"
  printf '%s\n%s\n%s\n' "$MARKER_START" "$ALIAS_LINE" "$MARKER_END"
  exit 0
fi

mkdir -p "$(dirname "$SHELL_RC")"
touch "$SHELL_RC"

if grep -F "$ALIAS_LINE" "$SHELL_RC" >/dev/null 2>&1; then
  printf 'skip existing-alias\t%s\n' "$SHELL_RC"
  exit 0
fi

if grep -F "$MARKER_START" "$SHELL_RC" >/dev/null 2>&1; then
  printf 'error: cmux4justn marker exists but alias differs: %s\n' "$SHELL_RC" >&2
  exit 1
fi

{
  printf '\n%s\n' "$MARKER_START"
  printf '%s\n' "$ALIAS_LINE"
  printf '%s\n' "$MARKER_END"
} >> "$SHELL_RC"

printf 'installed\t%s\n' "$SHELL_RC"
printf 'alias\tc4j -> %s\n' "$CLI"
