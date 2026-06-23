#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=test/lib/common.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib/common.bash"

output="$($CLI)"
assert_contains "$output" "c4j v$CURRENT_VERSION"
assert_contains "$output" "I want to:"
assert_contains "$output" "go <project>"
assert_contains "$output" "repair --apply"
assert_not_contains "$output" "Environment:"

output="$($CLI help go)"
assert_contains "$output" "c4j go <project-or-folder>"
assert_contains "$output" "Open a project."

output="$($CLI help cd)"
assert_contains "$output" "c4j cd <project-or-folder>"
assert_contains "$output" "Change directory"

ACTIVE="$TMPDIR/@active"
PROJECTS="$TMPDIR/projects"
mkdir -p "$ACTIVE" "$PROJECTS/alpha" "$PROJECTS/beta"
PROJECTS_RESOLVED="$(cd "$PROJECTS" && pwd -P)"
ln -s "$PROJECTS/alpha" "$ACTIVE/alpha"
ln -s "$PROJECTS/beta" "$ACTIVE/beta"

FAKE_CMUX="$TMPDIR/cmux"
CALLS="$TMPDIR/calls"
make_basic_cmux_stub "$FAKE_CMUX"
export CMUX_FAKE_CALLS="$CALLS"
export CMUX_TEST_PROJECTS="$PROJECTS_RESOLVED"
export C4J_ACTIVE_DIR="$ACTIVE"
export C4J_CMUX_BIN="$FAKE_CMUX"

output="$($CLI go --dry-run alpha)"
assert_contains "$output" "would-select-workspace	@active/alpha	workspace:1"
assert_contains "$output" "would-$C4J_ACTION_GO_PROJECT	alpha	$PROJECTS_RESOLVED/alpha"
[ ! -e "$CALLS" ] || fail "go dry-run should not call cmux"

output="$($CLI go alpha)"
assert_contains "$output" "select-workspace	@active/alpha	workspace:1"
assert_contains "$output" "$C4J_ACTION_GO_PROJECT	alpha	$PROJECTS_RESOLVED/alpha"
assert_contains "$(cat "$CALLS")" "select-workspace --workspace workspace:1"

rm -f "$CALLS"
output="$($CLI cd alpha)"
assert_contains "$output" "$C4J_ACTION_CD_PROJECT	alpha	$PROJECTS_RESOLVED/alpha"
[ ! -e "$CALLS" ] || fail "cd should not call cmux"

output="$($CLI cd --dry-run beta)"
assert_contains "$output" "would-$C4J_ACTION_CD_PROJECT	beta	$PROJECTS_RESOLVED/beta"

printf 'PASS help/go/cd smoke\n'
