#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CLI="$ROOT/bin/c4j"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
export HOME="$TMPDIR/home"
unset C4J_CONFIG CMUX4JUSTN_CONFIG
CURRENT_VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if ! printf '%s\n' "$haystack" | grep -F -- "$needle" >/dev/null; then
    fail "expected output to contain: $needle
--- actual output ---
$haystack
--- end ---"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if printf '%s\n' "$haystack" | grep -F -- "$needle" >/dev/null; then
    fail "expected output not to contain: $needle"
  fi
}

sed_inplace() {
  local pattern="$1"
  local file="$2"
  sed -i.bak "$pattern" "$file"
  rm -f "$file.bak"
}

output="$($CLI)"
assert_contains "$output" "c4j v$CURRENT_VERSION"
assert_contains "$output" "I want to:"
assert_contains "$output" "go <project>"
assert_contains "$output" "wt [name]"
assert_contains "$output" "sync --apply"
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

output="$($CLI help wt list)"
assert_contains "$output" "c4j wt list"

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

output="$($CLI wt delete api-v2)"
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

rm -f "$CALLS"
output="$($CLI go --dry-run alpha)"
assert_contains "$output" "would-select-workspace	@active/alpha	workspace:1"
assert_contains "$output" "would-go-project	alpha	$PROJECTS_RESOLVED/alpha"
[ ! -e "$CALLS" ] || fail "go dry-run should not call cmux"

output="$($CLI go alpha)"
assert_contains "$output" "select-workspace	@active/alpha	workspace:1"
assert_contains "$output" "go-project	alpha	$PROJECTS_RESOLVED/alpha"
assert_contains "$(cat "$CALLS")" "select-workspace --workspace workspace:1"

rm -f "$CALLS"
output="$($CLI go beta)"
assert_contains "$output" "create-workspace	@active/beta	$PROJECTS_RESOLVED/beta"
assert_contains "$output" "go-project	beta	$PROJECTS_RESOLVED/beta"
assert_contains "$(cat "$CALLS")" "new-workspace --name @active/beta --cwd $PROJECTS_RESOLVED/beta --focus true"

rm -f "$CALLS"
output="$($CLI go --no-cmux "$PROJECTS/legacy")"
assert_contains "$output" "link	$ACTIVE/legacy	$PROJECTS_RESOLVED/legacy"
assert_contains "$output" "skip cmux-disabled	@active/legacy"
assert_contains "$output" "go-project	legacy	$PROJECTS_RESOLVED/legacy"
[ -L "$ACTIVE/legacy" ] || fail "go path should add a missing active link"
[ ! -e "$CALLS" ] || fail "go --no-cmux should not call cmux"

rm -f "$CALLS"
output="$($CLI cd alpha)"
assert_contains "$output" "cd-project	alpha	$PROJECTS_RESOLVED/alpha"
[ ! -e "$CALLS" ] || fail "cd should not call cmux"

output="$($CLI cd --dry-run beta)"
assert_contains "$output" "would-cd-project	beta	$PROJECTS_RESOLVED/beta"

if output="$($CLI cd missing-project 2>&1)"; then
  fail "cd should fail for a missing active project"
fi
assert_contains "$output" "active project not found: missing-project"

CONFLICT_PROJECT="$PROJECTS/conflict"
rm -f "$ACTIVE/conflict"
mkdir -p "$CONFLICT_PROJECT"
if output="$($CLI go "$CONFLICT_PROJECT" 2>&1)"; then
  fail "go should fail when the matching workspace points elsewhere"
fi
assert_contains "$output" "workspace already points elsewhere: @active/conflict"
[ ! -e "$ACTIVE/conflict" ] || fail "go failure should not leave a new active link"

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
COMP_WORDS=(c4j cd beta-)
COMP_CWORD=2
_c4j_complete
assert_contains "${COMPREPLY[*]}" "beta-copy"
COMP_WORDS=(c4j h)
COMP_CWORD=1
_c4j_complete
assert_contains "${COMPREPLY[*]}" "help"
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

