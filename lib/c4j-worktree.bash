#!/usr/bin/env bash
# shellcheck disable=SC2153

canonical_git_root() {
  local path="$1"
  local git_dir

  git_dir="$(git -C "$path" rev-parse --absolute-git-dir 2>/dev/null)" || return 1
  case "$git_dir" in
    */.git/worktrees/*)
      dirname "$(dirname "$(dirname "$git_dir")")"
      ;;
    */.git)
      dirname "$git_dir"
      ;;
    *)
      return 1
      ;;
  esac
}

current_git_ref() {
  local path="$1"
  local branch short_sha

  branch="$(git -C "$path" branch --show-current 2>/dev/null || true)"
  if [ -n "$branch" ]; then
    printf '%s\n' "$branch"
    return 0
  fi

  short_sha="$(git -C "$path" rev-parse --short HEAD 2>/dev/null)" || return 1
  printf 'detached-%s\n' "$short_sha"
}

worktree_registered_at_path() {
  local repo_root="$1"
  local path="$2"

  git -C "$repo_root" worktree list --porcelain | awk -v target="$path" '$1 == "worktree" && $2 == target { found = 1 } END { exit found ? 0 : 1 }'
}

worktree_branch_in_use() {
  local repo_root="$1"
  local branch="$2"

  git -C "$repo_root" worktree list --porcelain | awk -v target="refs/heads/$branch" '$1 == "branch" && $2 == target { found = 1 } END { exit found ? 0 : 1 }'
}

git_branch_exists() {
  local repo_root="$1"
  local branch="$2"

  git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"
}

worktree_repo_root_for_path() {
  local path="$1"

  git -C "$path" rev-parse --show-toplevel 2>/dev/null || return 1
}

worktree_repo_root_from_cmux() {
  local cmux_bin="$1" workspace_dir repo_root

  workspace_dir="$(cmux_workspace_directory "$cmux_bin" 2>/dev/null || true)"
  [ -n "$workspace_dir" ] || return 1
  repo_root="$(worktree_repo_root_for_path "$workspace_dir" 2>/dev/null || true)"
  [ -n "$repo_root" ] || return 1
  printf '%s\n' "$repo_root"
}

discover_worktree_repo_roots() {
  local output_file="$1"
  local repos_root="${HOME:-/Users/justn}/Workspaces/repos"
  local worktree_root="${WORKTREE_DIR%/}"
  local gitdir worktree_dir repo_root

  : > "$output_file"

  if [ -d "$repos_root" ]; then
    while IFS= read -r gitdir; do
      [ -n "$gitdir" ] || continue
      dirname "$gitdir" >> "$output_file"
    done < <(find "$repos_root" -type d -name .git -print 2>/dev/null)
  fi

  if [ -d "$worktree_root" ]; then
    while IFS= read -r -d '' gitdir; do
      worktree_dir="$(dirname "$gitdir")"
      repo_root="$(canonical_git_root "$worktree_dir" 2>/dev/null || true)"
      [ -n "$repo_root" ] || continue
      printf '%s\n' "$repo_root" >> "$output_file"
    done < <(find "$worktree_root" -type f -name .git -print0 2>/dev/null)
  fi

  sort -u "$output_file" -o "$output_file"
}

collect_worktree_rows() {
  local rows_file="$1"
  local scope_repo_root="${2:-}"
  local roots_file

  : > "$rows_file"
  roots_file="$(mktemp)"

  if [ -n "$scope_repo_root" ]; then
    printf '%s\n' "$scope_repo_root" > "$roots_file"
  else
    discover_worktree_repo_roots "$roots_file"
  fi

  local repo_root
  while IFS= read -r repo_root; do
    [ -n "$repo_root" ] || continue
    [ -d "$repo_root" ] || continue
    append_worktree_rows_for_repo_root "$repo_root" "$rows_file"
  done < "$roots_file"

  sort -t "$(printf '\t')" -k1,1 -k2,2 -k3,3 "$rows_file" -o "$rows_file"
  rm -f "$roots_file"
}

append_worktree_rows_for_repo_root() {
  local repo_root="$1"
  local rows_file="$2"
  local repo_name current_path current_branch line name branch_display

  repo_name="$(basename "$repo_root")"
  current_path=""
  current_branch=""

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      worktree\ *)
        if [ -n "$current_path" ]; then
          name="$(basename "$current_path")"
          if [ "$current_path" = "$repo_root" ]; then
            name="$repo_name"
          fi
          branch_display="${current_branch:-detached}"
          printf '%s\t%s\t%s\t%s\t%s\n' "$repo_root" "$repo_name" "$name" "$current_path" "$branch_display" >> "$rows_file"
        fi
        current_path="${line#worktree }"
        current_branch=""
        ;;
      branch\ *)
        current_branch="${line#branch refs/heads/}"
        ;;
      detached)
        current_branch="detached"
        ;;
      "")
        if [ -n "$current_path" ]; then
          name="$(basename "$current_path")"
          if [ "$current_path" = "$repo_root" ]; then
            name="$repo_name"
          fi
          branch_display="${current_branch:-detached}"
          printf '%s\t%s\t%s\t%s\t%s\n' "$repo_root" "$repo_name" "$name" "$current_path" "$branch_display" >> "$rows_file"
          current_path=""
          current_branch=""
        fi
        ;;
    esac
  done < <(git -C "$repo_root" worktree list --porcelain 2>/dev/null || true)

  if [ -n "$current_path" ]; then
    name="$(basename "$current_path")"
    if [ "$current_path" = "$repo_root" ]; then
      name="$repo_name"
    fi
    branch_display="${current_branch:-detached}"
    printf '%s\t%s\t%s\t%s\t%s\n' "$repo_root" "$repo_name" "$name" "$current_path" "$branch_display" >> "$rows_file"
  fi
}

