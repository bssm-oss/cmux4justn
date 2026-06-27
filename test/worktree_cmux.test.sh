#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=test/lib/common.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib/common.bash"

WORKTREE_REPO="$TMPDIR/home/Workspaces/repos/bssm-oss/main/justn-hyeok/cmux4justn"
make_test_git_repo "$WORKTREE_REPO"
WORKTREE_REPO_RESOLVED="$(git -C "$WORKTREE_REPO" rev-parse --show-toplevel)"
WORKTREE_ROOT_RESOLVED="${WORKTREE_REPO_RESOLVED%%/repos/*}/worktrees/bssm-oss/main/justn-hyeok/cmux4justn"

FAKE_CMUX="$TMPDIR/cmux"
CALLS="$TMPDIR/calls"
INVENTORY="$TMPDIR/inventory.json"
cat > "$INVENTORY" <<'JSON'
{"workspaces":[]}
JSON

cat > "$FAKE_CMUX" <<'FAKE'
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
  cat "$CMUX_FAKE_INVENTORY"
  exit 0
fi
case "${1:-}" in
  new-workspace)
    printf '%s\n' "$*" >> "$CMUX_FAKE_CALLS"
    [ "${CMUX_FAIL_NEW_WORKSPACE:-0}" = "0" ] || exit 9
    ;;
  select-workspace)
    printf '%s\n' "$*" >> "$CMUX_FAKE_CALLS"
    [ "${CMUX_FAIL_SELECT_WORKSPACE:-0}" = "0" ] || exit 8
    ;;
  *)
    printf 'unexpected cmux command: %s\n' "$*" >&2
    exit 2
    ;;
esac
FAKE
chmod +x "$FAKE_CMUX"

export C4J_CMUX_BIN="$FAKE_CMUX"
export CMUX_FAKE_CALLS="$CALLS"
export CMUX_FAKE_INVENTORY="$INVENTORY"

cd "$WORKTREE_REPO"

output="$($CLI wt --dry-run --name api)"
assert_contains "$output" "would-create-worktree	api	$WORKTREE_ROOT_RESOLVED/api	worktree/api"
assert_contains "$output" "target_type=worktree"
assert_contains "$output" "would-create-workspace	workspace	@active/cmux4justn-api	true"
[ ! -e "$CALLS" ] || fail "dry-run should not call cmux"

output="$($CLI wt --dry-run --command list dispatch-command)"
assert_contains "$output" "would-create-worktree	dispatch-command	$WORKTREE_ROOT_RESOLVED/dispatch-command	worktree/dispatch-command"
assert_contains "$output" "would-run-command	command	list	false	reason=dry-run"
assert_not_contains "$output" "WORKTREE"

output="$($CLI wt --dry-run --workspace-name prune dispatch-workspace)"
assert_contains "$output" "would-create-worktree	dispatch-workspace	$WORKTREE_ROOT_RESOLVED/dispatch-workspace	worktree/dispatch-workspace"
assert_contains "$output" "would-create-workspace	workspace	prune	true"

stdout="$TMPDIR/api.stdout"
stderr="$TMPDIR/api.stderr"
"$CLI" wt --name api >"$stdout" 2>"$stderr"
[ "$(cat "$stdout")" = "$WORKTREE_ROOT_RESOLVED/api" ] || fail "wt should print only worktree path"
assert_contains "$(cat "$stderr")" "create-worktree	api	$WORKTREE_ROOT_RESOLVED/api	worktree/api"
assert_contains "$(cat "$stderr")" "create-workspace	@active/cmux4justn-api	$WORKTREE_ROOT_RESOLVED/api"
assert_contains "$(cat "$CALLS")" "new-workspace --name @active/cmux4justn-api --cwd $WORKTREE_ROOT_RESOLVED/api --focus true"

cat > "$INVENTORY" <<JSON
{"workspaces":[{"title":"custom/path-match","current_directory":"$WORKTREE_ROOT_RESOLVED/api","ref":"workspace:55"}]}
JSON
rm -f "$CALLS"
"$CLI" wt --name api >"$stdout" 2>"$stderr"
[ "$(cat "$stdout")" = "$WORKTREE_ROOT_RESOLVED/api" ] || fail "reused wt should print only worktree path"
assert_contains "$(cat "$stderr")" "reuse-worktree	api	$WORKTREE_ROOT_RESOLVED/api"
assert_contains "$(cat "$stderr")" "select-workspace	custom/path-match	workspace:55"
assert_contains "$(cat "$CALLS")" "select-workspace --workspace workspace:55"

cat > "$INVENTORY" <<'JSON'
{"workspaces":[]}
JSON
rm -f "$CALLS"
"$CLI" wt --name custom --workspace-name custom-name >"$stdout" 2>"$stderr"
[ "$(cat "$stdout")" = "$WORKTREE_ROOT_RESOLVED/custom" ] || fail "custom workspace wt should print only path"
assert_contains "$(cat "$CALLS")" "new-workspace --name custom-name --cwd $WORKTREE_ROOT_RESOLVED/custom --focus true"

rm -f "$CALLS"
"$CLI" wt --name nocmux --no-cmux >"$stdout" 2>"$stderr"
[ "$(cat "$stdout")" = "$WORKTREE_ROOT_RESOLVED/nocmux" ] || fail "no-cmux wt should print only path"
assert_contains "$(cat "$stderr")" "skip cmux-disabled	@active/cmux4justn-nocmux"
[ ! -e "$CALLS" ] || fail "--no-cmux should not invoke cmux"

rm -f "$CALLS"
CMUX_FAIL_NEW_WORKSPACE=1 "$CLI" wt --name cmuxfail >"$stdout" 2>"$stderr"
[ "$(cat "$stdout")" = "$WORKTREE_ROOT_RESOLVED/cmuxfail" ] || fail "cmux failure should keep stdout path"
assert_contains "$(cat "$stderr")" "warning: failed to create cmux workspace"
[ -d "$WORKTREE_ROOT_RESOLVED/cmuxfail" ] || fail "cmux failure should not roll back worktree"

"$CLI" wt --name cmdok --no-cmux --command 'printf "command-output\n"' >"$stdout" 2>"$stderr"
[ "$(cat "$stdout")" = "$WORKTREE_ROOT_RESOLVED/cmdok" ] || fail "command success should keep stdout path"
assert_contains "$(cat "$stderr")" "command-output"

set +e
"$CLI" wt --name cmdfail --no-cmux --command 'printf "command-failed\n"; exit 7' >"$stdout" 2>"$stderr"
status=$?
set -e
[ "$status" -eq 7 ] || fail "command failure should return command exit code, got $status"
[ "$(cat "$stdout")" = "$WORKTREE_ROOT_RESOLVED/cmdfail" ] || fail "command failure should keep stdout path"
assert_contains "$(cat "$stderr")" "command-failed"

printf 'PASS worktree cmux workflow\n'