BOOTSTRAP_HOME="$TMPDIR/bootstrap-home"
BOOTSTRAP_INSTALL_DIR="$TMPDIR/bootstrap-source"
BOOTSTRAP_ACTIVE="$TMPDIR/bootstrap-active"
BOOTSTRAP_REPO="$TMPDIR/bootstrap-repo"
mkdir -p "$BOOTSTRAP_HOME" "$BOOTSTRAP_ACTIVE"
git clone "$ROOT" "$BOOTSTRAP_REPO" >/dev/null
git -C "$BOOTSTRAP_REPO" checkout -B main >/dev/null
cp "$ROOT/install.sh" "$TMPDIR/bootstrap-install.sh"
chmod +x "$TMPDIR/bootstrap-install.sh"
output="$(HOME="$BOOTSTRAP_HOME" C4J_REPO_URL="file://$BOOTSTRAP_REPO" C4J_REF="main" C4J_INSTALL_DIR="$BOOTSTRAP_INSTALL_DIR" C4J_ACTIVE_DIR="$BOOTSTRAP_ACTIVE" bash "$TMPDIR/bootstrap-install.sh" --no-rc)"
assert_contains "$output" "download-source	file://$BOOTSTRAP_REPO	$BOOTSTRAP_INSTALL_DIR"
assert_contains "$output" "installed-bin	$BOOTSTRAP_HOME/.local/bin/c4j"
assert_contains "$output" "active-dir"
[ -x "$BOOTSTRAP_HOME/.local/bin/c4j" ] || fail "bootstrap install should create c4j executable"

STDIN_BOOTSTRAP_HOME="$TMPDIR/stdin-bootstrap-home"
STDIN_BOOTSTRAP_INSTALL_DIR="$TMPDIR/stdin-bootstrap-source"
STDIN_BOOTSTRAP_ACTIVE="$TMPDIR/stdin-bootstrap-active"
STDIN_BOOTSTRAP_ERR="$TMPDIR/stdin-bootstrap.err"
mkdir -p "$STDIN_BOOTSTRAP_HOME" "$STDIN_BOOTSTRAP_ACTIVE"
output="$(HOME="$STDIN_BOOTSTRAP_HOME" C4J_REPO_URL="file://$BOOTSTRAP_REPO" C4J_REF="main" C4J_INSTALL_DIR="$STDIN_BOOTSTRAP_INSTALL_DIR" C4J_ACTIVE_DIR="$STDIN_BOOTSTRAP_ACTIVE" bash -s -- --no-rc < "$ROOT/install.sh" 2>"$STDIN_BOOTSTRAP_ERR")"
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
git clone --bare "$UPDATE_SOURCE" "$UPDATE_REMOTE" >/dev/null
output="$(C4J_REPO_URL="file://$UPDATE_REMOTE" C4J_BIN_DIR="$UPDATE_BIN_DIR" "$CLI" update --dry-run --ref v9.9.9 --install-dir "$UPDATE_INSTALL_DIR")"
assert_contains "$output" "would-update-source	$UPDATE_INSTALL_DIR	v9.9.9"
assert_contains "$output" "would-install-bin	$UPDATE_BIN_DIR/c4j"
output="$(C4J_REPO_URL="file://$UPDATE_REMOTE" C4J_BIN_DIR="$UPDATE_BIN_DIR" "$CLI" update --ref v9.9.9 --install-dir "$UPDATE_INSTALL_DIR")"
assert_contains "$output" "update-cli	v9.9.9	$UPDATE_INSTALL_DIR"
[ "$("$UPDATE_BIN_DIR/c4j" version)" = "9.9.9" ] || fail "update should install the tagged version"

git clone "$ROOT" "$UPDATE_ALT_SOURCE" >/dev/null
git -C "$UPDATE_ALT_SOURCE" config user.name "Test User"
git -C "$UPDATE_ALT_SOURCE" config user.email "test@example.com"
sed_inplace 's/^VERSION="[0-9][0-9.]*"/VERSION="8.8.8"/' "$UPDATE_ALT_SOURCE/bin/cmux4justn"
sed_inplace 's/^[0-9][0-9.]*$/8.8.8/' "$UPDATE_ALT_SOURCE/VERSION"
git -C "$UPDATE_ALT_SOURCE" add VERSION bin/cmux4justn
git -C "$UPDATE_ALT_SOURCE" commit -m "alt test version" >/dev/null
git -C "$UPDATE_ALT_SOURCE" tag v8.8.8
git clone --bare "$UPDATE_ALT_SOURCE" "$UPDATE_ALT_REMOTE" >/dev/null
output="$(C4J_REPO_URL="file://$UPDATE_ALT_REMOTE" C4J_BIN_DIR="$UPDATE_BIN_DIR" "$CLI" update --ref v8.8.8 --install-dir "$UPDATE_INSTALL_DIR")"
assert_contains "$output" "update-cli	v8.8.8	$UPDATE_INSTALL_DIR"
[ "$("$UPDATE_BIN_DIR/c4j" version)" = "8.8.8" ] || fail "update should fetch refs from an overridden repo-url even when install dir exists"

[ "$($CLI version)" = "$CURRENT_VERSION" ] || fail "version mismatch"
[ "$("$ROOT/bin/cmux4justn" version)" = "$CURRENT_VERSION" ] || fail "legacy version mismatch"

printf 'PASS cmux4justn tests\n'
