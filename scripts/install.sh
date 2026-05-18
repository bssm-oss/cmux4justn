#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CLI="$ROOT/bin/cmux4justn"
SHELL_RC="${CMUX4JUSTN_SHELL_RC:-$HOME/.zshrc}"
BIN_DIR=""
NO_RC=0
DRY_RUN=0
MARKER_START="# >>> cmux4justn >>>"
MARKER_END="# <<< cmux4justn <<<"

usage() {
  cat <<'USAGE'
Usage: scripts/install.sh [--dry-run] [--shell-rc PATH] [--bin-dir PATH] [--no-rc]

Defaults:
  - Adds alias c4j to ~/.zshrc (or CMUX4JUSTN_SHELL_RC)
  - Uses repository bin/cmux4justn directly

Options:
  --shell-rc PATH  Override shell rc file target
  --bin-dir PATH   Install cmux4justn executable into PATH directory
  --no-rc          Skip shell rc alias update
  --dry-run        Print planned changes only
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --shell-rc)
      [ "$#" -ge 2 ] || {
        printf 'error: --shell-rc requires a path\n' >&2
        exit 1
      }
      SHELL_RC="$2"
      shift 2
      ;;
    --bin-dir)
      [ "$#" -ge 2 ] || {
        printf 'error: --bin-dir requires a path\n' >&2
        exit 1
      }
      BIN_DIR="$2"
      shift 2
      ;;
    --no-rc)
      NO_RC=1
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

TARGET_CLI="$CLI"
if [ -n "$BIN_DIR" ]; then
  TARGET_CLI="$BIN_DIR/cmux4justn"
fi
ALIAS_TARGET="$(printf '%q' "$TARGET_CLI")"
ALIAS_LINE="alias c4j=$ALIAS_TARGET"

if [ "$DRY_RUN" -eq 1 ]; then
  if [ ! -x "$CLI" ]; then
    printf 'would-chmod\t%s\n' "$CLI"
  fi

  if [ -n "$BIN_DIR" ]; then
    printf 'would-install-bin\t%s\t%s\n' "$CLI" "$TARGET_CLI"
  fi

  if [ "$NO_RC" -eq 1 ]; then
    printf 'would-skip-rc\n'
  else
    printf 'would-update\t%s\n' "$SHELL_RC"
    printf '%s\n%s\n%s\n' "$MARKER_START" "$ALIAS_LINE" "$MARKER_END"
  fi
  exit 0
fi

[ -x "$CLI" ] || chmod +x "$CLI"

if [ -n "$BIN_DIR" ]; then
  mkdir -p "$BIN_DIR"
  if [ -e "$TARGET_CLI" ] && ! cmp -s "$CLI" "$TARGET_CLI"; then
    printf 'error: target executable already exists and differs: %s\n' "$TARGET_CLI" >&2
    exit 1
  fi
  if [ -e "$TARGET_CLI" ]; then
    printf 'skip existing-bin\t%s\n' "$TARGET_CLI"
  else
    install -m 0755 "$CLI" "$TARGET_CLI"
    printf 'installed-bin\t%s\n' "$TARGET_CLI"
  fi
fi

if [ "$NO_RC" -eq 1 ]; then
  printf 'skip rc-update\n'
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
printf 'alias\tc4j -> %s\n' "$TARGET_CLI"
