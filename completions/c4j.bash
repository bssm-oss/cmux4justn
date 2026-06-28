#!/usr/bin/env bash

_c4j__source_contract() {
  local completion_dir contract_file
  completion_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  contract_file="$completion_dir/../lib/c4j-contract.bash"
  if [ -f "$contract_file" ]; then
    # shellcheck disable=SC1090,SC1091
    source "$contract_file"
  fi
}

_c4j__source_contract
if ! declare -p C4J_CONTRACT_HELP_TOPICS >/dev/null 2>&1; then
  C4J_CONTRACT_HELP_TOPICS=(add cd go anchor delete remove rm repair reconcile setup sync list config doctor update worktree wt version agent scripts automation ax)
fi
if ! declare -p C4J_CONTRACT_TOP_COMMANDS >/dev/null 2>&1; then
  C4J_CONTRACT_TOP_COMMANDS=(add cd go anchor delete update repair reconcile setup sync list config doctor version help remove rm)
fi
if ! declare -p C4J_CONTRACT_COMMANDS >/dev/null 2>&1; then
  C4J_CONTRACT_COMMANDS=("${C4J_CONTRACT_TOP_COMMANDS[@]}" worktree wt pane make-pane)
fi
if ! declare -p C4J_CONTRACT_WORKTREE_SUBCOMMANDS >/dev/null 2>&1; then
  C4J_CONTRACT_WORKTREE_SUBCOMMANDS=(list ls prune move delete remove rm update refresh up)
fi

_c4j__complete_dirs() {
  local cur="${1:-}"
  local entry

  COMPREPLY=()
  while IFS= read -r entry; do
    COMPREPLY+=("$entry")
  done < <(compgen -d -- "$cur")
}

_c4j__complete_words() {
  local cur="${1:-}"
  shift

  COMPREPLY=()
  _c4j__append_words "$cur" "$@"
}

_c4j__append_words() {
  local cur="${1:-}"
  shift
  local word

  for word in "$@"; do
    case "$word" in
      "$cur"*) COMPREPLY+=("$word") ;;
    esac
  done
}

_c4j__active_dir() {
  if [ -n "${C4J_ACTIVE_DIR:-}" ]; then
    printf '%s\n' "$C4J_ACTIVE_DIR"
    return 0
  fi
  if [ -n "${CMUX4JUSTN_ACTIVE_DIR:-}" ]; then
    printf '%s\n' "$CMUX4JUSTN_ACTIVE_DIR"
    return 0
  fi

  local config_file="${C4J_CONFIG:-${CMUX4JUSTN_CONFIG:-${HOME:-}/.c4j/config}}"
  if [ -f "$config_file" ]; then
    awk -F '=' '$1 == "active_dir" { print substr($0, length("active_dir") + 2); found = 1 } END { exit found ? 0 : 1 }' "$config_file" 2>/dev/null && return 0
  fi

  printf '%s\n' "${HOME:-}/.c4j/active"
}

