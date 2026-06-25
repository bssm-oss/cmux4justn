#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=test/lib/common.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib/common.bash"

ACTIVE="$TMPDIR/@active"
PROJECTS="$TMPDIR/projects"
mkdir -p "$ACTIVE" "$PROJECTS/alpha" "$PROJECTS/beta"
ln -s "$PROJECTS/alpha" "$ACTIVE/alpha"
ln -s "$PROJECTS/beta" "$ACTIVE/beta"
PROJECTS_RESOLVED="$(cd "$PROJECTS" && pwd -P)"

FAKE_CMUX="$TMPDIR/cmux"
CALLS="$TMPDIR/calls"
export CMUX_FAKE_CALLS="$CALLS"
export CMUX_TEST_PROJECTS="$PROJECTS_RESOLVED"
make_basic_cmux_stub "$FAKE_CMUX"
export C4J_ACTIVE_DIR="$ACTIVE"
export C4J_CMUX_BIN="$FAKE_CMUX"

output="$($CLI doctor)"
assert_contains "$output" "active_dir"
assert_contains "$output" "cmux_bin"

SETUP_HOME="$TMPDIR/setup-home"
SETUP_ACTIVE="$TMPDIR/setup-active"
mkdir -p "$SETUP_HOME" "$SETUP_ACTIVE"
SETUP_ACTIVE_RESOLVED="$(cd "$SETUP_ACTIVE" && pwd -P)"
output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$SETUP_HOME" C4J_CMUX_BIN="$FAKE_CMUX" "$CLI" setup --dry-run --active-dir "$SETUP_ACTIVE")"
assert_contains "$output" "would-set	name_prefix	@active/"
assert_contains "$output" "would-set	active_dir	$SETUP_ACTIVE_RESOLVED"
assert_contains "$output" "note	dry-run	apply with: c4j setup --active-dir $SETUP_ACTIVE --apply"
[ ! -e "$SETUP_HOME/.c4j/config" ] || fail "setup dry-run should not write config"

output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$SETUP_HOME" C4J_CMUX_BIN="$FAKE_CMUX" "$CLI" setup --active-dir "$SETUP_ACTIVE")"
assert_contains "$output" "set	name_prefix	@active/"
assert_contains "$output" "set	active_dir	$SETUP_ACTIVE_RESOLVED"
output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$SETUP_HOME" C4J_CMUX_BIN="$FAKE_CMUX" "$CLI" config get)"
assert_contains "$output" "name_prefix	@active/"
assert_contains "$output" "active_dir	$SETUP_ACTIVE_RESOLVED"

CONFIG_HOME="$TMPDIR/config-home"
CONFIG_ACTIVE="$TMPDIR/config-active"
mkdir -p "$CONFIG_HOME" "$CONFIG_ACTIVE"
CONFIG_ACTIVE_RESOLVED="$(cd "$CONFIG_ACTIVE" && pwd -P)"
output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$CONFIG_HOME" C4J_CMUX_BIN="$FAKE_CMUX" "$CLI" config set active-dir "$CONFIG_ACTIVE")"
assert_contains "$output" "set	active_dir	$CONFIG_ACTIVE_RESOLVED"
output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$CONFIG_HOME" C4J_CMUX_BIN="$FAKE_CMUX" "$CLI" config get)"
assert_contains "$output" "active_dir	$CONFIG_ACTIVE_RESOLVED"
output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$CONFIG_HOME" C4J_CMUX_BIN="$FAKE_CMUX" "$CLI" config set name-prefix "mine/")"
assert_contains "$output" "set	name_prefix	mine/"
output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$CONFIG_HOME" C4J_CMUX_BIN="$FAKE_CMUX" "$CLI" config get)"
assert_contains "$output" "name_prefix	mine/"
output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$CONFIG_HOME" C4J_CMUX_BIN="$FAKE_CMUX" "$CLI" config unset prefix)"
assert_contains "$output" "unset	name_prefix"
output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$CONFIG_HOME" "$CLI" config set cmux-bin "$FAKE_CMUX")"
assert_contains "$output" "set	cmux_bin	$FAKE_CMUX"
if output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$CONFIG_HOME" "$CLI" config set cmux-bin $'bad\nvalue' 2>&1)"; then
  fail "cmux-bin config should reject newlines"
fi
assert_contains "$output" "invalid value for cmux-bin"
output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$CONFIG_HOME" "$CLI" config unset cmux-bin)"
assert_contains "$output" "unset	cmux_bin"
output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$CONFIG_HOME" C4J_CMUX_BIN="$FAKE_CMUX" "$CLI" doctor)"
assert_contains "$output" "config_file	$CONFIG_HOME/.c4j/config	ok"
assert_contains "$output" "active_dir	$CONFIG_ACTIVE_RESOLVED	ok"
output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$CONFIG_HOME" "$CLI" config unset active-dir)"
assert_contains "$output" "unset	active_dir"

printf 'PASS setup/config/doctor workflow\n'
