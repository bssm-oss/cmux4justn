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
    {"title": "now-i-work-in-cmux4justn", "current_directory": "${WORKTREE_REPO:-}", "ref": "workspace:7"},
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

WORKTREE_REPO="$TMPDIR/home/Workspaces/repos/bssm-oss/main/justn-hyeok/cmux4justn"
mkdir -p "$WORKTREE_REPO"
git -C "$WORKTREE_REPO" init >/dev/null
git -C "$WORKTREE_REPO" symbolic-ref HEAD refs/heads/main
git -C "$WORKTREE_REPO" config user.name "Test User"
git -C "$WORKTREE_REPO" config user.email "test@example.com"
printf 'hello\n' > "$WORKTREE_REPO/README.md"
git -C "$WORKTREE_REPO" add README.md
git -C "$WORKTREE_REPO" commit -m "init" >/dev/null
export WORKTREE_REPO
REMOTE_REPO="$TMPDIR/remote.git"
git init --bare "$REMOTE_REPO" >/dev/null
git -C "$WORKTREE_REPO" remote add origin "$REMOTE_REPO"
git -C "$WORKTREE_REPO" push -u origin main >/dev/null
WORKTREE_REPO_RESOLVED="$(git -C "$WORKTREE_REPO" rev-parse --show-toplevel)"
WORKTREE_ROOT_RESOLVED="${WORKTREE_REPO_RESOLVED%%/repos/*}/worktrees/bssm-oss/main/justn-hyeok/cmux4justn"
CMUX_WORKSPACE_ROOT="$TMPDIR/cmux-workspace"
mkdir -p "$CMUX_WORKSPACE_ROOT"
WORKTREE_OLDPWD="$PWD"
cd "$CMUX_WORKSPACE_ROOT"

output="$($CLI wt feature-from-cmux --dry-run)"
assert_contains "$output" "would-create-worktree	feature-from-cmux	$WORKTREE_ROOT_RESOLVED/feature-from-cmux	worktree/feature-from-cmux"
[ ! -e "$WORKTREE_ROOT_RESOLVED/feature-from-cmux" ] || fail "cmux workspace dry-run should not create worktree"
[ ! -e "$WORKTREE_ROOT_RESOLVED" ] || fail "cmux workspace dry-run should not create worktree base directory"

output="$($CLI wt list)"
assert_contains "$output" "WORKTREE"
assert_contains "$output" "cmux4justn"
assert_not_contains "$output" "otherrepo"

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

output="$($CLI worktree --apply --name prune-me)"
assert_contains "$output" "create-worktree	prune-me	$WORKTREE_ROOT_RESOLVED/prune-me	worktree/prune-me"
[ -d "$WORKTREE_ROOT_RESOLVED/prune-me" ] || fail "prune test worktree should be created"

output="$($CLI worktree --dry-run --name docs)"
assert_contains "$output" "would-create-worktree	docs	$WORKTREE_ROOT_RESOLVED/docs	worktree/docs"
output="$($CLI wt for-feature1 --dry-run)"
assert_contains "$output" "would-create-worktree	for-feature1	$WORKTREE_ROOT_RESOLVED/for-feature1	worktree/for-feature1"

output="$($CLI wt for-feature1)"
assert_contains "$output" "create-worktree	for-feature1	$WORKTREE_ROOT_RESOLVED/for-feature1	worktree/for-feature1"
[ -d "$WORKTREE_ROOT_RESOLVED/for-feature1" ] || fail "positional wt should create explicit worktree"

