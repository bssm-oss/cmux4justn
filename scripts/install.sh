#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
CLI="$ROOT/bin/cmux4justn"
BIN_DIR="${C4J_BIN_DIR:-$HOME/.local/bin}"
ACTIVE_DIR="${C4J_ACTIVE_DIR:-$HOME/.c4j/active}"
CONFIG_FILE="${C4J_CONFIG:-$HOME/.c4j/config}"
SHELL_RC="${C4J_SHELL_RC:-${CMUX4JUSTN_SHELL_RC:-$HOME/.zshrc}}"
INSTALL_BIN=1
CREATE_ACTIVE=1
WRITE_CONFIG=1
UPDATE_RC=0
DRY_RUN=0
MARKER_START="# >>> c4j >>>"
MARKER_END="# <<< c4j <<<"
COMPLETION_MARKER_START="# >>> c4j completion >>>"
COMPLETION_MARKER_END="# <<< c4j completion <<<"

usage() {
  cat <<'USAGE'
Usage: scripts/install.sh [--dry-run] [--bin-dir PATH] [--no-bin] [--active-dir PATH] [--no-active-dir] [--config PATH] [--no-config] [--rc] [--shell-rc PATH] [--no-rc]

Defaults:
  - Installs c4j into ~/.local/bin, or C4J_BIN_DIR.
  - Creates ~/.c4j/active, or C4J_ACTIVE_DIR.
  - Writes ~/.c4j/config, or C4J_CONFIG.
  - Does not edit shell rc unless --rc is passed.

Options:
  --bin-dir PATH   Install c4j executable into PATH directory.
  --no-bin         Skip executable install.
  --active-dir PATH
                   Create the active-project symlink registry at PATH.
  --no-active-dir  Skip active directory creation.
  --config PATH    Write config to PATH.
  --no-config      Skip config write.
  --rc             Add a shell wrapper and completion fallback to shell rc.
  --shell-rc PATH  Override shell rc file target.
  --no-rc          Skip shell rc update.
  --dry-run        Print planned changes only.
USAGE
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

path_has_dir() {
  local dir="$1"
  case ":${PATH:-}:" in
    *":$dir:"*) return 0 ;;
    *) return 1 ;;
  esac
}

print_next_steps() {
  printf '\n'
  printf 'c4j is installed.\n'
  printf '  executable: %s\n' "$TARGET_CLI"
  printf '  active dir: %s\n' "$ACTIVE_DIR"
  printf '  config: %s\n' "$CONFIG_FILE"

  if [ "$INSTALL_BIN" -eq 1 ] && ! path_has_dir "$BIN_DIR"; then
    printf '\n'
    printf 'PATH notice:\n'
    printf '  %s is not currently on PATH.\n' "$BIN_DIR"
    printf '  Add this to your shell rc, then open a new shell:\n'
    printf '    export PATH="%s:$%s"\n' "$BIN_DIR" "PATH"
    printf '  Or reinstall with --rc to add the shell wrapper and completion fallbacks.\n'
  fi

  if [ "$UPDATE_RC" -eq 1 ]; then
    printf '\n'
    printf 'Shell rc updated. Open a new shell or run:\n'
    printf '  source %s\n' "$SHELL_RC"
  fi

  printf '\n'
  printf 'Check setup:\n'
  if [ "$INSTALL_BIN" -eq 1 ] && path_has_dir "$BIN_DIR"; then
    printf '  c4j doctor\n'
  else
    printf '  %s doctor\n' "$TARGET_CLI"
  fi
}

