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
[ ! -e "$WORKTREE_ROOT_RESOLVED" ] || fail "worktree dry-run should not create worktree base directory"

output="$($CLI worktree --apply --name api)"
assert_contains "$output" "$C4J_ACTION_CREATE_WORKTREE	api	$WORKTREE_ROOT_RESOLVED/api	worktree/api"
[ -d "$WORKTREE_ROOT_RESOLVED/api" ] || fail "worktree apply should create worktree"

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

printf 'PASS worktree workflow\n'