worktree_render_rows() {
  local rows_file="$1"
  local mode="${2:-table}"
  local repo_width name_width path_width branch_width

  if [ ! -s "$rows_file" ]; then
    printf 'No worktrees found.\n'
    return 0
  fi

  if [ "$mode" = "plain" ]; then
    cat "$rows_file"
    return 0
  fi

  repo_width="$(awk -F '\t' 'BEGIN { max = length("REPO") } { if (length($2) > max) max = length($2) } END { print max }' "$rows_file")"
  name_width="$(awk -F '\t' 'BEGIN { max = length("WORKTREE") } { if (length($3) > max) max = length($3) } END { print max }' "$rows_file")"
  path_width="$(awk -F '\t' 'BEGIN { max = length("PATH") } { if (length($4) > max) max = length($4) } END { print max }' "$rows_file")"
  branch_width="$(awk -F '\t' 'BEGIN { max = length("BRANCH") } { if (length($5) > max) max = length($5) } END { print max }' "$rows_file")"

  printf "%-${repo_width}s  %-${name_width}s  %-${path_width}s  %s\n" "REPO" "WORKTREE" "PATH" "BRANCH"
  printf "%-${repo_width}s  %-${name_width}s  %-${path_width}s  %s\n" "$(printf '%*s' "$repo_width" '' | tr ' ' '-')" "$(printf '%*s' "$name_width" '' | tr ' ' '-')" "$(printf '%*s' "$path_width" '' | tr ' ' '-')" "$(printf '%*s' "$branch_width" '' | tr ' ' '-')"
  awk -F '\t' -v repo_width="$repo_width" -v name_width="$name_width" -v path_width="$path_width" '{ printf "%-" repo_width "s  %-" name_width "s  %-" path_width "s  %s\n", $2, $3, $4, $5 }' "$rows_file"
}

worktree_find_rows() {
  local rows_file="$1"
  local target="$2"
  local matches_file="$3"
  : > "$matches_file"

  while IFS=$'\t' read -r repo_root repo_name worktree_name worktree_path branch; do
    [ -n "$repo_root" ] || continue
    case "$target" in
      "$worktree_path"|"$worktree_name"|"$branch"|worktree/"$target"|"$repo_root")
        printf '%s\t%s\t%s\t%s\t%s\n' "$repo_root" "$repo_name" "$worktree_name" "$worktree_path" "$branch" >> "$matches_file"
        ;;
    esac
  done < "$rows_file"
}

worktree_current_path_from_pwd() {
  local top repo_root

  top="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null)" || return 1
  repo_root="$(canonical_git_root "$top" 2>/dev/null || true)"
  [ -n "$repo_root" ] || return 1
  [ "$top" != "$repo_root" ] || return 1
  printf '%s\n' "$top"
}

worktree_repo_root_for_context() {
  local repo_path="${1:-}"
  local cmux_bin current_workspace_root current_pwd_root

  if [ -n "$repo_path" ]; then
    worktree_repo_root_for_path "$repo_path"
    return
  fi

  cmux_bin="$(find_cmux)"
  current_workspace_root="$(worktree_repo_root_from_cmux "$cmux_bin" 2>/dev/null || true)"
  if [ -n "$current_workspace_root" ]; then
    printf '%s\n' "$current_workspace_root"
    return 0
  fi

  current_pwd_root="$(worktree_repo_root_for_path "$PWD" 2>/dev/null || true)"
  [ -n "$current_pwd_root" ] || return 1
  printf '%s\n' "$current_pwd_root"
}

worktree_update_target_path() {
  local target="${1:-}"
  local resolved=""

  if [ -n "$target" ] && [ -e "$target" ]; then
    resolved="$(resolve_dir "$target" 2>/dev/null || true)"
    [ -n "$resolved" ] || fail "worktree target is not a directory: $target"
    printf '%s\n' "$resolved"
    return 0
  fi

  if [ -n "$target" ]; then
    return 1
  fi

  if resolved="$(worktree_current_path_from_pwd 2>/dev/null || true)"; then
    if [ -n "$resolved" ]; then
      printf '%s\n' "$resolved"
      return 0
    fi
  fi

  return 1
}

worktree_base_path_for_root() {
  local canonical_root="$1"
  local repo_slug relative_repo_path repos_root

  case "$canonical_root" in
    */Workspaces/repos/*)
      repos_root="${canonical_root%%/Workspaces/repos/*}/Workspaces/repos"
      relative_repo_path="${canonical_root#"$repos_root"/}"
      printf '%s\n' "${repos_root%/repos}/worktrees/$relative_repo_path"
      ;;
    *)
      repo_slug="$(slugify_name "$(basename "$canonical_root")")" || return 1
      printf '%s\n' "$WORKTREE_DIR/external/$repo_slug"
      ;;
  esac
}

worktree_move_destination_path() {
  local repo_root="$1"
  local destination="$2"
  local canonical_root worktree_base parent resolved_parent

  case "$destination" in
    ~) destination="$HOME" ;;
    ~/*) destination="$HOME/${destination#~/}" ;;
  esac

  case "$destination" in
    /*)
      printf '%s\n' "$destination"
      return 0
      ;;
    */*)
      parent="$(dirname "$destination")"
      [ -d "$parent" ] || return 1
      resolved_parent="$(cd "$parent" && pwd -P)" || return 1
      printf '%s/%s\n' "$resolved_parent" "$(basename "$destination")"
      return 0
      ;;
  esac

  canonical_root="$(canonical_git_root "$repo_root")" || return 1
  worktree_base="$(worktree_base_path_for_root "$canonical_root")" || return 1
  printf '%s/%s\n' "$worktree_base" "$(slugify_name "$destination")"
}