write_wrapper_block() {
  local shell_rc="$1"
  local wrapper_file tmp_file
  wrapper_file="$(mktemp)"
  tmp_file="$(mktemp)"
  printf '%s\n' "$WRAPPER_FUNCTION" > "$wrapper_file"
  awk -v start="$MARKER_START" -v end="$MARKER_END" -v wrapper_file="$wrapper_file" '
    BEGIN { in_block = 0 }
    $0 == start {
      print
      while ((getline line < wrapper_file) > 0) {
        print line
      }
      close(wrapper_file)
      in_block = 1
      next
    }
    in_block && $0 == end {
      print
      in_block = 0
      next
    }
    in_block { next }
    { print }
  ' "$shell_rc" > "$tmp_file"
  mv "$tmp_file" "$shell_rc"
  rm -f "$wrapper_file"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --bin-dir)
      [ "$#" -ge 2 ] || fail "--bin-dir requires a path"
      BIN_DIR="$2"
      INSTALL_BIN=1
      shift 2
      ;;
    --no-bin)
      INSTALL_BIN=0
      shift
      ;;
    --active-dir)
      [ "$#" -ge 2 ] || fail "--active-dir requires a path"
      ACTIVE_DIR="$2"
      CREATE_ACTIVE=1
      WRITE_CONFIG=1
      shift 2
      ;;
    --no-active-dir)
      CREATE_ACTIVE=0
      shift
      ;;
    --config)
      [ "$#" -ge 2 ] || fail "--config requires a path"
      CONFIG_FILE="$2"
      WRITE_CONFIG=1
      shift 2
      ;;
    --no-config)
      WRITE_CONFIG=0
      shift
      ;;
    --rc)
      UPDATE_RC=1
      shift
      ;;
    --shell-rc)
      [ "$#" -ge 2 ] || fail "--shell-rc requires a path"
      SHELL_RC="$2"
      UPDATE_RC=1
      shift 2
      ;;
    --no-rc)
      UPDATE_RC=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

