#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=test/lib/common.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib/common.bash"

ACTIVE="$TMPDIR/@active"
PROJECTS="$TMPDIR/projects"
mkdir -p "$ACTIVE" "$PROJECTS/alpha" "$PROJECTS/beta"
ln -s "$PROJECTS/alpha" "$ACTIVE/alpha"
ln -s "$PROJECTS/beta" "$ACTIVE/beta"
ln -s "$PROJECTS/beta" "$ACTIVE/beta-copy"
export C4J_ACTIVE_DIR="$ACTIVE"

COMPLETION_ROOT="$TMPDIR/completion-root"
mkdir -p "$COMPLETION_ROOT/alpha" "$COMPLETION_ROOT/beta"
OLDPWD="$PWD"
cd "$COMPLETION_ROOT"
# shellcheck source=/dev/null
source "$ROOT/completions/c4j.bash"

COMP_WORDS=(c4j setup --active-dir "")
COMP_CWORD=3
_c4j_complete
assert_contains "${COMPREPLY[*]}" "alpha"

COMP_WORDS=(c4j add "")
COMP_CWORD=2
_c4j_complete
assert_contains "${COMPREPLY[*]}" "beta"

COMP_WORDS=(c4j cd beta-)
COMP_CWORD=2
_c4j_complete
assert_contains "${COMPREPLY[*]}" "beta-copy"

COMP_WORDS=(c4j h)
COMP_CWORD=1
_c4j_complete
assert_contains "${COMPREPLY[*]}" "help"

COMP_WORDS=(c4j r)
COMP_CWORD=1
_c4j_complete
assert_contains "${COMPREPLY[*]}" "repair"
assert_contains "${COMPREPLY[*]}" "reconcile"

COMP_WORDS=(c4j help "")
COMP_CWORD=2
_c4j_complete
assert_contains "${COMPREPLY[*]}" "agent"
assert_contains "${COMPREPLY[*]}" "go"

COMP_WORDS=(c4j help wt "")
COMP_CWORD=3
_c4j_complete
assert_contains "${COMPREPLY[*]}" "move"

COMP_WORDS=(c4j help wt r)
COMP_CWORD=3
_c4j_complete
assert_contains "${COMPREPLY[*]}" "remove"

COMP_WORDS=(c4j config unset cmux-)
COMP_CWORD=3
_c4j_complete
assert_contains "${COMPREPLY[*]}" "cmux-bin"

COMP_WORDS=(c4j sync --cmux "")
COMP_CWORD=3
_c4j_complete
assert_contains "${COMPREPLY[*]}" "alpha"

cd "$OLDPWD"
printf 'PASS completion workflow\n'
