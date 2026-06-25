#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=test/lib/common.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib/common.bash"

ACTIVE="$TMPDIR/@active"
PROJECTS="$TMPDIR/projects"
mkdir -p "$ACTIVE" "$PROJECTS/alpha" "$PROJECTS/beta" "$PROJECTS/gamma" "$PROJECTS/delta" "$PROJECTS/legacy" "$PROJECTS/unsafe" "$PROJECTS/conflict-other"
PROJECTS_RESOLVED="$(cd "$PROJECTS" && pwd -P)"
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
if [ "${1:-}" = "identify" ] && [ "${2:-}" = "--json" ]; then
  cat <<JSON
{
  "caller": {
    "pane_ref": "pane:7",
    "surface_ref": "surface:14",
    "surface_type": "terminal",
    "tab_ref": "tab:14",
    "window_ref": "window:1",
    "workspace_ref": "workspace:7"
  },
  "focused": {
    "pane_ref": "pane:2",
    "surface_ref": "surface:5",
    "surface_type": "terminal",
    "tab_ref": "tab:5",
    "window_ref": "window:1",
    "workspace_ref": "workspace:2"
  },
  "socket_path": "/tmp/cmux.sock"
}
JSON
  exit 0
fi
if [ "${1:-}" = "--json" ] && [ "${2:-}" = "list-workspaces" ]; then
  cat <<JSON
{
  "workspaces": [
    {"title": "@active/alpha", "current_directory": "$CMUX_TEST_PROJECTS/alpha", "ref": "workspace:1"},
    {"title": "@active/delta", "current_directory": "$CMUX_TEST_PROJECTS/delta", "ref": "workspace:2"},
    {"title": "@active/gamma", "current_directory": "$CMUX_TEST_PROJECTS/gamma", "ref": "workspace:3"},
    {"title": "@active/conflict", "current_directory": "$CMUX_TEST_PROJECTS/conflict-other", "ref": "workspace:6"},
    {"title": "@active/bad/name", "current_directory": "$CMUX_TEST_PROJECTS/unsafe", "ref": "workspace:4"},
    {"title": "other", "current_directory": "$CMUX_TEST_PROJECTS/gamma", "ref": "workspace:5"},
    {"title": "justn-is-always-around-here", "current_directory": "$CMUX_TEST_PROJECTS", "ref": "workspace:8"}
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
chmod +x "$FAKE_CMUX"
export CMUX_FAKE_CALLS="$CALLS"
export CMUX_TEST_PROJECTS="$PROJECTS_RESOLVED"
export C4J_ACTIVE_DIR="$ACTIVE"
export C4J_CMUX_BIN="$FAKE_CMUX"

output="$($CLI anchor --dry-run --name missing-anchor --cwd "$PROJECTS")"
assert_contains "$output" "would-create-anchor	missing-anchor	$PROJECTS_RESOLVED"
assert_contains "$output" "would-pin-anchor	missing-anchor"
assert_contains "$output" "note	dry-run	apply with: c4j anchor --apply"
[ ! -e "$CALLS" ] || fail "anchor dry-run should not call cmux"

output="$($CLI anchor --apply --cwd "$PROJECTS")"
assert_contains "$output" "skip existing-anchor	justn-is-always-around-here	workspace:8"
assert_contains "$output" "pin-anchor	justn-is-always-around-here	workspace:8"
assert_contains "$(cat "$CALLS")" "workspace-action --workspace workspace:8 --action pin"
assert_contains "$(cat "$CALLS")" "workspace-action --workspace workspace:8 --action set-color --color Teal"
assert_contains "$(cat "$CALLS")" "workspace-action --workspace workspace:8 --action set-description --description"
rm -f "$CALLS"

output="$($CLI sync --dry-run)"
assert_contains "$output" "skip existing	@active/alpha"
assert_contains "$output" "would-create-workspace	@active/beta"
assert_contains "$output" "skip duplicate-target	@active/beta-copy"
assert_contains "$output" "skip broken-or-non-dir	missing"
assert_contains "$output" "summary	mode=dry-run	direction=active-to-cmux"
assert_contains "$output" "note	dry-run	apply with: c4j sync --apply"
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

output="$($CLI repair)"
assert_contains "$output" "summary	mode=dry-run	direction=both"

output="$($CLI sync --direction cmux-to-active --apply)"
assert_contains "$output" "create-link	@active/delta"
[ -L "$ACTIVE/delta" ] || fail "reverse apply should create symlink"
resolved="$(cd "$ACTIVE/delta" && pwd -P)"
expected_delta="$(cd "$PROJECTS/delta" && pwd -P)"
[ "$resolved" = "$expected_delta" ] || fail "delta symlink points to wrong target: $resolved"
rm -f "$ACTIVE/gamma"

output="$($CLI add)"
assert_contains "$output" "summary	mode=dry-run	direction=both"
[ ! -e "$ACTIVE/gamma" ] || fail "plain no-arg add should not create symlink"

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

output="$($CLI delete --dry-run gamma)"
assert_contains "$output" "would-unlink	gamma	$ACTIVE/gamma"
assert_contains "$output" "would-close-workspace	@active/gamma	workspace:3"
assert_contains "$output" "note	dry-run	apply with: c4j delete gamma --apply"
[ -L "$ACTIVE/gamma" ] || fail "delete dry-run should not remove symlink"

output="$($CLI delete --apply gamma)"
assert_contains "$output" "unlink	gamma	$ACTIVE/gamma"
assert_contains "$output" "close-workspace	@active/gamma	workspace:3"
[ ! -e "$ACTIVE/gamma" ] || fail "delete apply should remove symlink"
assert_contains "$(cat "$CALLS")" "close-workspace --workspace workspace:3"
rm -f "$CALLS"

output="$($CLI add --apply "$PROJECTS/gamma")"
assert_contains "$output" "link	$ACTIVE/gamma"
rm -f "$CALLS"
output="$($CLI rm --apply --keep-cmux "$PROJECTS/gamma")"
assert_contains "$output" "unlink	gamma	$ACTIVE/gamma"
assert_contains "$output" "skip cmux-kept	@active/gamma"
[ ! -e "$CALLS" ] || fail "delete --keep-cmux should not call cmux"

rm -f "$CALLS"
output="$($CLI go --dry-run alpha)"
assert_contains "$output" "would-select-workspace	@active/alpha	workspace:1"
assert_contains "$output" "would-go-project	alpha	$PROJECTS_RESOLVED/alpha"
[ ! -e "$CALLS" ] || fail "go dry-run should not call cmux"

output="$($CLI go alpha)"
assert_contains "$output" "select-workspace	@active/alpha	workspace:1"
assert_contains "$output" "go-project	alpha	$PROJECTS_RESOLVED/alpha"
assert_contains "$(cat "$CALLS")" "select-workspace --workspace workspace:1"

rm -f "$CALLS"
output="$($CLI go beta)"
assert_contains "$output" "create-workspace	@active/beta	$PROJECTS_RESOLVED/beta"
assert_contains "$output" "go-project	beta	$PROJECTS_RESOLVED/beta"
assert_contains "$(cat "$CALLS")" "new-workspace --name @active/beta --cwd $PROJECTS_RESOLVED/beta --focus true"

rm -f "$CALLS"
output="$($CLI go --no-cmux "$PROJECTS/legacy")"
assert_contains "$output" "link	$ACTIVE/legacy	$PROJECTS_RESOLVED/legacy"
assert_contains "$output" "skip cmux-disabled	@active/legacy"
assert_contains "$output" "go-project	legacy	$PROJECTS_RESOLVED/legacy"
[ -L "$ACTIVE/legacy" ] || fail "go path should add a missing active link"
[ ! -e "$CALLS" ] || fail "go --no-cmux should not call cmux"

rm -f "$CALLS"
output="$($CLI cd alpha)"
assert_contains "$output" "cd-project	alpha	$PROJECTS_RESOLVED/alpha"
[ ! -e "$CALLS" ] || fail "cd should not call cmux"

output="$($CLI cd --dry-run beta)"
assert_contains "$output" "would-cd-project	beta	$PROJECTS_RESOLVED/beta"

if output="$($CLI cd missing-project 2>&1)"; then
  fail "cd should fail for a missing active project"
fi
assert_contains "$output" "active project not found: missing-project"

CONFLICT_PROJECT="$PROJECTS/conflict"
rm -f "$ACTIVE/conflict"
mkdir -p "$CONFLICT_PROJECT"
if output="$($CLI go "$CONFLICT_PROJECT" 2>&1)"; then
  fail "go should fail when the matching workspace points elsewhere"
fi
assert_contains "$output" "workspace already points elsewhere: @active/conflict"
[ ! -e "$ACTIVE/conflict" ] || fail "go failure should not leave a new active link"

output="$($CLI list)"
assert_contains "$output" "PROJECT"
assert_contains "$output" "PATH"
assert_contains "$output" "alpha"
assert_not_contains "$output" "gamma"
output="$($CLI list --plain)"
assert_contains "$output" $'alpha	'
assert_not_contains "$output" "PROJECT"

printf 'PASS active workflow\n'
