#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CLI="$ROOT/bin/c4j"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
export HOME="$TMPDIR/home"
unset C4J_CONFIG CMUX4JUSTN_CONFIG

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if ! printf '%s\n' "$haystack" | grep -F -- "$needle" >/dev/null; then
    fail "expected output to contain: $needle"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if printf '%s\n' "$haystack" | grep -F -- "$needle" >/dev/null; then
    fail "expected output not to contain: $needle"
  fi
}

ACTIVE="$TMPDIR/@active"
PROJECTS="$TMPDIR/projects"
mkdir -p "$ACTIVE" "$PROJECTS/alpha" "$PROJECTS/beta" "$PROJECTS/gamma" "$PROJECTS/delta" "$PROJECTS/legacy" "$PROJECTS/unsafe"
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
    {"title": "@active/bad/name", "current_directory": "$CMUX_TEST_PROJECTS/unsafe", "ref": "workspace:4"},
    {"title": "other", "current_directory": "$CMUX_TEST_PROJECTS/gamma", "ref": "workspace:5"},
    {"title": "justn-is-always-around-here", "current_directory": "$CMUX_TEST_PROJECTS", "ref": "workspace:8"}
  ]
}
JSON
  exit 0
fi

case "${1:-}" in
  new-workspace|close-workspace|workspace-action|new-pane|send|send-key)
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
export CMUX_TEST_PROJECTS="$PROJECTS"
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

WORKTREE_REPO="$TMPDIR/home/Workspaces/repos/bssm-oss/main/justn-hyeok/cmux4justn"
mkdir -p "$WORKTREE_REPO"
git -C "$WORKTREE_REPO" init >/dev/null
git -C "$WORKTREE_REPO" symbolic-ref HEAD refs/heads/main
git -C "$WORKTREE_REPO" config user.name "Test User"
git -C "$WORKTREE_REPO" config user.email "test@example.com"
printf 'hello\n' > "$WORKTREE_REPO/README.md"
git -C "$WORKTREE_REPO" add README.md
git -C "$WORKTREE_REPO" commit -m "init" >/dev/null
WORKTREE_HOME_RESOLVED="$(cd "$TMPDIR/home" && pwd -P)"
WORKTREE_ROOT_RESOLVED="$WORKTREE_HOME_RESOLVED/Workspaces/worktrees/bssm-oss/main/justn-hyeok/cmux4justn"
WORKTREE_OLDPWD="$PWD"
cd "$WORKTREE_REPO"

output="$($CLI worktree --dry-run)"
assert_contains "$output" "would-create-worktree	cmux4justn-main	$WORKTREE_ROOT_RESOLVED/cmux4justn-main	worktree/cmux4justn-main"
assert_contains "$output" "note	dry-run	apply with: c4j worktree --apply"
[ ! -e "$WORKTREE_ROOT_RESOLVED/cmux4justn-main" ] || fail "worktree dry-run should not create worktree"

output="$($CLI worktree --apply)"
assert_contains "$output" "create-worktree	cmux4justn-main	$WORKTREE_ROOT_RESOLVED/cmux4justn-main	worktree/cmux4justn-main"
[ -d "$WORKTREE_ROOT_RESOLVED/cmux4justn-main" ] || fail "worktree apply should create worktree"
assert_contains "$(git -C "$WORKTREE_ROOT_RESOLVED/cmux4justn-main" branch --show-current)" "worktree/cmux4justn-main"

output="$($CLI worktree --apply)"
assert_contains "$output" "create-worktree	cmux4justn-main-2	$WORKTREE_ROOT_RESOLVED/cmux4justn-main-2	worktree/cmux4justn-main-2"
[ -d "$WORKTREE_ROOT_RESOLVED/cmux4justn-main-2" ] || fail "second worktree apply should create a suffixed worktree"

output="$($CLI worktree --apply --name api)"
assert_contains "$output" "create-worktree	api	$WORKTREE_ROOT_RESOLVED/api	worktree/api"
[ -d "$WORKTREE_ROOT_RESOLVED/api" ] || fail "named worktree apply should create explicit worktree"

output="$($CLI worktree --dry-run --name docs)"
assert_contains "$output" "would-create-worktree	docs	$WORKTREE_ROOT_RESOLVED/docs	worktree/docs"
output="$($CLI wt for-feature1 --dry-run)"
assert_contains "$output" "would-create-worktree	for-feature1	$WORKTREE_ROOT_RESOLVED/for-feature1	worktree/for-feature1"

