#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=test/lib/common.bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/lib/common.bash"

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
[ -x "$BOOTSTRAP_HOME/.local/bin/c4j" ] || fail "bootstrap install should create c4j executable"

printf 'local\n' > "$BOOTSTRAP_INSTALL_DIR/local.txt"
if output="$(HOME="$BOOTSTRAP_HOME" C4J_REPO_URL="file://$BOOTSTRAP_REPO" C4J_REF="main" C4J_INSTALL_DIR="$BOOTSTRAP_INSTALL_DIR" C4J_ACTIVE_DIR="$BOOTSTRAP_ACTIVE" bash "$TMPDIR/bootstrap-install.sh" --allow-unsafe-source --no-rc 2>&1)"; then
  fail "bootstrap update should reject dirty install checkout"
fi
assert_contains "$output" "install checkout has local changes"

UPDATE_SOURCE="$TMPDIR/update-source"
UPDATE_REMOTE="$TMPDIR/update-remote.git"
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

output="$(C4J_REPO_URL="file://$UPDATE_REMOTE" C4J_BIN_DIR="$UPDATE_BIN_DIR" "$CLI" update --allow-unsafe-source --dry-run --ref v9.9.9 --install-dir "$UPDATE_INSTALL_DIR")"
assert_contains "$output" "current-version	$CURRENT_VERSION"
assert_contains "$output" "target-ref	v9.9.9"
assert_contains "$output" "target-commit	$UPDATE_TARGET_COMMIT"
assert_contains "$output" "already-current	false"
assert_contains "$output" "would-update-source	$UPDATE_INSTALL_DIR	v9.9.9"
assert_contains "$output" "would-install-bin	$UPDATE_BIN_DIR/c4j"
[ ! -e "$UPDATE_INSTALL_DIR" ] || fail "update dry-run should not create install checkout"

printf 'PASS bootstrap/update workflow\n'