OTHER_REPO="$TMPDIR/home/Workspaces/repos/bssm-oss/main/justn-hyeok/otherrepo"
mkdir -p "$OTHER_REPO"
git -C "$OTHER_REPO" init >/dev/null
git -C "$OTHER_REPO" symbolic-ref HEAD refs/heads/main
git -C "$OTHER_REPO" config user.name "Test User"
git -C "$OTHER_REPO" config user.email "test@example.com"
printf 'other\n' > "$OTHER_REPO/README.md"
git -C "$OTHER_REPO" add README.md
git -C "$OTHER_REPO" commit -m "init" >/dev/null
OTHER_REPO_RESOLVED="$(git -C "$OTHER_REPO" rev-parse --show-toplevel)"
OTHER_WORKTREE_ROOT_RESOLVED="${OTHER_REPO_RESOLVED%%/repos/*}/worktrees/bssm-oss/main/justn-hyeok/otherrepo"
output="$($CLI wt --repo "$OTHER_REPO" other-feature)"
assert_contains "$output" "create-worktree	other-feature	$OTHER_WORKTREE_ROOT_RESOLVED/other-feature	worktree/other-feature"
[ -d "$OTHER_WORKTREE_ROOT_RESOLVED/other-feature" ] || fail "other repo worktree should create explicit worktree"

output="$(C4J_CMUX_BIN="$TMPDIR/no-cmux" $CLI wt list)"
assert_contains "$output" "otherrepo"
assert_contains "$output" "other-feature"
assert_contains "$output" "cmux4justn"

output="$($CLI wt move api api-v2)"
assert_contains "$output" "move-worktree	api	$WORKTREE_ROOT_RESOLVED/api	$WORKTREE_ROOT_RESOLVED/api-v2	worktree/api"
[ ! -d "$WORKTREE_ROOT_RESOLVED/api" ] || fail "move should remove the original worktree path"
[ -d "$WORKTREE_ROOT_RESOLVED/api-v2" ] || fail "move should create the destination worktree path"
assert_contains "$(git -C "$WORKTREE_ROOT_RESOLVED/api-v2" branch --show-current)" "worktree/api"

if output="$($CLI wt move --target api-v2 ignored-source ignored-destination 2>&1)"; then
  fail "move should reject positional source when --target is already set"
fi
assert_contains "$output" "worktree move accepts at most one source and one destination"

rm -rf "$WORKTREE_ROOT_RESOLVED/prune-me"
output="$($CLI wt prune)"
assert_contains "$output" "prune-worktree-repo	cmux4justn	$WORKTREE_REPO_RESOLVED"
[ ! -e "$WORKTREE_ROOT_RESOLVED/prune-me" ] || fail "prune should not recreate stale worktree paths"
output="$($CLI wt list)"
assert_not_contains "$output" "prune-me"

printf 'dirty\n' > "$WORKTREE_ROOT_RESOLVED/api-v2/dirty.txt"
if output="$($CLI wt delete api-v2 2>&1)"; then
  fail "delete should reject dirty worktrees without --force or --discard"
fi
assert_contains "$output" "worktree has uncommitted or untracked changes"
[ -d "$WORKTREE_ROOT_RESOLVED/api-v2" ] || fail "failed delete should leave dirty worktree in place"

output="$($CLI wt delete --discard api-v2)"
assert_contains "$output" "delete-worktree	api-v2	$WORKTREE_ROOT_RESOLVED/api-v2	worktree/api"
[ ! -d "$WORKTREE_ROOT_RESOLVED/api-v2" ] || fail "delete should remove the moved worktree"

before_update_head="$(git -C "$WORKTREE_ROOT_RESOLVED/cmux4justn-main" rev-parse HEAD)"
printf 'world\n' >> "$WORKTREE_REPO/README.md"
git -C "$WORKTREE_REPO" add README.md
git -C "$WORKTREE_REPO" commit -m "update main" >/dev/null
git -C "$WORKTREE_REPO" push origin main >/dev/null
output="$($CLI wt update cmux4justn-main)"
assert_contains "$output" "update-worktree	cmux4justn-main	$WORKTREE_ROOT_RESOLVED/cmux4justn-main	worktree/cmux4justn-main"
after_update_head="$(git -C "$WORKTREE_ROOT_RESOLVED/cmux4justn-main" rev-parse HEAD)"
expected_update_head="$(git -C "$WORKTREE_REPO" rev-parse HEAD)"
[ "$before_update_head" != "$after_update_head" ] || fail "update should advance the worktree"
[ "$after_update_head" = "$expected_update_head" ] || fail "update should match the latest main commit"

