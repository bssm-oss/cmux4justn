#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=test/lib/common.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib/common.bash"

WORKTREE_REPO="$TMPDIR/home/Workspaces/repos/bssm-oss/main/justn-hyeok/cmux4justn"
make_test_git_repo "$WORKTREE_REPO"
REMOTE_REPO="$TMPDIR/remote.git"
git init --bare "$REMOTE_REPO" >/dev/null
git -C "$WORKTREE_REPO" remote add origin "$REMOTE_REPO"
git -C "$WORKTREE_REPO" push -u origin main >/dev/null

WORKTREE_REPO_RESOLVED="$(git -C "$WORKTREE_REPO" rev-parse --show-toplevel)"
WORKTREE_ROOT_RESOLVED="${WORKTREE_REPO_RESOLVED%%/repos/*}/worktrees/bssm-oss/main/justn-hyeok/cmux4justn"
export C4J_CMUX_BIN="$TMPDIR/no-cmux"

cd "$WORKTREE_REPO"

output="$($CLI worktree --dry-run --name api)"
assert_contains "$output" "would-create-worktree	api	$WORKTREE_ROOT_RESOLVED/api	worktree/api"
assert_contains "$output" "target_type=worktree"
assert_contains "$output" "would_change=true"
[ ! -e "$WORKTREE_ROOT_RESOLVED" ] || fail "worktree dry-run should not create worktree base directory"

stdout="$TMPDIR/wt.stdout"
stderr="$TMPDIR/wt.stderr"
"$CLI" worktree --apply --name api >"$stdout" 2>"$stderr"
[ "$(cat "$stdout")" = "$WORKTREE_ROOT_RESOLVED/api" ] || fail "worktree apply should print only final path to stdout"
assert_contains "$(cat "$stderr")" "$C4J_ACTION_CREATE_WORKTREE	api	$WORKTREE_ROOT_RESOLVED/api	worktree/api"
assert_contains "$(cat "$stderr")" "warning: cmux unavailable"
[ -d "$WORKTREE_ROOT_RESOLVED/api" ] || fail "worktree apply should create worktree"
output="$($CLI wt --dry-run delete api)"
assert_contains "$output" "would-delete-worktree	api	$WORKTREE_ROOT_RESOLVED/api	worktree/api"
[ -d "$WORKTREE_ROOT_RESOLVED/api" ] || fail "prefix dry-run delete should not remove worktree"

output="$($CLI wt --dry-run move api api-dry)"
assert_contains "$output" "would-move-worktree	api	$WORKTREE_ROOT_RESOLVED/api	$WORKTREE_ROOT_RESOLVED/api-dry	worktree/api"
[ -d "$WORKTREE_ROOT_RESOLVED/api" ] || fail "prefix dry-run move should leave source worktree"
[ ! -e "$WORKTREE_ROOT_RESOLVED/api-dry" ] || fail "prefix dry-run move should not create destination"

output="$($CLI wt list)"
assert_contains "$output" "cmux4justn"
assert_contains "$output" "api"

output="$($CLI wt move api api-v2)"
assert_contains "$output" "$C4J_ACTION_MOVE_WORKTREE	api	$WORKTREE_ROOT_RESOLVED/api	$WORKTREE_ROOT_RESOLVED/api-v2	worktree/api"
[ -d "$WORKTREE_ROOT_RESOLVED/api-v2" ] || fail "move should create destination worktree"
[ ! -d "$WORKTREE_ROOT_RESOLVED/api" ] || fail "move should remove source worktree"

printf 'dirty\n' > "$WORKTREE_ROOT_RESOLVED/api-v2/dirty.txt"
if output="$($CLI wt delete api-v2 2>&1)"; then
  fail "delete should reject dirty worktrees without --force or --discard"
fi
assert_contains "$output" "worktree has uncommitted or untracked changes"
[ -d "$WORKTREE_ROOT_RESOLVED/api-v2" ] || fail "failed delete should leave dirty worktree in place"

output="$($CLI wt delete --discard api-v2)"
assert_contains "$output" "delete-worktree	api-v2	$WORKTREE_ROOT_RESOLVED/api-v2	worktree/api"
[ ! -d "$WORKTREE_ROOT_RESOLVED/api-v2" ] || fail "discard delete should remove worktree"
"$CLI" wt --name current-delete --no-cmux >"$stdout" 2>"$stderr"
current_delete="$WORKTREE_ROOT_RESOLVED/current-delete"
output="$(cd "$current_delete" && "$CLI" wt --dry-run delete)"
assert_contains "$output" "would-delete-worktree	current-delete	$current_delete	worktree/current-delete"
[ -d "$current_delete" ] || fail "omitted dry-run delete should not remove current worktree"
output="$(cd "$current_delete" && "$CLI" wt delete)"
assert_contains "$output" "delete-worktree	current-delete	$current_delete	worktree/current-delete"
[ ! -d "$current_delete" ] || fail "omitted delete should remove current worktree"

"$CLI" wt --name current-move --no-cmux >"$stdout" 2>"$stderr"
current_move="$WORKTREE_ROOT_RESOLVED/current-move"
output="$(cd "$current_move" && "$CLI" wt --dry-run move current-moved)"
assert_contains "$output" "would-move-worktree	current-move	$current_move	$WORKTREE_ROOT_RESOLVED/current-moved	worktree/current-move"
[ -d "$current_move" ] || fail "omitted dry-run move should leave current worktree"
[ ! -e "$WORKTREE_ROOT_RESOLVED/current-moved" ] || fail "omitted dry-run move should not create destination"
output="$(cd "$current_move" && "$CLI" wt move current-moved)"
assert_contains "$output" "$C4J_ACTION_MOVE_WORKTREE	current-move	$current_move	$WORKTREE_ROOT_RESOLVED/current-moved	worktree/current-move"
[ -d "$WORKTREE_ROOT_RESOLVED/current-moved" ] || fail "omitted move should move current worktree"
"$CLI" wt delete --discard current-moved >/dev/null