_c4j__append_active_projects() {
  local cur="${1:-}"
  local active_dir link name

  active_dir="$(_c4j__active_dir 2>/dev/null || true)"
  [ -d "$active_dir" ] || return 0

  shopt -s nullglob
  for link in "$active_dir"/*; do
    [ -L "$link" ] || continue
    name="$(basename "$link")"
    case "$name" in
      "$cur"*) COMPREPLY+=("$name") ;;
    esac
  done
  shopt -u nullglob
}

_c4j__complete_help_topics() {
  local cur="${1:-}"
  _c4j__complete_words "$cur" "${C4J_CONTRACT_HELP_TOPICS[@]}"
}
_c4j__worktree_subcommand() {
  local index=2
  local word

  while [ "$index" -lt "$COMP_CWORD" ]; do
    word="${COMP_WORDS[$index]:-}"
    case "$word" in
      --dry-run|--apply|-h|--help|--no-cmux)
        index=$((index + 1))
        ;;
      --repo|--target|--to|--destination)
        index=$((index + 2))
        ;;
      --name|--cmux|--name-prefix|--workspace-name|--command)
        return 0
        ;;
      --)
        index=$((index + 1))
        if [ "$index" -lt "$COMP_CWORD" ]; then
          printf '%s\n' "${COMP_WORDS[$index]}"
        fi
        return 0
        ;;
      --*)
        index=$((index + 1))
        ;;
      list|ls|prune|move|delete|remove|rm|update|refresh|up)
        printf '%s\n' "$word"
        return 0
        ;;
      *)
        return 0
        ;;
    esac
  done

  return 0
}

_c4j_complete() {
  local cur prev command subcommand field

  cur="${COMP_WORDS[COMP_CWORD]:-}"
  prev="${COMP_WORDS[COMP_CWORD-1]:-}"
  command="${COMP_WORDS[1]:-}"
  subcommand="${COMP_WORDS[2]:-}"
  case "$command" in
    worktree|wt|pane|make-pane)
      subcommand="$(_c4j__worktree_subcommand)"
      ;;
  esac
  field="${COMP_WORDS[3]:-}"

  case "$prev" in
    --cwd|--active-dir|--repo|--cmux)
      _c4j__complete_dirs "$cur"
      return 0
      ;;
  esac

  if [[ "$cur" == -* ]]; then
    case "$command" in
      add)
        _c4j__complete_words "$cur" --dry-run --apply -h --help
        ;;
      cd)
        _c4j__complete_words "$cur" --dry-run --apply --active-dir -h --help
        ;;
      go)
        _c4j__complete_words "$cur" --dry-run --apply --no-cmux --active-dir --cmux --name-prefix -h --help
        ;;
      anchor)
        _c4j__complete_words "$cur" --dry-run --apply --name --cwd -h --help
        ;;
      delete|remove|rm)
        _c4j__complete_words "$cur" --dry-run --apply --keep-cmux -h --help
        ;;
      update)
        _c4j__complete_words "$cur" --dry-run --apply --ref --repo-url --install-dir --allow-unsafe-source -h --help
        ;;
      worktree|wt|pane|make-pane)
        case "$subcommand" in
          list|ls)
            _c4j__complete_words "$cur" --repo --plain --tsv -h --help
            ;;
          prune)
            _c4j__complete_words "$cur" --dry-run --apply --repo -h --help
            ;;
          move)
            _c4j__complete_words "$cur" --dry-run --apply --repo --target --to --destination -h --help
            ;;
          delete|remove|rm)
            _c4j__complete_words "$cur" --dry-run --apply --force --discard --repo --target -h --help
            ;;
          update|refresh|up)
            _c4j__complete_words "$cur" --dry-run --apply --repo --target -h --help
            ;;
          *)
            _c4j__complete_words "$cur" "${C4J_CONTRACT_WORKTREE_SUBCOMMANDS[@]}" --dry-run --apply --repo --name --no-cmux --cmux --name-prefix --workspace-name --command -h --help
            ;;
        esac
        ;;
      setup)
        _c4j__complete_words "$cur" --dry-run --apply --active-dir --name-prefix --prefix -h --help
        ;;
      sync)
        _c4j__complete_words "$cur" --dry-run --apply --direction --active-dir --cmux --name-prefix -h --help
        ;;
      repair|reconcile)
        _c4j__complete_words "$cur" --dry-run --apply --active-dir --cmux --name-prefix -h --help
        ;;
      list)
        _c4j__complete_words "$cur" --plain --tsv -h --help
        ;;
      config)
        case "$subcommand" in
          set)
            _c4j__complete_words "$cur" -h --help
            ;;
          unset)
            _c4j__complete_words "$cur" -h --help
            ;;
          *)
            _c4j__complete_words "$cur" get set unset path -h --help
            ;;
        esac
        ;;
      help)
        COMPREPLY=()
        ;;
      *)
        _c4j__complete_words "$cur" "${C4J_CONTRACT_TOP_COMMANDS[@]}" -h --help
        ;;
    esac
    return 0
  fi

  case "$command" in
    add)
      _c4j__complete_dirs "$cur"
      ;;
    cd)
      case "$prev" in
        --active-dir)
          _c4j__complete_dirs "$cur"
          ;;
        *)
          _c4j__complete_dirs "$cur"
          _c4j__append_active_projects "$cur"
          _c4j__append_words "$cur" --dry-run --apply --active-dir
          ;;
      esac
      ;;
    go)
      case "$prev" in
        --active-dir|--cmux)
          _c4j__complete_dirs "$cur"
          ;;
        --name-prefix)
          COMPREPLY=()
          ;;
        *)
          _c4j__complete_dirs "$cur"
          _c4j__append_active_projects "$cur"
          _c4j__append_words "$cur" --dry-run --apply --no-cmux --active-dir --cmux --name-prefix
          ;;
      esac
      ;;
    anchor)
      if [ "$prev" = "--name" ]; then
        COMPREPLY=()
      else
        _c4j__complete_words "$cur" --dry-run --apply --name --cwd
      fi
      ;;
    delete|remove|rm)
      _c4j__complete_dirs "$cur"
      ;;
    update)
      case "$prev" in
        --install-dir)
          _c4j__complete_dirs "$cur"
          ;;
        *)
          _c4j__complete_words "$cur" --dry-run --apply --ref --repo-url --install-dir --allow-unsafe-source
          ;;
      esac
      ;;
    worktree|wt|pane|make-pane)
      case "$subcommand" in
        list|ls)
          _c4j__complete_words "$cur" --repo --plain --tsv
          ;;
        prune)
          _c4j__complete_words "$cur" --dry-run --apply --repo
          ;;
        move)
          case "$prev" in
            --target|--repo|--to|--destination)
              _c4j__complete_dirs "$cur"
              ;;
            *)
              _c4j__complete_words "$cur" --dry-run --apply --repo --target --to --destination
              ;;
          esac
          ;;
        delete|remove|rm)
          case "$prev" in
            --target|--repo)
              _c4j__complete_dirs "$cur"
              ;;
            *)
              _c4j__complete_words "$cur" --dry-run --apply --force --discard --repo --target
              ;;
          esac
          ;;
        update|refresh|up)
          case "$prev" in
            --target|--repo)
              _c4j__complete_dirs "$cur"
              ;;
            *)
              _c4j__complete_words "$cur" --dry-run --apply --repo --target
              ;;
          esac
          ;;
        *)
          case "$prev" in
            --name|--workspace-name|--name-prefix|--command)
              COMPREPLY=()
              ;;
            --repo|--cmux)
              _c4j__complete_dirs "$cur"
              ;;
            *)
          _c4j__complete_words "$cur" "${C4J_CONTRACT_WORKTREE_SUBCOMMANDS[@]}" --dry-run --apply --repo --name --no-cmux --cmux --name-prefix --workspace-name --command
            ;;
        esac
      ;;
      esac
      ;;
    setup)
      case "$prev" in
        --name-prefix|--prefix)
          COMPREPLY=()
          ;;
        *)
          _c4j__complete_words "$cur" --dry-run --apply --active-dir --name-prefix --prefix
          ;;
      esac
      ;;
    config)
      case "$subcommand" in
        set)
          case "$field" in
            active-dir|workspace-dir|workspace-file)
              _c4j__complete_dirs "$cur"
              ;;
            cmux-bin)
              COMPREPLY=()
              ;;
            name-prefix|prefix|workspace-prefix)
              COMPREPLY=()
              ;;
            *)
              _c4j__complete_words "$cur" active-dir cmux-bin name-prefix prefix workspace-dir workspace-file workspace-prefix
              ;;
          esac
          ;;
        unset)
          _c4j__complete_words "$cur" active-dir cmux-bin name-prefix prefix workspace-dir workspace-file workspace-prefix
          ;;
        *)
          _c4j__complete_words "$cur" get set unset path
          ;;
      esac
      ;;
    help)
      case "$subcommand" in
        worktree|wt)
          _c4j__complete_words "$cur" "${C4J_CONTRACT_WORKTREE_SUBCOMMANDS[@]}"
          ;;
        "")
          _c4j__complete_help_topics "$cur"
          ;;
        *)
          COMPREPLY=()
          ;;
      esac
      ;;
    sync)
      case "$prev" in
        --direction)
          _c4j__complete_words "$cur" active-to-cmux cmux-to-active both
          ;;
        --name-prefix)
          COMPREPLY=()
          ;;
        *)
          _c4j__complete_words "$cur" --dry-run --apply --direction --active-dir --cmux --name-prefix
          ;;
      esac
      ;;
    repair|reconcile)
      case "$prev" in
        --name-prefix)
          COMPREPLY=()
          ;;
        --active-dir|--cmux)
          _c4j__complete_dirs "$cur"
          ;;
        *)
          _c4j__complete_words "$cur" --dry-run --apply --active-dir --cmux --name-prefix
          ;;
      esac
      ;;
    list|doctor|version)
      COMPREPLY=()
      ;;
    *)
      _c4j__complete_words "$cur" "${C4J_CONTRACT_COMMANDS[@]}"
      ;;
  esac
}

if [ -n "${ZSH_VERSION:-}" ] && ! type complete >/dev/null 2>&1; then
  autoload -Uz compinit 2>/dev/null || true
  compinit -C 2>/dev/null || true
  autoload -U +X bashcompinit 2>/dev/null || true
  bashcompinit 2>/dev/null || true
fi

if type complete >/dev/null 2>&1; then
  complete -o bashdefault -o default -o nospace -F _c4j_complete c4j cmux4justn
fi