cd "$WORKTREE_OLDPWD"

INSTALL_RC="$TMPDIR/zshrc"
output="$(env HOME="$TMPDIR/home" bash "$ROOT/scripts/install.sh" --dry-run --no-bin --no-active-dir --no-config --rc --shell-rc "$INSTALL_RC")"
assert_contains "$output" "would-update-rc	$INSTALL_RC"
assert_contains "$output" "c4j()"
assert_contains "$output" "builtin cd --"
assert_contains "$output" "move-worktree"

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
assert_contains "$install_output" "updated-rc	$INSTALL_RC"
assert_contains "$install_output" "installed-completion	$INSTALL_RC"
assert_contains "$(cat "$INSTALL_RC")" "c4j()"
assert_contains "$(cat "$INSTALL_RC")" "cd-project"
assert_contains "$(cat "$INSTALL_RC")" "builtin cd --"
assert_contains "$(cat "$INSTALL_RC")" "source $ROOT/completions/c4j.bash"

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
assert_contains "$(cat "$WRAPPER_DRY_RUN_OUT")" "would-cd-project	beta	$PROJECTS_RESOLVED/beta"

BROKEN_RC="$TMPDIR/broken-zshrc"
printf '%s\n' "keep-before" "# >>> c4j >>>" "keep-after" > "$BROKEN_RC"
if install_output="$(run_install --shell-rc "$BROKEN_RC" --no-bin 2>&1)"; then
  fail "install should reject shell rc with an unmatched c4j marker"
fi
assert_contains "$install_output" "without matching"
assert_contains "$(cat "$BROKEN_RC")" "keep-after"

SPACE_RC="$TMPDIR/space-zshrc"
SPACE_BIN_DIR="$TMPDIR/bin with spaces"
mkdir -p "$SPACE_BIN_DIR"
install_output="$(run_install --shell-rc "$SPACE_RC" --bin-dir "$SPACE_BIN_DIR")"
assert_contains "$install_output" "installed-bin	$SPACE_BIN_DIR/c4j"
SPACE_WRAPPER_OUT="$TMPDIR/space-wrapper-out"
SPACE_WRAPPER_SCRIPT="$TMPDIR/space-wrapper-check.sh"
cat > "$SPACE_WRAPPER_SCRIPT" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$SPACE_RC"
cd "$TMPDIR"
c4j cd alpha > "$SPACE_WRAPPER_OUT"
pwd -P > "$WRAPPER_PWD"
EOF
HOME="$INSTALL_HOME" C4J_ACTIVE_DIR="$ACTIVE" C4J_CMUX_BIN="$FAKE_CMUX" bash "$SPACE_WRAPPER_SCRIPT"
[ "$(cat "$WRAPPER_PWD")" = "$PROJECTS_RESOLVED/alpha" ] || fail "wrapper should support bin dirs with spaces"
assert_contains "$(cat "$SPACE_RC")" "bin\\ with\\ spaces/c4j"

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

if launch_output="$(bash "$ROOT/scripts/launchd.sh" install --apply --launch-agents-dir "$LAUNCH_AGENTS_DIR" --label "../bad" 2>&1)"; then
  fail "launchd should reject unsafe labels"
fi
assert_contains "$launch_output" "invalid label"
[ ! -e "$LAUNCH_AGENTS_DIR/../bad.plist" ] || fail "launchd unsafe label should not write outside LaunchAgents"

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