TARGET_CLI="$BIN_DIR/c4j"
WRAPPER_FUNCTION="c4j() {
  local c4j_output c4j_status c4j_worktree_path
  c4j_output=\"\$($TARGET_CLI \"\$@\" 2>&1)\"
  c4j_status=\$?
  printf '%s\n' \"\$c4j_output\"
  if [ \"\$c4j_status\" -ne 0 ]; then
    return \"\$c4j_status\"
  fi
  case \"\${1:-}\" in
    go)
      c4j_worktree_path=\$(printf '%s\n' \"\$c4j_output\" | awk -F '\\t' '\$1 == \"go-project\" { print \$3; exit }')
      if [ -n \"\$c4j_worktree_path\" ] && [ -d \"\$c4j_worktree_path\" ]; then
        builtin cd -- \"\$c4j_worktree_path\"
      fi
      ;;
    worktree|wt|pane|make-pane)
      c4j_worktree_path=\$(printf '%s\n' \"\$c4j_output\" | awk -F '\\t' '(\$1 == \"create-worktree\" || \$1 == \"reuse-worktree\") { print \$3; exit } \$1 == \"move-worktree\" { print \$4; exit }')
      if [ -n \"\$c4j_worktree_path\" ] && [ -d \"\$c4j_worktree_path\" ]; then
        builtin cd -- \"\$c4j_worktree_path\"
      fi
      ;;
  esac
}"
COMPLETION_SOURCE="$ROOT/completions/c4j.bash"
COMPLETION_LINE="[ -f $(printf '%q' "$COMPLETION_SOURCE") ] && source $(printf '%q' "$COMPLETION_SOURCE")"

if [ "$INSTALL_BIN" -eq 0 ] && [ "$UPDATE_RC" -eq 0 ] && [ "$CREATE_ACTIVE" -eq 0 ] && [ "$WRITE_CONFIG" -eq 0 ]; then
  fail "nothing to install; use --bin-dir or --rc"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  if [ ! -x "$CLI" ]; then
    printf 'would-chmod\t%s\n' "$CLI"
  fi

  if [ "$INSTALL_BIN" -eq 1 ]; then
    printf 'would-install-bin\t%s\t%s\n' "$CLI" "$TARGET_CLI"
  else
    printf 'would-skip-bin\n'
  fi

  if [ "$CREATE_ACTIVE" -eq 1 ]; then
    printf 'would-create-active-dir\t%s\n' "$ACTIVE_DIR"
  else
    printf 'would-skip-active-dir\n'
  fi

  if [ "$WRITE_CONFIG" -eq 1 ]; then
    printf 'would-write-config\t%s\tactive_dir=%s\n' "$CONFIG_FILE" "$ACTIVE_DIR"
  else
    printf 'would-skip-config\n'
  fi

  if [ "$UPDATE_RC" -eq 1 ]; then
    printf 'would-update-rc\t%s\n' "$SHELL_RC"
    printf '%s\n%s\n%s\n' "$MARKER_START" "$WRAPPER_FUNCTION" "$MARKER_END"
    printf '%s\n%s\n%s\n' "$COMPLETION_MARKER_START" "$COMPLETION_LINE" "$COMPLETION_MARKER_END"
  else
    printf 'would-skip-rc\n'
  fi

  if [ "$INSTALL_BIN" -eq 1 ] && ! path_has_dir "$BIN_DIR"; then
    printf 'would-warn-path-missing\t%s\n' "$BIN_DIR"
  fi
  exit 0
fi

[ -x "$CLI" ] || chmod +x "$CLI"

if [ "$INSTALL_BIN" -eq 1 ]; then
  mkdir -p "$BIN_DIR"
  if [ -e "$TARGET_CLI" ] && ! cmp -s "$CLI" "$TARGET_CLI"; then
    printf 'error: target executable already exists and differs: %s\n' "$TARGET_CLI" >&2
    exit 1
  fi
  if [ -e "$TARGET_CLI" ]; then
    printf 'skip existing-bin\t%s\n' "$TARGET_CLI"
  else
    install -m 0755 "$CLI" "$TARGET_CLI"
    printf 'installed-bin\t%s\n' "$TARGET_CLI"
  fi
else
  printf 'skip bin-install\n'
fi

if [ "$CREATE_ACTIVE" -eq 1 ]; then
  mkdir -p "$ACTIVE_DIR"
  ACTIVE_DIR="$(cd "$ACTIVE_DIR" && pwd -P)"
  printf 'active-dir\t%s\n' "$ACTIVE_DIR"
else
  printf 'skip active-dir\n'
fi

if [ "$WRITE_CONFIG" -eq 1 ]; then
  mkdir -p "$(dirname "$CONFIG_FILE")"
  tmp_config="$(mktemp)"
  if [ -f "$CONFIG_FILE" ]; then
    awk -F '=' '$1 != "active_dir" { print }' "$CONFIG_FILE" > "$tmp_config"
  fi
  printf 'active_dir=%s\n' "$ACTIVE_DIR" >> "$tmp_config"
  mv "$tmp_config" "$CONFIG_FILE"
  printf 'config\t%s\n' "$CONFIG_FILE"
else
  printf 'skip config\n'
fi

if [ "$UPDATE_RC" -ne 1 ]; then
  printf 'skip rc-update\n'
  print_next_steps
  exit 0
fi

mkdir -p "$(dirname "$SHELL_RC")"
touch "$SHELL_RC"

wrapper_present=0
completion_present=0
if grep -F "$MARKER_START" "$SHELL_RC" >/dev/null 2>&1 &&
  grep -F "go-project" "$SHELL_RC" >/dev/null 2>&1 &&
  grep -F "move-worktree" "$SHELL_RC" >/dev/null 2>&1; then
  wrapper_present=1
fi
if grep -F "$COMPLETION_MARKER_START" "$SHELL_RC" >/dev/null 2>&1; then
  completion_present=1
fi

if [ "$wrapper_present" -eq 1 ] && [ "$completion_present" -eq 1 ]; then
  printf 'skip existing-rc\t%s\n' "$SHELL_RC"
  print_next_steps
  exit 0
fi

if grep -F "$MARKER_START" "$SHELL_RC" >/dev/null 2>&1; then
  if [ "$wrapper_present" -eq 0 ]; then
    write_wrapper_block "$SHELL_RC"
    wrapper_present=1
    printf 'updated-rc\t%s\n' "$SHELL_RC"
  fi
fi

if [ "$wrapper_present" -eq 0 ]; then
  {
    printf '\n%s\n' "$MARKER_START"
    printf '%s\n' "$WRAPPER_FUNCTION"
    printf '%s\n' "$MARKER_END"
  } >> "$SHELL_RC"
  printf 'installed-rc\t%s\n' "$SHELL_RC"
  printf 'wrapper\tc4j -> %s\n' "$TARGET_CLI"
fi

if [ "$completion_present" -eq 0 ]; then
  {
    printf '\n%s\n' "$COMPLETION_MARKER_START"
    printf '%s\n' "$COMPLETION_LINE"
    printf '%s\n' "$COMPLETION_MARKER_END"
  } >> "$SHELL_RC"
  printf 'installed-completion\t%s\n' "$SHELL_RC"
fi

print_next_steps
