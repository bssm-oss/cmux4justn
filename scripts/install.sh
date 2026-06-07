#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CLI="$ROOT/bin/cmux4justn"
BIN_DIR="${C4J_BIN_DIR:-$HOME/.local/bin}"
ACTIVE_DIR="${C4J_ACTIVE_DIR:-$HOME/.c4j/active}"
SHELL_RC="${C4J_SHELL_RC:-${CMUX4JUSTN_SHELL_RC:-$HOME/.zshrc}}"
INSTALL_BIN=1
CREATE_ACTIVE=1
UPDATE_RC=0
DRY_RUN=0
MARKER_START="# >>> c4j >>>"
MARKER_END="# <<< c4j <<<"

usage() {
  cat <<'USAGE'
Usage: scripts/install.sh [--dry-run] [--bin-dir PATH] [--no-bin] [--active-dir PATH] [--no-active-dir] [--rc] [--shell-rc PATH] [--no-rc]

Defaults:
  - Installs c4j into ~/.local/bin, or C4J_BIN_DIR.
  - Creates ~/.c4j/active, or C4J_ACTIVE_DIR.
  - Does not edit shell rc unless --rc is passed.

Options:
  --bin-dir PATH   Install c4j executable into PATH directory.
  --no-bin         Skip executable install.
  --active-dir PATH
                   Create the active-project symlink registry at PATH.
  --no-active-dir  Skip active directory creation.
  --rc             Add an alias fallback to shell rc.
  --shell-rc PATH  Override shell rc file target.
  --no-rc          Skip shell rc update.
  --dry-run        Print planned changes only.
USAGE
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --bin-dir)
      [ "$#" -ge 2 ] || fail "--bin-dir requires a path"
      BIN_DIR="$2"
      INSTALL_BIN=1
      shift 2
      ;;
    --no-bin)
      INSTALL_BIN=0
      shift
      ;;
    --active-dir)
      [ "$#" -ge 2 ] || fail "--active-dir requires a path"
      ACTIVE_DIR="$2"
      CREATE_ACTIVE=1
      shift 2
      ;;
    --no-active-dir)
      CREATE_ACTIVE=0
      shift
      ;;
    --rc)
      UPDATE_RC=1
      shift
      ;;
    --shell-rc)
      [ "$#" -ge 2 ] || fail "--shell-rc requires a path"
      SHELL_RC="$2"
      UPDATE_RC=1
      shift 2
      ;;
    --no-rc)
      UPDATE_RC=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

TARGET_CLI="$BIN_DIR/c4j"
ALIAS_TARGET="$(printf '%q' "$TARGET_CLI")"
ALIAS_LINE="alias c4j=$ALIAS_TARGET"

if [ "$INSTALL_BIN" -eq 0 ] && [ "$UPDATE_RC" -eq 0 ] && [ "$CREATE_ACTIVE" -eq 0 ]; then
  fail "nothing to install; use --bin-dir or --rc"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  if [ ! -x "$CLI" ]; then
    printf 'would-chmod\t%s\n' "$CLI"
  fi

  if [ "$INSTALL_BIN" -eq 1 ]; then
    printf 'would-install-bin\t%s\t%s\n' "$CLI" "$TARGET_CLI"
  else
    printf 'would-skip-bin\n'
  fi

  if [ "$CREATE_ACTIVE" -eq 1 ]; then
    printf 'would-create-active-dir\t%s\n' "$ACTIVE_DIR"
  else
    printf 'would-skip-active-dir\n'
  fi

  if [ "$UPDATE_RC" -eq 1 ]; then
    printf 'would-update-rc\t%s\n' "$SHELL_RC"
    printf '%s\n%s\n%s\n' "$MARKER_START" "$ALIAS_LINE" "$MARKER_END"
  else
    printf 'would-skip-rc\n'
  fi
  exit 0
fi

[ -x "$CLI" ] || chmod +x "$CLI"

if [ "$INSTALL_BIN" -eq 1 ]; then
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
else
  printf 'skip bin-install\n'
fi

if [ "$CREATE_ACTIVE" -eq 1 ]; then
  mkdir -p "$ACTIVE_DIR"
  printf 'active-dir\t%s\n' "$ACTIVE_DIR"
else
  printf 'skip active-dir\n'
fi

if [ "$UPDATE_RC" -ne 1 ]; then
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
  if grep -F "alias c4j='${TARGET_CLI}'" "$SHELL_RC" >/dev/null 2>&1; then
    printf 'skip existing-alias\t%s\n' "$SHELL_RC"
    exit 0
  fi
  printf 'error: c4j marker exists but alias differs: %s\n' "$SHELL_RC" >&2
  exit 1
fi

{
  printf '\n%s\n' "$MARKER_START"
  printf '%s\n' "$ALIAS_LINE"
  printf '%s\n' "$MARKER_END"
} >> "$SHELL_RC"

printf 'installed-rc\t%s\n' "$SHELL_RC"
printf 'alias\tc4j -> %s\n' "$TARGET_CLI"