BOOTSTRAP_HOME="$TMPDIR/bootstrap-home"
BOOTSTRAP_INSTALL_DIR="$TMPDIR/bootstrap-source"
BOOTSTRAP_ACTIVE="$TMPDIR/bootstrap-active"
BOOTSTRAP_REPO="$TMPDIR/bootstrap-repo"
mkdir -p "$BOOTSTRAP_HOME" "$BOOTSTRAP_ACTIVE"
git clone "$ROOT" "$BOOTSTRAP_REPO" >/dev/null
git -C "$BOOTSTRAP_REPO" checkout -B main >/dev/null
cp "$ROOT/install.sh" "$TMPDIR/bootstrap-install.sh"
chmod +x "$TMPDIR/bootstrap-install.sh"
if output="$(HOME="$BOOTSTRAP_HOME" C4J_REPO_URL="file://$BOOTSTRAP_REPO" C4J_REF="main" C4J_INSTALL_DIR="$BOOTSTRAP_INSTALL_DIR" C4J_ACTIVE_DIR="$BOOTSTRAP_ACTIVE" bash "$TMPDIR/bootstrap-install.sh" --dry-run --no-rc 2>&1)"; then
  fail "bootstrap custom source should require --allow-unsafe-source"
fi
assert_contains "$output" "unsafe source requires --allow-unsafe-source"

output="$(HOME="$BOOTSTRAP_HOME" C4J_REPO_URL="file://$BOOTSTRAP_REPO" C4J_REF="main" C4J_INSTALL_DIR="$BOOTSTRAP_INSTALL_DIR" C4J_ACTIVE_DIR="$BOOTSTRAP_ACTIVE" bash "$TMPDIR/bootstrap-install.sh" --allow-unsafe-source --dry-run --no-rc)"
assert_contains "$output" "would-download-source	file://$BOOTSTRAP_REPO	$BOOTSTRAP_INSTALL_DIR"
assert_contains "$output" "would-run-installer	$BOOTSTRAP_INSTALL_DIR/scripts/install.sh	--dry-run --no-rc"
[ ! -e "$BOOTSTRAP_INSTALL_DIR" ] || fail "bootstrap dry-run should not create install checkout"

output="$(HOME="$BOOTSTRAP_HOME" C4J_REPO_URL="file://$BOOTSTRAP_REPO" C4J_REF="main" C4J_INSTALL_DIR="$BOOTSTRAP_INSTALL_DIR" C4J_ACTIVE_DIR="$BOOTSTRAP_ACTIVE" bash "$TMPDIR/bootstrap-install.sh" --allow-unsafe-source --no-rc)"
assert_contains "$output" "download-source	file://$BOOTSTRAP_REPO	$BOOTSTRAP_INSTALL_DIR"
assert_contains "$output" "installed-bin	$BOOTSTRAP_HOME/.local/bin/c4j"
assert_contains "$output" "active-dir"
[ -x "$BOOTSTRAP_HOME/.local/bin/c4j" ] || fail "bootstrap install should create c4j executable"

printf 'local\n' > "$BOOTSTRAP_INSTALL_DIR/local.txt"
if output="$(HOME="$BOOTSTRAP_HOME" C4J_REPO_URL="file://$BOOTSTRAP_REPO" C4J_REF="main" C4J_INSTALL_DIR="$BOOTSTRAP_INSTALL_DIR" C4J_ACTIVE_DIR="$BOOTSTRAP_ACTIVE" bash "$TMPDIR/bootstrap-install.sh" --allow-unsafe-source --no-rc 2>&1)"; then
  fail "bootstrap update should reject dirty install checkout"
fi
assert_contains "$output" "install checkout has local changes"
rm -f "$BOOTSTRAP_INSTALL_DIR/local.txt"

