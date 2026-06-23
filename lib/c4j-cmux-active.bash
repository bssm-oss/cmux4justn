#!/usr/bin/env bash

is_safe_name() {
  local name="$1"
  [ -n "$name" ] || return 1
  [ "$name" != "." ] || return 1
  [ "$name" != ".." ] || return 1
  case "$name" in
    */*|*..*) return 1 ;;
  esac
  return 0
}

find_cmux() {
  if [ -n "$CMUX_BIN" ]; then
    printf '%s\n' "$CMUX_BIN"
  elif command -v cmux >/dev/null 2>&1; then
    command -v cmux
  elif [ -x "/Applications/cmux.app/Contents/Resources/bin/cmux" ]; then
    printf '%s\n' "/Applications/cmux.app/Contents/Resources/bin/cmux"
  else
    printf '%s\n' "cmux"
  fi
}

cmux_available() {
  local cmux_bin="$1"
  command -v "$cmux_bin" >/dev/null 2>&1 || [ -x "$cmux_bin" ]
}

has_direction() {
  local direction="$1"
  local requested="$2"
  case "$direction:$requested" in
    active-to-cmux:active-to-cmux|both:active-to-cmux|cmux-to-active:cmux-to-active|both:cmux-to-active)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

load_cmux_inventory() {
  local cmux_bin="$1"
  local output_file="$2"
  : > "$output_file"

  cmux_available "$cmux_bin" || return 1

  local json
  json="$("$cmux_bin" --json list-workspaces 2>/dev/null)" || return 1

  local parsed_file
  parsed_file="$(mktemp)"

  if command -v python3 >/dev/null 2>&1; then
    if JSON_INPUT="$json" python3 - "$parsed_file" <<'PY'
import json
import os
import sys

output_path = sys.argv[1]
data = json.loads(os.environ["JSON_INPUT"])
with open(output_path, "w", encoding="utf-8") as handle:
    for workspace in data.get("workspaces", []):
        title = workspace.get("title")
        cwd = workspace.get("current_directory")
        ref = workspace.get("ref")
        if (
            isinstance(title, str)
            and isinstance(cwd, str)
            and isinstance(ref, str)
            and not any(ch in title for ch in "\t\r\n")
            and not any(ch in cwd for ch in "\t\r\n")
            and not any(ch in ref for ch in "\t\r\n")
        ):
            handle.write(f"{title}\t{cwd}\t{ref}\n")
PY
    then
      mv "$parsed_file" "$output_file"
      return 0
    fi
    rm -f "$parsed_file"
    return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    if printf '%s\n' "$json" | jq -r '.workspaces[] | select(.title and .current_directory and .ref) | select((.title | test("[\\t\\r\\n]") | not) and (.current_directory | test("[\\t\\r\\n]") | not) and (.ref | test("[\\t\\r\\n]") | not)) | [.title, .current_directory, .ref] | @tsv' > "$parsed_file"; then
      mv "$parsed_file" "$output_file"
      return 0
    fi
    rm -f "$parsed_file"
    return 1
  fi

  rm -f "$parsed_file"
  return 1
}

cmux_workspace_directory() {
  local cmux_bin="$1"

  cmux_available "$cmux_bin" || return 1

  local identify_json inventory_file workspace_ref
  identify_json="$("$cmux_bin" identify --json 2>/dev/null)" || return 1

  if command -v python3 >/dev/null 2>&1; then
    if ! workspace_ref="$(IDENTIFY_JSON="$identify_json" python3 - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["IDENTIFY_JSON"])
for key in ("caller", "focused"):
    block = data.get(key, {})
    ref = block.get("workspace_ref")
    if isinstance(ref, str) and ref and not any(ch in ref for ch in "\t\r\n"):
        print(ref)
        sys.exit(0)
sys.exit(1)
PY
    )"; then
      return 1
    fi
  elif command -v jq >/dev/null 2>&1; then
    workspace_ref="$(printf '%s\n' "$identify_json" | jq -r '.caller.workspace_ref // .focused.workspace_ref // empty')"
  else
    return 1
  fi

  [ -n "$workspace_ref" ] || return 1

  inventory_file="$(mktemp)"
  if ! load_cmux_inventory "$cmux_bin" "$inventory_file"; then
    rm -f "$inventory_file"
    return 1
  fi

  awk -F '\t' -v ref="$workspace_ref" '
    $3 == ref {
      print $2
      found = 1
      exit
    }
    END { exit found ? 0 : 1 }
  ' "$inventory_file"
  local status=$?
  rm -f "$inventory_file"
  return "$status"
}

workspace_title_exists() {
  local inventory_file="$1"
  local title="$2"
  awk -F '\t' -v title="$title" '$1 == title { found = 1 } END { exit found ? 0 : 1 }' "$inventory_file"
}

workspace_ref_for_title() {
  local inventory_file="$1"
  local title="$2"
  awk -F '\t' -v title="$title" '$1 == title { print $3; found = 1; exit } END { exit found ? 0 : 1 }' "$inventory_file"
}

workspace_cwd_for_title() {
  local inventory_file="$1"
  local title="$2"
  awk -F '\t' -v title="$title" '$1 == title { print $2; found = 1; exit } END { exit found ? 0 : 1 }' "$inventory_file"
}

active_name_for_query() {
  local query="$1"
  local query_lower matches_file

  is_safe_name "$query" || return 1

  if [ -L "$ACTIVE_DIR/$query" ]; then
    printf '%s\n' "$query"
    return 0
  fi

  query_lower="$(printf '%s\n' "$query" | tr '[:upper:]' '[:lower:]')"
  matches_file="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$matches_file'" RETURN

  shopt -s nullglob
  local link name name_lower
  for link in "$ACTIVE_DIR"/*; do
    [ -L "$link" ] || continue
    name="$(basename "$link")"
    name_lower="$(printf '%s\n' "$name" | tr '[:upper:]' '[:lower:]')"
    if [ "$name_lower" = "$query_lower" ]; then
      printf '%s\n' "$name" >> "$matches_file"
    fi
  done
  shopt -u nullglob

  local match_count
  match_count="$(wc -l < "$matches_file" | tr -d ' ')"
  if [ "$match_count" -eq 1 ]; then
    cat "$matches_file"
    return 0
  fi
  if [ "$match_count" -gt 1 ]; then
    cat "$matches_file"
    return 2
  fi
  return 1
}

active_name_from_delete_arg() {
  local arg="$1"
  local target

  if target="$(resolve_dir "$arg" 2>/dev/null)"; then
    basename "$target"
    return 0
  fi

  case "$arg" in
    "$NAME_PREFIX"*)
      printf '%s\n' "${arg#"$NAME_PREFIX"}"
      ;;
    */*)
      fail "delete target is not an existing directory or active name: $arg"
      ;;
    *)
      printf '%s\n' "$arg"
      ;;
  esac
}
