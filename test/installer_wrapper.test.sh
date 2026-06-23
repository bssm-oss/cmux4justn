#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=test/lib/common.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib/common.bash"

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

INSTALL_RC="$TMPDIR/zshrc"
INSTALL_BIN_DIR="$TMPDIR/bin"
INSTALL_HOME="$TMPDIR/install-home"
INSTALL_CONFIG="$TMPDIR/install-config/config"
INSTALL_ACTIVE="$ACTIVE"

run_install() {
  HOME="$INSTALL_HOME" C4J_CONFIG="$INSTALL_CONFIG" C4J_ACTIVE_DIR="$INSTALL_ACTIVE" bash "$ROOT/scripts/install.sh" "$@"
}

install_output="$(HOME="$INSTALL_HOME" C4J_CONFIG="$INSTALL_CONFIG" C4J_ACTIVE_DIR="$INSTALL_ACTIVE" C4J_BIN_DIR="$INSTALL_BIN_DIR" C4J_SHELL_RC="$INSTALL_RC" bash "$ROOT/scripts/install.sh" --dry-run)"
assert_contains "$install_output" "would-install-bin	$ROOT/bin/cmux4justn	$INSTALL_BIN_DIR/c4j"
assert_contains "$install_output" "would-skip-rc"
[ ! -e "$INSTALL_BIN_DIR/c4j" ] || fail "install dry-run should not create bin"

install_output="$(run_install --shell-rc "$INSTALL_RC" --bin-dir "$INSTALL_BIN_DIR")"
assert_contains "$install_output" "installed-bin	$INSTALL_BIN_DIR/c4j"
assert_contains "$install_output" "installed-rc	$INSTALL_RC"
assert_contains "$(cat "$INSTALL_RC")" "c4j()"
assert_contains "$(cat "$INSTALL_RC")" "$C4J_ACTION_CD_PROJECT"
assert_contains "$(cat "$INSTALL_RC")" "builtin cd --"

WRAPPER_OUT="$TMPDIR/wrapper-out"
WRAPPER_DRY_RUN_OUT="$TMPDIR/wrapper-dry-run-out"
WRAPPER_PWD="$TMPDIR/wrapper-pwd"
WRAPPER_SCRIPT="$TMPDIR/wrapper-check.sh"
cat > "$WRAPPER_SCRIPT" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$INSTALL_RC"
cd "$TMPDIR"
c4j cd alpha > "$WRAPPER_OUT"
pwd -P > "$WRAPPER_PWD"
c4j cd --dry-run beta > "$WRAPPER_DRY_RUN_OUT"
EOF
HOME="$INSTALL_HOME" C4J_ACTIVE_DIR="$ACTIVE" C4J_CMUX_BIN="$FAKE_CMUX" bash "$WRAPPER_SCRIPT"
[ "$(cat "$WRAPPER_PWD")" = "$PROJECTS_RESOLVED/alpha" ] || fail "wrapper cd should change the caller shell directory"
[ ! -s "$WRAPPER_OUT" ] || fail "wrapper cd should be quiet on success"
assert_contains "$(cat "$WRAPPER_DRY_RUN_OUT")" "would-$C4J_ACTION_CD_PROJECT	beta	$PROJECTS_RESOLVED/beta"

BROKEN_RC="$TMPDIR/broken-zshrc"
printf '%s\n' "keep-before" "# >>> c4j >>>" "keep-after" > "$BROKEN_RC"
if install_output="$(run_install --shell-rc "$BROKEN_RC" --no-bin 2>&1)"; then
  fail "install should reject shell rc with an unmatched c4j marker"
fi
assert_contains "$install_output" "without matching"
assert_contains "$(cat "$BROKEN_RC")" "keep-after"

printf 'PASS installer wrapper workflow\n'