STDIN_BOOTSTRAP_HOME="$TMPDIR/stdin-bootstrap-home"
STDIN_BOOTSTRAP_INSTALL_DIR="$TMPDIR/stdin-bootstrap-source"
STDIN_BOOTSTRAP_ACTIVE="$TMPDIR/stdin-bootstrap-active"
STDIN_BOOTSTRAP_ERR="$TMPDIR/stdin-bootstrap.err"
mkdir -p "$STDIN_BOOTSTRAP_HOME" "$STDIN_BOOTSTRAP_ACTIVE"
output="$(HOME="$STDIN_BOOTSTRAP_HOME" C4J_REPO_URL="file://$BOOTSTRAP_REPO" C4J_REF="main" C4J_INSTALL_DIR="$STDIN_BOOTSTRAP_INSTALL_DIR" C4J_ACTIVE_DIR="$STDIN_BOOTSTRAP_ACTIVE" bash -s -- --allow-unsafe-source --no-rc < "$ROOT/install.sh" 2>"$STDIN_BOOTSTRAP_ERR")"
! grep -q "BASH_SOURCE" "$STDIN_BOOTSTRAP_ERR" || fail "stdin bootstrap should not warn about BASH_SOURCE"
assert_contains "$output" "download-source	file://$BOOTSTRAP_REPO	$STDIN_BOOTSTRAP_INSTALL_DIR"
assert_contains "$output" "installed-bin	$STDIN_BOOTSTRAP_HOME/.local/bin/c4j"
[ -x "$STDIN_BOOTSTRAP_HOME/.local/bin/c4j" ] || fail "stdin bootstrap install should create c4j executable"

UPDATE_SOURCE="$TMPDIR/update-source"
UPDATE_REMOTE="$TMPDIR/update-remote.git"
UPDATE_ALT_SOURCE="$TMPDIR/update-alt-source"
UPDATE_ALT_REMOTE="$TMPDIR/update-alt-remote.git"
UPDATE_INSTALL_DIR="$TMPDIR/update-install"
UPDATE_BIN_DIR="$TMPDIR/update-bin"
mkdir -p "$UPDATE_BIN_DIR"
printf '#!/usr/bin/env bash\nprintf old-version\\\\n\n' > "$UPDATE_BIN_DIR/c4j"
chmod +x "$UPDATE_BIN_DIR/c4j"
git clone "$ROOT" "$UPDATE_SOURCE" >/dev/null
git -C "$UPDATE_SOURCE" config user.name "Test User"
git -C "$UPDATE_SOURCE" config user.email "test@example.com"
sed_inplace 's/^VERSION="[0-9][0-9.]*"/VERSION="9.9.9"/' "$UPDATE_SOURCE/bin/cmux4justn"
sed_inplace 's/^[0-9][0-9.]*$/9.9.9/' "$UPDATE_SOURCE/VERSION"
git -C "$UPDATE_SOURCE" add VERSION bin/cmux4justn
git -C "$UPDATE_SOURCE" commit -m "bump test version" >/dev/null
git -C "$UPDATE_SOURCE" tag v9.9.9
UPDATE_TARGET_COMMIT="$(git -C "$UPDATE_SOURCE" rev-parse HEAD)"
git clone --bare "$UPDATE_SOURCE" "$UPDATE_REMOTE" >/dev/null
if output="$(C4J_REPO_URL="file://$UPDATE_REMOTE" C4J_BIN_DIR="$UPDATE_BIN_DIR" "$CLI" update --dry-run --ref v9.9.9 --install-dir "$UPDATE_INSTALL_DIR" 2>&1)"; then
  fail "update custom repo should require --allow-unsafe-source"
fi
assert_contains "$output" "unsafe source requires --allow-unsafe-source"
if output="$(C4J_BIN_DIR="$UPDATE_BIN_DIR" "$CLI" update --dry-run --ref main --install-dir "$UPDATE_INSTALL_DIR" 2>&1)"; then
  fail "update arbitrary ref should require --allow-unsafe-source"
fi
assert_contains "$output" "unsafe source requires --allow-unsafe-source"

