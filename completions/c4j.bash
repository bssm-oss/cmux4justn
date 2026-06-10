#!/usr/bin/env bash

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
  local word

  COMPREPLY=()
  for word in "$@"; do
    case "$word" in
      "$cur"*) COMPREPLY+=("$word") ;;
    esac
  done
}

_c4j_complete() {
  local cur prev command subcommand field

  cur="${COMP_WORDS[COMP_CWORD]:-}"
  prev="${COMP_WORDS[COMP_CWORD-1]:-}"
  command="${COMP_WORDS[1]:-}"
  subcommand="${COMP_WORDS[2]:-}"
  field="${COMP_WORDS[3]:-}"

  case "$prev" in
    --cwd|--active-dir|--repo)
      _c4j__complete_dirs "$cur"
      return 0
      ;;
  esac

  if [[ "$cur" == -* ]]; then
    case "$command" in
      add)
        _c4j__complete_words "$cur" --dry-run --apply -h --help
        ;;
      anchor)
        _c4j__complete_words "$cur" --dry-run --apply --name --cwd -h --help
        ;;
      delete|remove|rm)
        _c4j__complete_words "$cur" --dry-run --apply --keep-cmux -h --help
        ;;
      worktree|wt|pane|make-pane)
        _c4j__complete_words "$cur" --dry-run --apply --repo --name -h --help
        ;;
      setup)
        _c4j__complete_words "$cur" --dry-run --apply --active-dir --name-prefix --prefix -h --help
        ;;
      sync)
        _c4j__complete_words "$cur" --dry-run --apply --direction --active-dir --cmux --name-prefix -h --help
        ;;
      list)
        _c4j__complete_words "$cur" --plain --tsv -h --help
        ;;
      config)
        case "$subcommand" in
          set)
            _c4j__complete_words "$cur" active-dir cmux-bin name-prefix prefix workspace-dir workspace-file workspace-prefix
            ;;
          unset)
            _c4j__complete_words "$cur" active-dir name-prefix
            ;;
          *)
            _c4j__complete_words "$cur" get set unset path -h --help
            ;;
        esac
        ;;
      *)
        _c4j__complete_words "$cur" add anchor delete setup sync list config doctor version remove rm -h --help
        ;;
    esac
    return 0
  fi

  case "$command" in
    add)
      _c4j__complete_dirs "$cur"
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
    worktree|wt|pane|make-pane)
      case "$prev" in
        --name)
          COMPREPLY=()
          ;;
        *)
          _c4j__complete_words "$cur" --dry-run --apply --repo --name
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
          _c4j__complete_words "$cur" active-dir name-prefix prefix workspace-dir workspace-file workspace-prefix
          ;;
        *)
          _c4j__complete_words "$cur" get set unset path
          ;;
      esac
      ;;
    sync)
      case "$prev" in
        --direction)
          _c4j__complete_words "$cur" active-to-cmux cmux-to-active both
          ;;
        *)
          _c4j__complete_words "$cur" --dry-run --apply --direction --active-dir --cmux --name-prefix
          ;;
      esac
      ;;
    list|doctor|version)
      COMPREPLY=()
      ;;
    *)
      _c4j__complete_words "$cur" add anchor delete worktree wt pane make-pane setup sync list config doctor version remove rm
      ;;
  esac
}

if [ -n "${ZSH_VERSION:-}" ] && ! type complete >/dev/null 2>&1; then
  autoload -U +X bashcompinit 2>/dev/null || true
  bashcompinit 2>/dev/null || true
fi

if type complete >/dev/null 2>&1; then
  complete -o bashdefault -o default -o nospace -F _c4j_complete c4j cmux4justn
fi
