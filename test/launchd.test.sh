#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=test/lib/common.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib/common.bash"

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
[ ! -e "$LAUNCH_AGENTS_DIR/com.justn.c4j.sync.plist" ] || fail "launchd install dry-run should not write plist"

launch_print="$(bash "$ROOT/scripts/launchd.sh" print --launch-agents-dir "$LAUNCH_AGENTS_DIR" --active-dir "$ACTIVE_TEST_DIR" --cmux "$CMUX_TEST_BIN")"
assert_contains "$launch_print" "--dry-run"
assert_contains "$launch_print" "&amp;"
assert_contains "$launch_print" "&lt;test&gt;"

launch_output="$(bash "$ROOT/scripts/launchd.sh" install --apply --launch-agents-dir "$LAUNCH_AGENTS_DIR" --launchctl "$LAUNCHCTL_STUB" --active-dir "$ACTIVE_TEST_DIR")"
assert_contains "$launch_output" "installed	$LAUNCH_AGENTS_DIR/com.justn.c4j.sync.plist"
assert_contains "$launch_output" "skip load"
[ -e "$LAUNCH_AGENTS_DIR/com.justn.c4j.sync.plist" ] || fail "launchd install apply should write plist"
plist_content="$(cat "$LAUNCH_AGENTS_DIR/com.justn.c4j.sync.plist")"
assert_contains "$plist_content" "--dry-run"
assert_contains "$plist_content" "$ROOT/bin/c4j"

if launch_output="$(bash "$ROOT/scripts/launchd.sh" install --apply --launch-agents-dir "$LAUNCH_AGENTS_DIR" --label "../bad" 2>&1)"; then
  fail "launchd should reject unsafe labels"
fi
assert_contains "$launch_output" "invalid label"
[ ! -e "$LAUNCH_AGENTS_DIR/../bad.plist" ] || fail "launchd unsafe label should not write outside LaunchAgents"

launch_output="$(bash "$ROOT/scripts/launchd.sh" install --apply --load --launch-agents-dir "$LAUNCH_AGENTS_DIR" --launchctl "$LAUNCHCTL_STUB" --sync-apply)"
assert_contains "$launch_output" "loaded"
[ -e "$CMUX_LAUNCHCTL_CALLS" ] || fail "launchd install --load should call launchctl"
assert_contains "$(cat "$CMUX_LAUNCHCTL_CALLS")" "load"

launch_output="$(bash "$ROOT/scripts/launchd.sh" uninstall --launch-agents-dir "$LAUNCH_AGENTS_DIR" --launchctl "$LAUNCHCTL_STUB")"
assert_contains "$launch_output" "dry-run	no-remove"
[ -e "$LAUNCH_AGENTS_DIR/com.justn.c4j.sync.plist" ] || fail "launchd uninstall dry-run should not remove plist"

launch_output="$(bash "$ROOT/scripts/launchd.sh" uninstall --apply --load --launch-agents-dir "$LAUNCH_AGENTS_DIR" --launchctl "$LAUNCHCTL_STUB")"
assert_contains "$launch_output" "removed	$LAUNCH_AGENTS_DIR/com.justn.c4j.sync.plist"
[ ! -e "$LAUNCH_AGENTS_DIR/com.justn.c4j.sync.plist" ] || fail "launchd uninstall apply should remove plist"
assert_contains "$(cat "$CMUX_LAUNCHCTL_CALLS")" "unload"

printf 'PASS launchd workflow\n'
