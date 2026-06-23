#!/usr/bin/env bash

C4J_TEST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
ROOT="$C4J_TEST_ROOT"
CLI="$ROOT/bin/c4j"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
export HOME="$TMPDIR/home"
unset C4J_CONFIG CMUX4JUSTN_CONFIG
CURRENT_VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
export ROOT CLI CURRENT_VERSION

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if ! printf '%s\n' "$haystack" | grep -F -- "$needle" >/dev/null; then
    fail "expected output to contain: $needle
--- actual output ---
$haystack
--- end ---"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if printf '%s\n' "$haystack" | grep -F -- "$needle" >/dev/null; then
    fail "expected output not to contain: $needle"
  fi
}

sed_inplace() {
  local pattern="$1"
  local file="$2"
  sed -i.bak "$pattern" "$file"
  rm -f "$file.bak"
}

make_basic_cmux_stub() {
  local cmux_bin="$1"
  cat > "$cmux_bin" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "identify" ] && [ "${2:-}" = "--json" ]; then
  cat <<JSON
{
  "caller": {"workspace_ref": "workspace:1"},
  "focused": {"workspace_ref": "workspace:1"},
  "socket_path": "/tmp/cmux.sock"
}
JSON
  exit 0
fi
if [ "${1:-}" = "--json" ] && [ "${2:-}" = "list-workspaces" ]; then
  cat <<JSON
{
  "workspaces": [
    {"title": "@active/alpha", "current_directory": "$CMUX_TEST_PROJECTS/alpha", "ref": "workspace:1"}
  ]
}
JSON
  exit 0
fi
case "${1:-}" in
  new-workspace|close-workspace|select-workspace|workspace-action|new-pane|send|send-key)
    printf '%s\n' "$*" >> "$CMUX_FAKE_CALLS"
    ;;
  *)
    printf 'unexpected cmux command: %s\n' "$*" >&2
    exit 2
    ;;
esac
FAKE
  chmod +x "$cmux_bin"
}

make_test_git_repo() {
  local repo="$1"
  local message="${2:-init}"
  mkdir -p "$repo"
  git -C "$repo" init >/dev/null
  git -C "$repo" symbolic-ref HEAD refs/heads/main
  git -C "$repo" config user.name "Test User"
  git -C "$repo" config user.email "test@example.com"
  printf 'hello\n' > "$repo/README.md"
  git -C "$repo" add README.md
  git -C "$repo" commit -m "$message" >/dev/null
}