if output="$(cd "$TMPDIR" && "$CLI" wt delete 2>&1)"; then
  fail "omitted delete outside a worktree should fail"
fi
assert_contains "$output" "worktree delete requires a target or must be run inside a worktree"

if output="$($CLI wt delete "$WORKTREE_REPO_RESOLVED" 2>&1)"; then
  fail "delete should refuse the main checkout"
fi
assert_contains "$output" "refusing to delete the main repository checkout"

"$CLI" wt --name current-dirty --no-cmux >"$stdout" 2>"$stderr"
current_dirty="$WORKTREE_ROOT_RESOLVED/current-dirty"
printf 'dirty\n' > "$current_dirty/dirty.txt"
if output="$(cd "$current_dirty" && "$CLI" wt delete 2>&1)"; then
  fail "omitted delete should reject dirty current worktree"
fi
assert_contains "$output" "worktree has uncommitted or untracked changes"
output="$(cd "$current_dirty" && "$CLI" wt delete --discard)"
assert_contains "$output" "delete-worktree	current-dirty	$current_dirty	worktree/current-dirty"
[ ! -d "$current_dirty" ] || fail "discard omitted delete should remove dirty current worktree"

FAKE_CMUX="$TMPDIR/cmux-same"
cat > "$FAKE_CMUX" <<FAKE
#!/usr/bin/env bash
set -euo pipefail
if [ "\${1:-}" = "identify" ] && [ "\${2:-}" = "--json" ]; then
  printf '%s\n' '{"caller":{"workspace_ref":"workspace:1"},"focused":{"workspace_ref":"workspace:1"}}'
  exit 0
fi
if [ "\${1:-}" = "--json" ] && [ "\${2:-}" = "list-workspaces" ]; then
  printf '%s\n' '{"workspaces":[{"title":"same","current_directory":"$WORKTREE_REPO_RESOLVED","ref":"workspace:1"}]}'
  exit 0
fi
exit 2
FAKE
chmod +x "$FAKE_CMUX"
"$CLI" wt --name current-cmux --no-cmux >"$stdout" 2>"$stderr"
current_cmux="$WORKTREE_ROOT_RESOLVED/current-cmux"
output="$(C4J_CMUX_BIN="$FAKE_CMUX" bash -c 'cd "$1" && "$2" wt --dry-run delete' _ "$current_cmux" "$CLI")"
assert_contains "$output" "would-delete-worktree	current-cmux	$current_cmux	worktree/current-cmux"
"$CLI" wt delete --discard current-cmux >/dev/null

OTHER_REPO="$TMPDIR/home/Workspaces/repos/example/otherrepo"
make_test_git_repo "$OTHER_REPO"
OTHER_REPO_RESOLVED="$(git -C "$OTHER_REPO" rev-parse --show-toplevel)"
FAKE_CMUX_MISMATCH="$TMPDIR/cmux-mismatch"
cat > "$FAKE_CMUX_MISMATCH" <<FAKE
#!/usr/bin/env bash
set -euo pipefail
if [ "\${1:-}" = "identify" ] && [ "\${2:-}" = "--json" ]; then
  printf '%s\n' '{"caller":{"workspace_ref":"workspace:1"},"focused":{"workspace_ref":"workspace:1"}}'
  exit 0
fi
if [ "\${1:-}" = "--json" ] && [ "\${2:-}" = "list-workspaces" ]; then
  printf '%s\n' '{"workspaces":[{"title":"mismatch","current_directory":"$OTHER_REPO_RESOLVED","ref":"workspace:1"}]}'
  exit 0
fi
exit 2
FAKE
chmod +x "$FAKE_CMUX_MISMATCH"
"$CLI" wt --name current-mismatch --no-cmux >"$stdout" 2>"$stderr"
current_mismatch="$WORKTREE_ROOT_RESOLVED/current-mismatch"
set +e
output="$(C4J_CMUX_BIN="$FAKE_CMUX_MISMATCH" bash -c 'cd "$1" && "$2" wt --dry-run delete' _ "$current_mismatch" "$CLI" 2>&1)"
status=$?
set -e
if [ "$status" -eq 0 ]; then
  assert_contains "$output" "would-delete-worktree	current-mismatch	$current_mismatch	worktree/current-mismatch"
else
  assert_contains "$output" "worktree not found"
fi
[ -d "$current_mismatch" ] || fail "cmux mismatch dry-run should not remove current worktree"
[ -d "$OTHER_REPO_RESOLVED" ] || fail "cmux mismatch dry-run should not touch other repo"
"$CLI" wt delete --discard current-mismatch >/dev/null
output="$($CLI help wt)"
assert_contains "$output" "--repo PATH"
assert_contains "$output" "--name NAME"
assert_contains "$output" "delete, remove, rm"
assert_contains "$output" "update, refresh, up"
output="$($CLI help wt list)"
assert_contains "$output" "c4j wt ls"
output="$($CLI help wt delete)"
assert_contains "$output" "--force"
assert_contains "$output" "--discard"
assert_contains "$output" "--target WORKTREE"
output="$($CLI help wt move)"
assert_contains "$output" "--destination DEST"
output="$($CLI help wt update)"
assert_contains "$output" "c4j wt refresh"

printf 'PASS worktree workflow\n'
