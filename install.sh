#!/usr/bin/env bash
set -euo pipefail

DEFAULT_REPO_URL="https://github.com/bssm-oss/cmux4justn.git"
REPO_URL="${C4J_REPO_URL:-$DEFAULT_REPO_URL}"
BOOTSTRAP_REF="v0.13.6"
REF="${C4J_REF:-$BOOTSTRAP_REF}"
INSTALL_DIR="${C4J_INSTALL_DIR:-$HOME/.local/share/c4j}"
DRY_RUN=0
ALLOW_UNSAFE_SOURCE=0
INSTALL_ARGS=()

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

trusted_ref() {
  case "$1" in
    v[0-9]*)
      case "$1" in
        */*|*..*|"") return 1 ;;
        *) return 0 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

validate_source_policy() {
  [ "$ALLOW_UNSAFE_SOURCE" -eq 0 ] || return 0
  [ "$REPO_URL" = "$DEFAULT_REPO_URL" ] || fail "unsafe source requires --allow-unsafe-source: repo-url $REPO_URL"
  trusted_ref "$REF" || fail "unsafe source requires --allow-unsafe-source: ref $REF is not a trusted v* tag"
}

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=1
      INSTALL_ARGS+=("$arg")
      ;;
    --allow-unsafe-source)
      ALLOW_UNSAFE_SOURCE=1
      ;;
    *)
      INSTALL_ARGS+=("$arg")
      ;;
  esac
done

script_dir=""
if [ -n "${BASH_SOURCE[0]-}" ]; then
  if script_dir_candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"; then
    script_dir="$script_dir_candidate"
  fi
fi
if [ -n "$script_dir" ] && [ -x "$script_dir/scripts/install.sh" ] && [ -x "$script_dir/bin/cmux4justn" ]; then
  exec "$script_dir/scripts/install.sh" "${INSTALL_ARGS[@]}"
fi

command -v git >/dev/null 2>&1 || fail "git is required to download c4j"
validate_source_policy

if [ -e "$INSTALL_DIR" ] && [ ! -d "$INSTALL_DIR/.git" ]; then
  fail "install directory exists and is not a git clone: $INSTALL_DIR"
fi

if [ -d "$INSTALL_DIR/.git" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'would-update-source\t%s\t%s\n' "$INSTALL_DIR" "$REF"
    printf 'would-run-installer\t%s\t%s\n' "$INSTALL_DIR/scripts/install.sh" "${INSTALL_ARGS[*]}"
    exit 0
  fi
  if [ -n "$(git -C "$INSTALL_DIR" status --porcelain 2>/dev/null)" ]; then
    fail "install checkout has local changes: $INSTALL_DIR (commit, stash, or remove them before updating)"
  fi
  printf 'update-source\t%s\t%s\n' "$INSTALL_DIR" "$REF"
  git -C "$INSTALL_DIR" fetch -q --depth 1 origin "$REF"
  git -C "$INSTALL_DIR" -c advice.detachedHead=false checkout -q -f FETCH_HEAD
else
  if [ "$DRY_RUN" -eq 1 ]; then
    printf 'would-download-source\t%s\t%s\n' "$REPO_URL" "$INSTALL_DIR"
    printf 'would-run-installer\t%s\t%s\n' "$INSTALL_DIR/scripts/install.sh" "${INSTALL_ARGS[*]}"
    exit 0
  fi
  printf 'download-source\t%s\t%s\n' "$REPO_URL" "$INSTALL_DIR"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  git init -q "$INSTALL_DIR"
  git -C "$INSTALL_DIR" remote add origin "$REPO_URL"
  git -C "$INSTALL_DIR" fetch -q --depth 1 origin "$REF"
  git -C "$INSTALL_DIR" -c advice.detachedHead=false checkout -q FETCH_HEAD
fi

exec "$INSTALL_DIR/scripts/install.sh" "${INSTALL_ARGS[@]}"
