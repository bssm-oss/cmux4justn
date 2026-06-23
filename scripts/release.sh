#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DRY_RUN=0
PREPARE_ONLY=0
NOTES_FILE=""

usage() {
  cat <<'USAGE'
Usage: scripts/release.sh [--dry-run] [--prepare-only] [--notes-file PATH] <0.13.x>

Runs the canonical c4j patch release flow:
  1. update version references
  2. run local checks
  3. commit and push main
  4. wait for main CI
  5. tag, push tag, and wait for tag CI
  6. create the GitHub Release

Options:
  --dry-run       Print planned actions without changing files or remotes.
  --prepare-only Update version references and stop before checks/commit/push.
  --notes-file   Use this file as GitHub Release notes.
USAGE
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

json_field() {
  local field="$1"
  python3 -c "import json,sys; data=json.load(sys.stdin); print(data.get('$field',''))"
}

current_date() {
  date +%F
}

next_patch_version() {
  local version="$1"
  local prefix patch
  prefix="${version%.*}"
  patch="${version##*.}"
  [[ "$patch" =~ ^[0-9]+$ ]] || fail "invalid current version: $version"
  printf '%s.%s\n' "$prefix" "$((patch + 1))"
}

ensure_clean_tree() {
  local status
  status="$(git -C "$ROOT" status --porcelain)"
  [ -z "$status" ] || fail "working tree is not clean"
}

replace_version_refs() {
  local old_version="$1"
  local new_version="$2"
  local old_tag="v$old_version"
  local new_tag="v$new_version"

  printf '%s\n' "$new_version" > "$ROOT/VERSION"
  perl -0pi -e "s/VERSION=\"\\Q$old_version\\E\"/VERSION=\"$new_version\"/" "$ROOT/bin/cmux4justn"
  perl -0pi -e "s/\\Q$old_tag\\E/$new_tag/g" \
    "$ROOT/install.sh" \
    "$ROOT/README.md" \
    "$ROOT/README.ko.md" \
    "$ROOT/bin/cmux4justn"
}

ensure_changelog_entry() {
  local version="$1"
  local tag="v$version"
  local today
  today="$(current_date)"

  if grep -F "## $tag " "$ROOT/CHANGELOG.md" >/dev/null 2>&1; then
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v tag="$tag" -v today="$today" '
    NR == 1 {
      print
      print ""
      print "## " tag " - " today
      print ""
      print "### Changed"
      print ""
      print "- Prepared " tag " release."
      next
    }
    { print }
  ' "$ROOT/CHANGELOG.md" > "$tmp"
  mv "$tmp" "$ROOT/CHANGELOG.md"
}

release_notes_from_changelog() {
  local version="$1"
  local tag="v$version"
  awk -v tag="$tag" '
    $0 ~ "^## " tag " " { in_section = 1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$ROOT/CHANGELOG.md" | sed '/./,$!d'
}

run_local_checks() {
  (
    cd "$ROOT"
    bash -n bin/c4j bin/cmux4justn install.sh scripts/install.sh scripts/launchd.sh scripts/release.sh test/cmux4justn.test.sh completions/c4j.bash
    shellcheck -x bin/c4j bin/cmux4justn install.sh scripts/install.sh scripts/launchd.sh scripts/release.sh test/cmux4justn.test.sh completions/c4j.bash
    bash test/cmux4justn.test.sh
    git diff --check
    run_zsh_smoke
  )
}

run_zsh_smoke() {
  local tmpdir install_rc install_bin install_home active project stderr out expected
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN
  install_rc="$tmpdir/zshrc"
  install_bin="$tmpdir/bin"
  install_home="$tmpdir/home"
  active="$tmpdir/active"
  project="$tmpdir/project"
  stderr="$tmpdir/zsh.err"
  mkdir -p "$install_home" "$active" "$project"
  HOME="$install_home" C4J_BIN_DIR="$install_bin" C4J_ACTIVE_DIR="$active" C4J_SHELL_RC="$install_rc" bash "$ROOT/scripts/install.sh" --rc >/dev/null
  out="$(zsh -f -c "source '$install_rc'; cd '$tmpdir'; C4J_ACTIVE_DIR='$active' C4J_CMUX_BIN='$tmpdir/no-cmux' c4j go --no-cmux '$project' >/dev/null; pwd -P" 2>"$stderr")"
  if [ -s "$stderr" ]; then
    cat "$stderr" >&2
    return 1
  fi
  expected="$(cd "$project" && pwd -P)"
  [ "$out" = "$expected" ] || fail "fresh zsh smoke ended in $out, expected $expected"
}

check_release_prereqs() {
  need_command git
  need_command gh
  need_command python3
  need_command perl
  need_command shellcheck
  need_command zsh

  gh auth status >/dev/null 2>&1 || fail "gh is not authenticated"
  gh run list --limit 1 >/dev/null 2>&1 || fail "cannot read GitHub Actions runs with gh"
}

wait_for_ci() {
  local branch="$1"
  local sha="$2"
  local run_json run_id status conclusion
  local attempts=40

  while [ "$attempts" -gt 0 ]; do
    run_json="$(gh run list --event push --branch "$branch" --json databaseId,status,conclusion,headSha,url --limit 10)"
    run_json="$(printf '%s\n' "$run_json" | python3 -c "import json,sys; runs=json.load(sys.stdin); sha='$sha'; matches=[r for r in runs if r.get('headSha') == sha]; print(json.dumps(matches[0] if matches else {}))")"
    if [ "$run_json" != "{}" ]; then
      run_id="$(printf '%s\n' "$run_json" | json_field databaseId)"
      status="$(printf '%s\n' "$run_json" | json_field status)"
      conclusion="$(printf '%s\n' "$run_json" | json_field conclusion)"
      if [ "$status" = "completed" ]; then
        [ "$conclusion" = "success" ] || fail "CI failed for $branch at $sha: $conclusion"
        printf 'ci-ok\t%s\t%s\n' "$branch" "$run_id"
        return 0
      fi
      gh run watch "$run_id" --exit-status
      printf 'ci-ok\t%s\t%s\n' "$branch" "$run_id"
      return 0
    fi
    sleep 3
    attempts=$((attempts - 1))
  done

  fail "CI run was not visible for $branch at $sha"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --prepare-only)
      PREPARE_ONLY=1
      shift
      ;;
    --notes-file)
      [ "$#" -ge 2 ] || fail "--notes-file requires a path"
      NOTES_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      fail "unknown option: $1"
      ;;
    *)
      [ "${VERSION_ARG:-}" = "" ] || fail "release version specified more than once"
      VERSION_ARG="$1"
      shift
      ;;
  esac
