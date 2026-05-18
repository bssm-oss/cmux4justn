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

INSTALL_RC="$TMPDIR/zshrc"
INSTALL_BIN_DIR="$TMPDIR/bin"

install_output="$(CMUX4JUSTN_SHELL_RC="$INSTALL_RC" bash "$ROOT/scripts/install.sh" --dry-run)"
assert_contains "$install_output" "would-update	$INSTALL_RC"
[ ! -e "$INSTALL_RC" ] || fail "install dry-run should not create shell rc"

{
  printf '%s\n' "# >>> cmux4justn >>>"
  printf "alias c4j='%s'\n" "$ROOT/bin/cmux4justn"
  printf '%s\n' "# <<< cmux4justn <<<"
} > "$INSTALL_RC"
install_output="$(bash "$ROOT/scripts/install.sh" --shell-rc "$INSTALL_RC")"
assert_contains "$install_output" "skip existing-alias	$INSTALL_RC"
rm -f "$INSTALL_RC"

install_output="$(bash "$ROOT/scripts/install.sh" --dry-run --shell-rc "$INSTALL_RC" --bin-dir "$INSTALL_BIN_DIR")"
assert_contains "$install_output" "would-install-bin"
assert_contains "$install_output" "would-update	$INSTALL_RC"
[ ! -e "$INSTALL_BIN_DIR/cmux4justn" ] || fail "install dry-run should not create bin copy"

install_output="$(bash "$ROOT/scripts/install.sh" --dry-run --no-rc --bin-dir "$INSTALL_BIN_DIR")"
assert_contains "$install_output" "would-skip-rc"
assert_not_contains "$install_output" "would-update"

install_output="$(bash "$ROOT/scripts/install.sh" --no-rc --bin-dir "$INSTALL_BIN_DIR")"
assert_contains "$install_output" "installed-bin	$INSTALL_BIN_DIR/cmux4justn"
assert_contains "$install_output" "skip rc-update"
[ -x "$INSTALL_BIN_DIR/cmux4justn" ] || fail "install apply should create executable bin copy"

install_output="$(bash "$ROOT/scripts/install.sh" --no-rc --bin-dir "$INSTALL_BIN_DIR")"
assert_contains "$install_output" "skip existing-bin	$INSTALL_BIN_DIR/cmux4justn"

printf 'different\n' > "$INSTALL_BIN_DIR/cmux4justn"
if install_output="$(bash "$ROOT/scripts/install.sh" --no-rc --bin-dir "$INSTALL_BIN_DIR" 2>&1)"; then
  fail "install should fail rather than overwrite different bin target"
fi
assert_contains "$install_output" "target executable already exists and differs"

LAUNCH_TMP="$TMPDIR/launchd"
LAUNCH_AGENTS_DIR="$LAUNCH_TMP/LaunchAgents"
LAUNCHCTL_STUB="$LAUNCH_TMP/launchctl"
ACTIVE_TEST_DIR="$TMPDIR/active test & dir"
CMUX_TEST_BIN="$TMPDIR/cmux <test>"
mkdir -p "$LAUNCH_TMP"
cat > "$LAUNCHCTL_STUB" <<'LCTL'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$CMUX_LAUNCHCTL_CALLS"
LCTL
chmod +x "$LAUNCHCTL_STUB"
export CMUX_LAUNCHCTL_CALLS="$TMPDIR/launchctl.calls"

launch_output="$(bash "$ROOT/scripts/launchd.sh" install --launch-agents-dir "$LAUNCH_AGENTS_DIR" --launchctl "$LAUNCHCTL_STUB")"
assert_contains "$launch_output" "dry-run	no-write"
[ ! -e "$LAUNCH_AGENTS_DIR/com.justn.cmux4justn.sync.plist" ] || fail "launchd install dry-run should not write plist"

launch_print="$(bash "$ROOT/scripts/launchd.sh" print --launch-agents-dir "$LAUNCH_AGENTS_DIR" --active-dir "$ACTIVE_TEST_DIR" --cmux "$CMUX_TEST_BIN")"
assert_contains "$launch_print" "--dry-run"
assert_contains "$launch_print" "&amp;"
assert_contains "$launch_print" "&lt;test&gt;"

launch_output="$(bash "$ROOT/scripts/launchd.sh" install --apply --launch-agents-dir "$LAUNCH_AGENTS_DIR" --launchctl "$LAUNCHCTL_STUB" --active-dir "$ACTIVE_TEST_DIR")"
assert_contains "$launch_output" "installed	$LAUNCH_AGENTS_DIR/com.justn.cmux4justn.sync.plist"
assert_contains "$launch_output" "skip load"
[ -e "$LAUNCH_AGENTS_DIR/com.justn.cmux4justn.sync.plist" ] || fail "launchd install apply should write plist"
plist_content="$(cat "$LAUNCH_AGENTS_DIR/com.justn.cmux4justn.sync.plist")"
assert_contains "$plist_content" "--dry-run"
assert_contains "$plist_content" "$ROOT/bin/cmux4justn"

launch_output="$(bash "$ROOT/scripts/launchd.sh" install --apply --load --launch-agents-dir "$LAUNCH_AGENTS_DIR" --launchctl "$LAUNCHCTL_STUB" --sync-apply)"
assert_contains "$launch_output" "loaded"
[ -e "$CMUX_LAUNCHCTL_CALLS" ] || fail "launchd install --load should call launchctl"
assert_contains "$(cat "$CMUX_LAUNCHCTL_CALLS")" "load"

launch_output="$(bash "$ROOT/scripts/launchd.sh" uninstall --launch-agents-dir "$LAUNCH_AGENTS_DIR" --launchctl "$LAUNCHCTL_STUB")"
assert_contains "$launch_output" "dry-run	no-remove"
[ -e "$LAUNCH_AGENTS_DIR/com.justn.cmux4justn.sync.plist" ] || fail "launchd uninstall dry-run should not remove plist"

launch_output="$(bash "$ROOT/scripts/launchd.sh" uninstall --apply --load --launch-agents-dir "$LAUNCH_AGENTS_DIR" --launchctl "$LAUNCHCTL_STUB")"
assert_contains "$launch_output" "removed	$LAUNCH_AGENTS_DIR/com.justn.cmux4justn.sync.plist"
[ ! -e "$LAUNCH_AGENTS_DIR/com.justn.cmux4justn.sync.plist" ] || fail "launchd uninstall apply should remove plist"
assert_contains "$(cat "$CMUX_LAUNCHCTL_CALLS")" "unload"

[ "$($CLI version)" = "0.1.3" ] || fail "version mismatch"

printf 'PASS cmux4justn tests\n'