output="$(C4J_REPO_URL="file://$UPDATE_REMOTE" C4J_BIN_DIR="$UPDATE_BIN_DIR" "$CLI" update --allow-unsafe-source --dry-run --ref v9.9.9 --install-dir "$UPDATE_INSTALL_DIR")"
assert_contains "$output" "current-version	$CURRENT_VERSION"
assert_contains "$output" "target-ref	v9.9.9"
assert_contains "$output" "target-commit	$UPDATE_TARGET_COMMIT"
assert_contains "$output" "already-current	false"
assert_contains "$output" "would-update-source	$UPDATE_INSTALL_DIR	v9.9.9"
assert_contains "$output" "would-install-bin	$UPDATE_BIN_DIR/c4j"
[ ! -e "$UPDATE_INSTALL_DIR" ] || fail "update dry-run should not create install checkout"
output="$(C4J_REPO_URL="file://$UPDATE_REMOTE" C4J_BIN_DIR="$UPDATE_BIN_DIR" "$CLI" update --allow-unsafe-source --ref v9.9.9 --install-dir "$UPDATE_INSTALL_DIR")"
assert_contains "$output" "update-cli	v9.9.9	$UPDATE_INSTALL_DIR"
[ "$("$UPDATE_BIN_DIR/c4j" version)" = "9.9.9" ] || fail "update should install the tagged version"
output="$(C4J_REPO_URL="file://$UPDATE_REMOTE" C4J_BIN_DIR="$UPDATE_BIN_DIR" "$CLI" update --allow-unsafe-source --dry-run --ref v9.9.9 --install-dir "$UPDATE_INSTALL_DIR")"
assert_contains "$output" "already-current	true"
printf 'local\n' > "$UPDATE_INSTALL_DIR/local.txt"
if output="$(C4J_REPO_URL="file://$UPDATE_REMOTE" C4J_BIN_DIR="$UPDATE_BIN_DIR" "$CLI" update --allow-unsafe-source --ref v9.9.9 --install-dir "$UPDATE_INSTALL_DIR" 2>&1)"; then
  fail "update should reject dirty install checkout"
fi
assert_contains "$output" "install checkout has local changes"
rm -f "$UPDATE_INSTALL_DIR/local.txt"

git clone "$ROOT" "$UPDATE_ALT_SOURCE" >/dev/null
git -C "$UPDATE_ALT_SOURCE" config user.name "Test User"
git -C "$UPDATE_ALT_SOURCE" config user.email "test@example.com"
sed_inplace 's/^VERSION="[0-9][0-9.]*"/VERSION="8.8.8"/' "$UPDATE_ALT_SOURCE/bin/cmux4justn"
sed_inplace 's/^[0-9][0-9.]*$/8.8.8/' "$UPDATE_ALT_SOURCE/VERSION"
git -C "$UPDATE_ALT_SOURCE" add VERSION bin/cmux4justn
git -C "$UPDATE_ALT_SOURCE" commit -m "alt test version" >/dev/null
git -C "$UPDATE_ALT_SOURCE" tag v8.8.8
git clone --bare "$UPDATE_ALT_SOURCE" "$UPDATE_ALT_REMOTE" >/dev/null
output="$(C4J_REPO_URL="file://$UPDATE_ALT_REMOTE" C4J_BIN_DIR="$UPDATE_BIN_DIR" "$CLI" update --allow-unsafe-source --ref v8.8.8 --install-dir "$UPDATE_INSTALL_DIR")"
assert_contains "$output" "update-cli	v8.8.8	$UPDATE_INSTALL_DIR"
[ "$("$UPDATE_BIN_DIR/c4j" version)" = "8.8.8" ] || fail "update should fetch refs from an overridden repo-url even when install dir exists"

CURRENT_MAJOR_MINOR="${CURRENT_VERSION%.*}"
CURRENT_PATCH="${CURRENT_VERSION##*.}"
NEXT_PATCH_VERSION="$CURRENT_MAJOR_MINOR.$((CURRENT_PATCH + 1))"
output="$(bash "$ROOT/scripts/release.sh" --dry-run "$NEXT_PATCH_VERSION")"
assert_contains "$output" "release-dry-run	$CURRENT_VERSION	$NEXT_PATCH_VERSION"
assert_contains "$output" "would-run-local-checks"
assert_contains "$output" "would-create-release	v$NEXT_PATCH_VERSION"

[ "$($CLI version)" = "$CURRENT_VERSION" ] || fail "version mismatch"
[ "$("$ROOT/bin/cmux4justn" version)" = "$CURRENT_VERSION" ] || fail "legacy version mismatch"

printf 'PASS cmux4justn tests\n'
