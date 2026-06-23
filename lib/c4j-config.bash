#!/usr/bin/env bash

config_get_value() {
  local key="$1"
  [ -f "$CONFIG_FILE" ] || return 1
  awk -F '=' -v key="$key" '$1 == key { print substr($0, length(key) + 2); found = 1 } END { exit found ? 0 : 1 }' "$CONFIG_FILE"
}

config_key_for_field() {
  case "$1" in
    active-dir|workspace-dir|workspace-file)
      printf 'active_dir\n'
      ;;
    cmux-bin)
      printf 'cmux_bin\n'
      ;;
    name-prefix|prefix|workspace-prefix)
      printf 'name_prefix\n'
      ;;
    *)
      return 1
      ;;
  esac
}

config_value_for_field() {
  local field="$1"
  local value="$2"
  case "$field" in
    active-dir|workspace-dir|workspace-file)
      resolve_dir "$value" || return 1
      ;;
    cmux-bin)
      [ -n "$value" ] || return 1
      case "$value" in
        *$'\t'*|*$'\r'*|*$'\n'*) return 1 ;;
      esac
      printf '%s\n' "$value"
      ;;
    name-prefix|prefix|workspace-prefix)
      [ -n "$value" ] || return 1
      case "$value" in
        *$'\t'*|*$'\r'*|*$'\n'*) return 1 ;;
      esac
      printf '%s\n' "$value"
      ;;
    *)
      return 1
      ;;
  esac
}

config_write_value() {
  local key="$1"
  local value="$2"
  local dir tmp_file
  dir="$(dirname "$CONFIG_FILE")"
  mkdir -p "$dir"
  tmp_file="$(mktemp "$dir/.c4j.config.XXXXXX")"
  if [ -f "$CONFIG_FILE" ]; then
    awk -F '=' -v key="$key" '$1 != key { print }' "$CONFIG_FILE" > "$tmp_file"
  fi
  printf '%s=%s\n' "$key" "$value" >> "$tmp_file"
  mv "$tmp_file" "$CONFIG_FILE"
}

config_unset_value() {
  local key="$1"
  local tmp_file
  [ -f "$CONFIG_FILE" ] || return 0
  tmp_file="$(mktemp "$(dirname "$CONFIG_FILE")/.c4j.config.XXXXXX")"
  awk -F '=' -v key="$key" '$1 != key { print }' "$CONFIG_FILE" > "$tmp_file"
  mv "$tmp_file" "$CONFIG_FILE"
}