done

[ "${VERSION_ARG:-}" != "" ] || fail "release version required"
[[ "$VERSION_ARG" =~ ^0\.13\.[0-9]+$ ]] || fail "release version must look like 0.13.x"

cd "$ROOT"

current_version="$(tr -d '[:space:]' < "$ROOT/VERSION")"
expected_version="$(next_patch_version "$current_version")"
[ "$VERSION_ARG" = "$expected_version" ] || fail "expected next patch version $expected_version, got $VERSION_ARG"

tag="v$VERSION_ARG"

if [ "$DRY_RUN" -eq 1 ]; then
  printf 'release-dry-run\t%s\t%s\n' "$current_version" "$VERSION_ARG"
  printf 'would-update-version-refs\t%s\t%s\n' "$current_version" "$VERSION_ARG"
  printf 'would-run-local-checks\n'
  printf 'would-commit\tRelease %s\n' "$tag"
  printf 'would-push-main\n'
  printf 'would-push-tag\t%s\n' "$tag"
  printf 'would-create-release\t%s\n' "$tag"
  exit 0
fi

check_release_prereqs
ensure_clean_tree

git rev-parse --verify "$tag" >/dev/null 2>&1 && fail "tag already exists locally: $tag"
gh release view "$tag" >/dev/null 2>&1 && fail "GitHub Release already exists: $tag"

replace_version_refs "$current_version" "$VERSION_ARG"
ensure_changelog_entry "$VERSION_ARG"

if [ "$PREPARE_ONLY" -eq 1 ]; then
  printf 'prepared-release\t%s\n' "$tag"
  exit 0
fi

run_local_checks

if git -C "$ROOT" diff --quiet; then
  fail "no release changes to commit"
fi

git add CHANGELOG.md README.md README.ko.md VERSION bin/cmux4justn install.sh scripts/release.sh completions/c4j.bash test/cmux4justn.test.sh
git commit -m "Release $tag"
commit_sha="$(git rev-parse HEAD)"

git push origin main
wait_for_ci main "$commit_sha"

git tag "$tag"
git push origin "$tag"
wait_for_ci "$tag" "$commit_sha"

notes_tmp="$(mktemp)"
trap 'rm -f "$notes_tmp"' EXIT
if [ -n "$NOTES_FILE" ]; then
  [ -f "$NOTES_FILE" ] || fail "notes file not found: $NOTES_FILE"
  cp "$NOTES_FILE" "$notes_tmp"
else
  release_notes_from_changelog "$VERSION_ARG" > "$notes_tmp"
fi

gh release create "$tag" --title "$tag" --notes-file "$notes_tmp"
printf 'released\t%s\t%s\n' "$tag" "$commit_sha"
