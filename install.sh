#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${C4J_REPO_URL:-https://github.com/bssm-oss/cmux4justn.git}"
BOOTSTRAP_REF="v0.10.2"
REF="${C4J_REF:-$BOOTSTRAP_REF}"
INSTALL_DIR="${C4J_INSTALL_DIR:-$HOME/.local/share/c4j}"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

script_dir=""
if [ -n "${BASH_SOURCE[0]-}" ]; then
  if script_dir_candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"; then
    script_dir="$script_dir_candidate"
  fi
fi
if [ -n "$script_dir" ] && [ -x "$script_dir/scripts/install.sh" ] && [ -x "$script_dir/bin/cmux4justn" ]; then
  exec "$script_dir/scripts/install.sh" "$@"
fi

command -v git >/dev/null 2>&1 || fail "git is required to download c4j"

if [ -e "$INSTALL_DIR" ] && [ ! -d "$INSTALL_DIR/.git" ]; then
  fail "install directory exists and is not a git clone: $INSTALL_DIR"
fi

if [ -d "$INSTALL_DIR/.git" ]; then
  printf 'update-source\t%s\t%s\n' "$INSTALL_DIR" "$REF"
  git -C "$INSTALL_DIR" fetch -q --depth 1 origin "$REF"
  git -C "$INSTALL_DIR" -c advice.detachedHead=false checkout -q -f FETCH_HEAD
else
  printf 'download-source\t%s\t%s\n' "$REPO_URL" "$INSTALL_DIR"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git clone -q --depth 1 --no-checkout "$REPO_URL" "$INSTALL_DIR"
  git -C "$INSTALL_DIR" fetch -q --depth 1 origin "$REF"
  git -C "$INSTALL_DIR" -c advice.detachedHead=false checkout -q FETCH_HEAD
fi

exec "$INSTALL_DIR/scripts/install.sh" "$@"