output="$($CLI wt for-feature1)"
assert_contains "$output" "create-worktree	for-feature1	$WORKTREE_ROOT_RESOLVED/for-feature1	worktree/for-feature1"
[ -d "$WORKTREE_ROOT_RESOLVED/for-feature1" ] || fail "positional wt should create explicit worktree"
cd "$WORKTREE_OLDPWD"

output="$($CLI sync --direction cmux-to-active --dry-run)"
assert_contains "$output" "skip existing-link	@active/alpha"
assert_contains "$output" "would-create-link	@active/delta"
assert_contains "$output" "skip unsafe-name	@active/bad/name"
[ ! -e "$ACTIVE/delta" ] || fail "reverse dry-run should not create symlink"

output="$($CLI sync --direction cmux-to-active --apply)"
assert_contains "$output" "create-link	@active/delta"
[ -L "$ACTIVE/delta" ] || fail "reverse apply should create symlink"
resolved="$(cd "$ACTIVE/delta" && pwd -P)"
expected_delta="$(cd "$PROJECTS/delta" && pwd -P)"
[ "$resolved" = "$expected_delta" ] || fail "delta symlink points to wrong target: $resolved"
rm -f "$ACTIVE/gamma"

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

output="$($CLI list)"
assert_contains "$output" "PROJECT"
assert_contains "$output" "PATH"
assert_contains "$output" "alpha"
assert_not_contains "$output" "gamma"
output="$($CLI list --plain)"
assert_contains "$output" $'alpha	'
assert_not_contains "$output" "PROJECT"

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
cd "$OLDPWD"

INSTALL_RC="$TMPDIR/zshrc"
INSTALL_BIN_DIR="$TMPDIR/bin"
INSTALL_HOME="$TMPDIR/install-home"
INSTALL_CONFIG="$TMPDIR/install-config/config"
INSTALL_ACTIVE="$TMPDIR/install-active"

run_install() {
  HOME="$INSTALL_HOME" C4J_CONFIG="$INSTALL_CONFIG" C4J_ACTIVE_DIR="$INSTALL_ACTIVE" bash "$ROOT/scripts/install.sh" "$@"
}

install_output="$(HOME="$INSTALL_HOME" C4J_CONFIG="$INSTALL_CONFIG" C4J_ACTIVE_DIR="$INSTALL_ACTIVE" C4J_BIN_DIR="$INSTALL_BIN_DIR" C4J_SHELL_RC="$INSTALL_RC" bash "$ROOT/scripts/install.sh" --dry-run)"
assert_contains "$install_output" "would-install-bin	$ROOT/bin/cmux4justn	$INSTALL_BIN_DIR/c4j"
assert_contains "$install_output" "would-skip-rc"
[ ! -e "$INSTALL_BIN_DIR/c4j" ] || fail "install dry-run should not create bin"
[ ! -e "$INSTALL_RC" ] || fail "install dry-run should not create shell rc"

{
  printf '%s\n' "# >>> c4j >>>"
  printf "alias c4j='%s'\n" "$INSTALL_BIN_DIR/c4j"
  printf '%s\n' "# <<< c4j <<<"
} > "$INSTALL_RC"
mkdir -p "$INSTALL_BIN_DIR"
install -m 0755 "$ROOT/bin/cmux4justn" "$INSTALL_BIN_DIR/c4j"
install_output="$(run_install --shell-rc "$INSTALL_RC" --bin-dir "$INSTALL_BIN_DIR")"
assert_contains "$install_output" "skip existing-bin	$INSTALL_BIN_DIR/c4j"
assert_contains "$install_output" "skip existing-alias	$INSTALL_RC"
assert_contains "$install_output" "installed-completion	$INSTALL_RC"
assert_contains "$(cat "$INSTALL_RC")" "source $ROOT/completions/c4j.bash"
rm -f "$INSTALL_RC" "$INSTALL_BIN_DIR/c4j"

install_output="$(run_install --dry-run --shell-rc "$INSTALL_RC" --bin-dir "$INSTALL_BIN_DIR")"
assert_contains "$install_output" "would-install-bin"
assert_contains "$install_output" "would-update-rc	$INSTALL_RC"
assert_contains "$install_output" "$ROOT/completions/c4j.bash"
[ ! -e "$INSTALL_BIN_DIR/c4j" ] || fail "install dry-run should not create bin copy"

install_output="$(run_install --dry-run --no-rc --bin-dir "$INSTALL_BIN_DIR")"
assert_contains "$install_output" "would-skip-rc"
assert_not_contains "$install_output" "would-update-rc"

