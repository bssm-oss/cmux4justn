#!/usr/bin/env bash
# shellcheck disable=SC2034

C4J_CONTRACT_HELP_TOPICS=(
  add
  cd
  go
  anchor
  delete
  remove
  rm
  repair
  reconcile
  setup
  sync
  list
  config
  doctor
  update
  worktree
  wt
  version
  agent
  scripts
  automation
  ax
)

C4J_CONTRACT_TOP_COMMANDS=(
  add
  cd
  go
  anchor
  delete
  update
  repair
  reconcile
  setup
  sync
  list
  config
  doctor
  version
  help
  remove
  rm
)

C4J_CONTRACT_COMMANDS=(
  "${C4J_CONTRACT_TOP_COMMANDS[@]}"
  worktree
  wt
  pane
  make-pane
)

C4J_CONTRACT_WORKTREE_SUBCOMMANDS=(
  list
  ls
  prune
  move
  delete
  remove
  rm
  update
  refresh
  up
)

C4J_ACTION_CD_PROJECT="cd-project"
C4J_ACTION_GO_PROJECT="go-project"
C4J_ACTION_CREATE_WORKTREE="create-worktree"
C4J_ACTION_REUSE_WORKTREE="reuse-worktree"
C4J_ACTION_MOVE_WORKTREE="move-worktree"
