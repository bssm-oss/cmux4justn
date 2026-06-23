#!/usr/bin/env bash

tsv_row() {
  local first="$1"
  shift
  printf '%s' "$first"
  local field
  for field in "$@"; do
    printf '\t%s' "$field"
  done
  printf '\n'
}

print_apply_hint() {
  local command="$1"
  shift
  printf 'note\tdry-run\tapply with: c4j %s' "$command"
  if [ "$#" -gt 0 ]; then
    printf ' %s' "$@"
  fi
  printf ' --apply\n'
}