install_output="$(run_install --no-rc --bin-dir "$INSTALL_BIN_DIR")"
assert_contains "$install_output" "installed-bin	$INSTALL_BIN_DIR/c4j"
assert_contains "$install_output" "skip rc-update"
[ -x "$INSTALL_BIN_DIR/c4j" ] || fail "install apply should create executable bin copy"

install_output="$(run_install --no-rc --bin-dir "$INSTALL_BIN_DIR")"
assert_contains "$install_output" "skip existing-bin	$INSTALL_BIN_DIR/c4j"

printf 'different\n' > "$INSTALL_BIN_DIR/c4j"
if install_output="$(run_install --no-rc --bin-dir "$INSTALL_BIN_DIR" 2>&1)"; then
  fail "install should fail rather than overwrite different bin target"
fi
assert_contains "$install_output" "target executable already exists and differs"

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
output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$CONFIG_HOME" C4J_CMUX_BIN="$FAKE_CMUX" "$CLI" doctor)"
assert_contains "$output" "config_file	$CONFIG_HOME/.c4j/config	ok"
assert_contains "$output" "active_dir	$CONFIG_ACTIVE_RESOLVED	ok"
output="$(env -u C4J_ACTIVE_DIR -u CMUX4JUSTN_ACTIVE_DIR HOME="$CONFIG_HOME" "$CLI" config unset active-dir)"
assert_contains "$output" "unset	active_dir"

BOOTSTRAP_HOME="$TMPDIR/bootstrap-home"
BOOTSTRAP_INSTALL_DIR="$TMPDIR/bootstrap-source"
BOOTSTRAP_ACTIVE="$TMPDIR/bootstrap-active"
mkdir -p "$BOOTSTRAP_HOME" "$BOOTSTRAP_ACTIVE"
cp "$ROOT/install.sh" "$TMPDIR/bootstrap-install.sh"
chmod +x "$TMPDIR/bootstrap-install.sh"
output="$(HOME="$BOOTSTRAP_HOME" C4J_REPO_URL="file://$ROOT" C4J_REF="main" C4J_INSTALL_DIR="$BOOTSTRAP_INSTALL_DIR" C4J_ACTIVE_DIR="$BOOTSTRAP_ACTIVE" bash "$TMPDIR/bootstrap-install.sh" --no-rc)"
assert_contains "$output" "download-source	file://$ROOT	$BOOTSTRAP_INSTALL_DIR"
assert_contains "$output" "installed-bin	$BOOTSTRAP_HOME/.local/bin/c4j"
assert_contains "$output" "active-dir"
[ -x "$BOOTSTRAP_HOME/.local/bin/c4j" ] || fail "bootstrap install should create c4j executable"

STDIN_BOOTSTRAP_HOME="$TMPDIR/stdin-bootstrap-home"
STDIN_BOOTSTRAP_INSTALL_DIR="$TMPDIR/stdin-bootstrap-source"
STDIN_BOOTSTRAP_ACTIVE="$TMPDIR/stdin-bootstrap-active"
STDIN_BOOTSTRAP_ERR="$TMPDIR/stdin-bootstrap.err"
mkdir -p "$STDIN_BOOTSTRAP_HOME" "$STDIN_BOOTSTRAP_ACTIVE"
output="$(HOME="$STDIN_BOOTSTRAP_HOME" C4J_REPO_URL="file://$ROOT" C4J_REF="main" C4J_INSTALL_DIR="$STDIN_BOOTSTRAP_INSTALL_DIR" C4J_ACTIVE_DIR="$STDIN_BOOTSTRAP_ACTIVE" bash -s -- --no-rc < "$ROOT/install.sh" 2>"$STDIN_BOOTSTRAP_ERR")"
! grep -q "BASH_SOURCE" "$STDIN_BOOTSTRAP_ERR" || fail "stdin bootstrap should not warn about BASH_SOURCE"
assert_contains "$output" "download-source	file://$ROOT	$STDIN_BOOTSTRAP_INSTALL_DIR"
assert_contains "$output" "installed-bin	$STDIN_BOOTSTRAP_HOME/.local/bin/c4j"
[ -x "$STDIN_BOOTSTRAP_HOME/.local/bin/c4j" ] || fail "stdin bootstrap install should create c4j executable"

[ "$($CLI version)" = "0.11.0" ] || fail "version mismatch"
[ "$("$ROOT/bin/cmux4justn" version)" = "0.11.0" ] || fail "legacy version mismatch"

printf 'PASS cmux4justn tests\n'
