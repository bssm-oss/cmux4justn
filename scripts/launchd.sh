#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DEFAULT_C4J="$ROOT/bin/c4j"
LABEL="com.justn.c4j.sync"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LAUNCHCTL_BIN="launchctl"
C4J_BIN="$DEFAULT_C4J"
ACTIVE_DIR=""
CMUX_BIN=""
SYNC_APPLY=0
APPLY=0
LOAD=0

usage() {
  cat <<'USAGE'
Usage:
  scripts/launchd.sh print [options]
  scripts/launchd.sh install [options]
  scripts/launchd.sh uninstall [options]

Options:
  --apply                    required for any file writes/removals
  --load                     load after install, unload before uninstall
  --sync-apply               run scheduled sync with --apply (default: --dry-run)
  --active-dir PATH          pass --active-dir PATH to c4j sync
  --cmux PATH                pass --cmux PATH to c4j sync
  --c4j PATH                 c4j executable path for launchd job
  --cmux4justn PATH          compatibility alias for --c4j
  --launch-agents-dir PATH   override LaunchAgents directory
  --launchctl PATH           override launchctl binary path
  --label TEXT               override launchd label
  -h, --help                 show help

Safety defaults:
  - No writes unless --apply is provided
  - No load/unload unless --load is provided
  - Scheduled sync uses --dry-run unless --sync-apply is passed
USAGE
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

xml_escape() {
  local input="$1"
  input=${input//&/\&amp;}
  input=${input//</\&lt;}
  input=${input//>/\&gt;}
  input=${input//\"/\&quot;}
  input=${input//\'/\&apos;}
  printf '%s' "$input"
}

plist_path() {
  printf '%s/%s.plist\n' "$LAUNCH_AGENTS_DIR" "$LABEL"
}

build_plist() {
  local arg_sync_mode="--dry-run"
  if [ "$SYNC_APPLY" -eq 1 ]; then
    arg_sync_mode="--apply"
  fi

  local escaped_label escaped_c4j escaped_active escaped_cmux
  escaped_label="$(xml_escape "$LABEL")"
  escaped_c4j="$(xml_escape "$C4J_BIN")"

  printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
  printf '%s\n' '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
  printf '%s\n' '<plist version="1.0">'
  printf '%s\n' '<dict>'
  printf '%s\n' '  <key>Label</key>'
  printf '  <string>%s</string>\n' "$escaped_label"
  printf '%s\n' '  <key>ProgramArguments</key>'
  printf '%s\n' '  <array>'
  printf '    <string>%s</string>\n' "$escaped_c4j"
  printf '%s\n' '    <string>sync</string>'
  printf '%s\n' '    <string>--direction</string>'
  printf '%s\n' '    <string>both</string>'
  printf '    <string>%s</string>\n' "$arg_sync_mode"

  if [ -n "$ACTIVE_DIR" ]; then
    escaped_active="$(xml_escape "$ACTIVE_DIR")"
    printf '%s\n' '    <string>--active-dir</string>'
    printf '    <string>%s</string>\n' "$escaped_active"
  fi

  if [ -n "$CMUX_BIN" ]; then
    escaped_cmux="$(xml_escape "$CMUX_BIN")"
    printf '%s\n' '    <string>--cmux</string>'
    printf '    <string>%s</string>\n' "$escaped_cmux"
  fi

  printf '%s\n' '  </array>'
  printf '%s\n' '  <key>StartInterval</key>'
  printf '%s\n' '  <integer>3600</integer>'
  printf '%s\n' '  <key>RunAtLoad</key>'
  printf '%s\n' '  <false/>'
  printf '%s\n' '</dict>'
  printf '%s\n' '</plist>'
}

COMMAND="${1:-}"
if [ "$#" -gt 0 ]; then
  shift
fi

case "$COMMAND" in
  print|install|uninstall) ;;
  -h|--help|help|"")
    usage
    exit 0
    ;;
  *)
    fail "unknown command: $COMMAND"
    ;;
esac

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --load)
      LOAD=1
      shift
      ;;
    --sync-apply)
      SYNC_APPLY=1
      shift
      ;;
    --active-dir)
      [ "$#" -ge 2 ] || fail "--active-dir requires a path"
      ACTIVE_DIR="$2"
      shift 2
      ;;
    --cmux)
      [ "$#" -ge 2 ] || fail "--cmux requires a path"
      CMUX_BIN="$2"
      shift 2
      ;;
    --c4j|--cmux4justn)
      [ "$#" -ge 2 ] || fail "$1 requires a path"
      C4J_BIN="$2"
      shift 2
      ;;
    --launch-agents-dir)
      [ "$#" -ge 2 ] || fail "--launch-agents-dir requires a path"
      LAUNCH_AGENTS_DIR="$2"
      shift 2
      ;;
    --launchctl)
      [ "$#" -ge 2 ] || fail "--launchctl requires a path"
      LAUNCHCTL_BIN="$2"
      shift 2
      ;;
    --label)
      [ "$#" -ge 2 ] || fail "--label requires text"
      LABEL="$2"
      shift 2
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

PLIST_PATH="$(plist_path)"

case "$COMMAND" in
  print)
    build_plist
    ;;
  install)
    if [ "$APPLY" -ne 1 ]; then
      printf 'dry-run\tno-write\t%s\n' "$PLIST_PATH"
      printf 'hint\tpass --apply to write plist\n'
      if [ "$LOAD" -eq 1 ]; then
        printf 'hint\t--load ignored without --apply\n'
      fi
      exit 0
    fi

    mkdir -p "$LAUNCH_AGENTS_DIR"
    build_plist > "$PLIST_PATH"
    printf 'installed\t%s\n' "$PLIST_PATH"

    if [ "$LOAD" -eq 1 ]; then
      "$LAUNCHCTL_BIN" unload "$PLIST_PATH" >/dev/null 2>&1 || true
      "$LAUNCHCTL_BIN" load "$PLIST_PATH"
      printf 'loaded\t%s\n' "$PLIST_PATH"
    else
      printf 'skip load\tpass --load to enable automation\n'
    fi
    ;;
  uninstall)
    if [ "$APPLY" -ne 1 ]; then
      printf 'dry-run\tno-remove\t%s\n' "$PLIST_PATH"
      printf 'hint\tpass --apply to remove plist\n'
      if [ "$LOAD" -eq 1 ]; then
        printf 'hint\t--load ignored without --apply\n'
      fi
      exit 0
    fi

    if [ "$LOAD" -eq 1 ]; then
      "$LAUNCHCTL_BIN" unload "$PLIST_PATH" >/dev/null 2>&1 || true
      printf 'unloaded\t%s\n' "$PLIST_PATH"
    else
      printf 'skip unload\tpass --load to disable loaded automation\n'
    fi

    if [ -e "$PLIST_PATH" ]; then
      rm -f "$PLIST_PATH"
      printf 'removed\t%s\n' "$PLIST_PATH"
    else
      printf 'skip missing\t%s\n' "$PLIST_PATH"
    fi
    ;;
esac
