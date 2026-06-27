#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=test/lib/common.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib/common.bash"

output="$($CLI)"
assert_contains "$output" "c4j v$CURRENT_VERSION"
assert_contains "$output" "I want to:"
assert_contains "$output" "go <project>"
assert_contains "$output" "wt [name]"
assert_contains "$output" "repair --apply"
assert_contains "$output" "c4j help agent"
assert_contains "$output" "Tip: add --dry-run"
assert_not_contains "$output" "Environment:"
assert_not_contains "$output" "C4J_ACTIVE_DIR"

output="$($CLI help go)"
assert_contains "$output" "c4j go <project-or-folder>"
assert_contains "$output" "Open a project."
assert_not_contains "$output" "Environment:"

output="$($CLI go --help)"
assert_contains "$output" "c4j go <project-or-folder>"
assert_not_contains "$output" "I want to:"

output="$($CLI help cd)"
assert_contains "$output" "c4j cd <project-or-folder>"
assert_contains "$output" "Change directory"

output="$($CLI help wt list)"
assert_contains "$output" "c4j wt list"

output="$($CLI help wt)"
assert_contains "$output" "--no-cmux"
assert_contains "$output" "--workspace-name"
assert_contains "$output" "--command"

output="$($CLI help repair)"
assert_contains "$output" "c4j repair"
assert_contains "$output" "two-way reconciliation"

output="$($CLI help agent)"
assert_contains "$output" "For agents and scripts:"
assert_contains "$output" "c4j list --plain"
assert_contains "$output" "Parse action rows by the first tab-separated field"
assert_contains "$output" "output is plain text"

output="$($CLI doctor --help)"
assert_contains "$output" "c4j doctor"
assert_contains "$output" "Run this when c4j feels weird."

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
