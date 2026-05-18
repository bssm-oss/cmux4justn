#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CLI="$ROOT/bin/cmux4justn"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if ! printf '%s\n' "$haystack" | grep -F -- "$needle" >/dev/null; then
    fail "expected output to contain: $needle"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if printf '%s\n' "$haystack" | grep -F -- "$needle" >/dev/null; then
    fail "expected output not to contain: $needle"
  fi
}

ACTIVE="$TMPDIR/@active"
PROJECTS="$TMPDIR/projects"
mkdir -p "$ACTIVE" "$PROJECTS/alpha" "$PROJECTS/beta" "$PROJECTS/gamma" "$PROJECTS/delta" "$PROJECTS/unsafe"
ln -s "$PROJECTS/alpha" "$ACTIVE/alpha"
ln -s "$PROJECTS/beta" "$ACTIVE/beta"
ln -s "$PROJECTS/beta" "$ACTIVE/beta-copy"
ln -s "$PROJECTS/missing" "$ACTIVE/missing"
mkdir -p "$ACTIVE/not-a-link"

FAKE_CMUX="$TMPDIR/cmux"
CALLS="$TMPDIR/calls"
cat > "$FAKE_CMUX" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "--json" ] && [ "${2:-}" = "list-workspaces" ]; then
  cat <<JSON
{
  "workspaces": [
    {"title": "@active/alpha", "current_directory": "$CMUX_TEST_PROJECTS/alpha"},
    {"title": "@active/delta", "current_directory": "$CMUX_TEST_PROJECTS/delta"},
    {"title": "@active/bad/name", "current_directory": "$CMUX_TEST_PROJECTS/unsafe"},
    {"title": "other", "current_directory": "$CMUX_TEST_PROJECTS/gamma"}
  ]
}
JSON
  exit 0
fi

case "${1:-}" in
  new-workspace)
    printf '%s\n' "$*" >> "$CMUX_FAKE_CALLS"
    ;;
  *)
    printf 'unexpected cmux command: %s\n' "$*" >&2
    exit 2
    ;;
esac
FAKE
chmod +x "$FAKE_CMUX"
export CMUX_FAKE_CALLS="$CALLS"
export CMUX_TEST_PROJECTS="$PROJECTS"
export CMUX4JUSTN_ACTIVE_DIR="$ACTIVE"
export CMUX4JUSTN_CMUX_BIN="$FAKE_CMUX"

output="$($CLI sync --dry-run)"
assert_contains "$output" "skip existing	@active/alpha"
assert_contains "$output" "would-create-workspace	@active/beta"
assert_contains "$output" "skip duplicate-target	@active/beta-copy"
assert_contains "$output" "skip broken-or-non-dir	missing"
assert_contains "$output" "summary	mode=dry-run	direction=active-to-cmux"
[ ! -e "$CALLS" ] || fail "dry-run should not call new-workspace"

output="$($CLI sync --apply)"
assert_contains "$output" "create-workspace	@active/beta"
assert_not_contains "$output" "create-workspace	@active/alpha"
[ -e "$CALLS" ] || fail "apply should call new-workspace"
assert_contains "$(cat "$CALLS")" "new-workspace --name @active/beta --cwd"
rm -f "$CALLS"

output="$($CLI sync --direction cmux-to-active --dry-run)"
assert_contains "$output" "skip existing-link	@active/alpha"
assert_contains "$output" "would-create-link	@active/delta"
assert_contains "$output" "skip unsafe-name	@active/bad/name"
[ ! -e "$ACTIVE/delta" ] || fail "reverse dry-run should not create symlink"

output="$($CLI sync --direction cmux-to-active --apply)"
assert_contains "$output" "create-link	@active/delta"
[ -L "$ACTIVE/delta" ] || fail "reverse apply should create symlink"
resolved="$(cd "$ACTIVE/delta" && pwd -P)"
expected_delta="$(cd "$PROJECTS/delta" && pwd -P)"
[ "$resolved" = "$expected_delta" ] || fail "delta symlink points to wrong target: $resolved"

output="$($CLI add --dry-run)"
assert_contains "$output" "summary	mode=dry-run	direction=both"

BAD_CMUX="$TMPDIR/bad-cmux"
cat > "$BAD_CMUX" <<'BAD'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "--json" ] && [ "${2:-}" = "list-workspaces" ]; then
  printf '{not-json\n'
  exit 0
fi
exit 2
BAD
chmod +x "$BAD_CMUX"
if output="$($CLI sync --apply --cmux "$BAD_CMUX" 2>&1)"; then
  fail "sync apply should fail when cmux inventory is invalid"
fi
assert_contains "$output" "cannot read cmux workspace inventory for apply sync"

output="$($CLI add --dry-run "$PROJECTS/gamma")"
assert_contains "$output" "would-link"
assert_contains "$output" "summary	mode=dry-run	direction=both"
[ ! -e "$ACTIVE/gamma" ] || fail "add dry-run should not create symlink"

output="$($CLI add --apply "$PROJECTS/gamma")"
assert_contains "$output" "link	$ACTIVE/gamma"
[ -L "$ACTIVE/gamma" ] || fail "add apply should create symlink"

output="$($CLI list)"
assert_contains "$output" "alpha"
assert_contains "$output" "gamma"

output="$($CLI doctor)"
assert_contains "$output" "active_dir"
assert_contains "$output" "cmux_bin"

install_output="$(CMUX4JUSTN_SHELL_RC="$TMPDIR/zshrc" "$ROOT/scripts/install.sh" --dry-run)"
assert_contains "$install_output" "would-update	$TMPDIR/zshrc"
[ ! -e "$TMPDIR/zshrc" ] || fail "install dry-run should not create shell rc"

[ "$($CLI version)" = "0.1.1" ] || fail "version mismatch"

printf 'PASS cmux4justn tests\n'
