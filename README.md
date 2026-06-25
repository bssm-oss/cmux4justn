# c4j

[한국어 README](README.ko.md)

`c4j` is a macOS shell CLI for keeping active project symlinks and cmux workspaces in sync.

It gives cmux users a small workspace manager for adding projects, listing active work, syncing workspace titles, and keeping a pinned anchor workspace at `~/Workspaces`.

`c4j` is intentionally conservative: it creates missing symlinks and missing cmux workspaces, and only removes active symlinks or closes cmux workspaces when `c4j delete` is explicit.

## Features

- One-line macOS install with a plain Bash script.
- Active project registry backed by symlinks in `~/.c4j/active`.
- Fast project jump with `c4j go <name-or-path>`.
- Quiet shell directory jump with `c4j cd <name-or-path>`.
- cmux workspace sync with configurable title prefixes such as `@active/`.
- Pinned cmux anchor workspace support through `c4j anchor`.
- Git worktree creation for the current repo.
- Safe defaults: dry-run sync, explicit apply, and no real project directory deletion.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/v0.13.17/install.sh | bash -s -- --rc
```

The installer:

- downloads the source into `~/.local/share/c4j`
- installs `c4j` into `~/.local/bin/c4j`
- creates the active-project registry at `~/.c4j/active`
- writes the active registry path to `~/.c4j/config`
- adds the shell wrapper and completion fallback to your shell rc when `--rc` is passed

The `--rc` wrapper is what lets `c4j go`, `c4j cd`, and `c4j wt` change the current shell directory. If `~/.local/bin` is not on `PATH`, the installer prints the exact export line to add to your shell rc. Then check the setup:

```bash
c4j doctor
```

## Quick Start

```bash
# Open the current project and focus its cmux workspace.
c4j go .

# Open a known active project by name.
c4j go cmux4justn

# Change only the current shell directory, without touching cmux.
c4j cd cmux4justn

# Make a worktree for the current repo and cd into it.
c4j wt feature-api

# Re-enter an existing worktree.
c4j wt list

# Remove a managed worktree when you are done.
c4j wt delete feature-api

# List active projects.
c4j list

# Preview a c4j/cmux reconciliation.
c4j repair

# Remove a project from the active registry and close its cmux workspace.
c4j delete cmux4justn

# Show focused help for one command.
c4j help go
c4j help cd
c4j help wt
```

## Commands

Use `c4j help <command>` or `c4j <command> --help` for focused command help.
Use `c4j help agent` for automation-friendly output conventions.

### `c4j go [--dry-run|--apply] [--no-cmux] <name-or-path>`

Jumps to an active project by name, or to a directory path. If you pass a path that is not active yet, `go` adds it to the active registry first.

`go` defaults to `--apply`. It selects an existing `@active/<project>` cmux workspace, creates one when missing, then prints a `go-project` row. When installed with `scripts/install.sh --rc`, the shell wrapper reads that row and changes the current shell directory to the project.

Use `--no-cmux` when you only want the shell directory jump and active symlink management.

```bash
c4j go cmux4justn
c4j go codeagora
c4j go .
c4j go ~/Workspaces/repos/bssm-oss/main/justn-hyeok/cmux4justn
c4j go --dry-run cmux4justn
c4j go --no-cmux cmux4justn
```

### `c4j cd [--dry-run|--apply] <name-or-path>`

Changes the current shell directory to an active project by name, or to a directory path. It does not touch cmux and does not add new active symlinks.

Like any `cd` helper, this requires the shell wrapper installed with `scripts/install.sh --rc`. Without that wrapper, the standalone executable can only print the resolved target row for scripts.

```bash
c4j cd cmux4justn
c4j cd .
c4j cd --dry-run codeagora
```

### `c4j worktree [--dry-run|--apply] [--repo <path>] [--name <name>]`

Creates a git worktree for the current repo under `~/Workspaces/worktrees`, mirroring the canonical repo path under `~/Workspaces/repos`.
If you run it from inside the repo you want to branch off, it uses that current working directory as the source repo. If that directory is not a git repo but you are inside cmux, it falls back to the current cmux workspace's repo. Pass `--repo` to override the source path.
The first positional argument is the worktree name, so `c4j wt for-feature1` is the normal shorthand.

The default worktree name is `<repo>-<branch>`. If that name already exists, `c4j` appends `-2`, `-3`, and so on. Pass `--name` to override the worktree name directly.

`worktree` defaults to `--apply`. `wt`, `pane`, and `make-pane` are aliases.
When you use the shell wrapper installed by `scripts/install.sh`, a successful `c4j wt ...` also changes the current shell directory to the created or reused worktree.
`c4j wt list` shows worktrees for the current cmux workspace when one is active, otherwise it shows every managed worktree it can discover.
`c4j wt prune` prunes stale worktree metadata for the current workspace scope, and `c4j wt move` moves a named or current worktree to a new path.
`c4j wt delete` and `c4j wt update` remain as compatibility aliases for the older naming.

```bash
c4j worktree
c4j worktree --dry-run
c4j wt for-feature1
c4j wt list
c4j wt prune
c4j wt move api api-v2
c4j worktree --repo ~/Workspaces/repos/bssm-oss/main/justn-hyeok/cmux4justn
c4j worktree --name api
```

### `c4j list [--plain]`

Prints active symlinks and their resolved targets as a table.

Use `--plain` or `--tsv` for script-friendly tab-separated output.

### `c4j delete [--dry-run|--apply] [--keep-cmux] <name-or-path>...`

Removes one or more active symlinks and closes the matching cmux workspace.

`delete` defaults to `--apply`. It never deletes the real project directory.

```bash
c4j delete cmux4justn
c4j delete .
c4j delete --dry-run cmux4justn
c4j delete --keep-cmux cmux4justn
```

Aliases:

- `remove`
- `rm`

## Maintenance And Advanced

These commands are useful for repair, bulk reconciliation, setup changes, and scripts. Most daily work should start with `go`, `cd`, `wt`, `list`, or `delete`.

### `c4j repair [--dry-run|--apply]`

Previews or applies a two-way reconciliation between the active registry and cmux. `reconcile` is an alias.

```bash
c4j repair
c4j repair --apply
c4j reconcile --dry-run
```

### `c4j add [--dry-run|--apply] <path>...`

Adds one or more directories to the active registry as symlinks, then runs `sync --direction both`.

With no path, `add` previews the two-way sync:

```bash
c4j add
c4j add --apply
```

### `c4j anchor [--dry-run|--apply] [--name <title>] [--cwd <path>]`

Ensures the pinned cmux anchor workspace exists. By default it uses:

- title: `justn-is-always-around-here`
- cwd: `~/Workspaces`
- color: `Teal`

```bash
c4j anchor
c4j anchor --dry-run
c4j anchor --name justn-is-always-around-here --cwd ~/Workspaces
```

### `c4j update [--dry-run|--apply] [--ref <ref>] [--repo-url <url>] [--install-dir <path>] [--allow-unsafe-source]`

Updates the installed `c4j` binary by fetching the latest tagged release from the source repository and reinstalling from that checkout.

By default it looks for the latest `v*` tag in `https://github.com/bssm-oss/cmux4justn.git` and reinstalls from `~/.local/share/c4j`.
Use `--ref` to pin a specific trusted `v*` tag and `--install-dir` to override the local source checkout path. Custom `--repo-url` values and non-`v*` refs require `--allow-unsafe-source`.

```bash
c4j update
c4j update --dry-run
c4j update --ref v0.13.17
c4j update --repo-url <url> --ref <ref> --allow-unsafe-source
```

Dry-run output includes the current CLI version, target ref, resolved target commit, and whether the local source checkout is already current.

### `c4j setup [--dry-run|--apply] [--active-dir <path>] [--name-prefix <prefix>]`

Initializes the config with the default `@active/` workspace prefix.

`setup` defaults to `--apply`. It writes `name_prefix=@active/` unless you pass a different `--name-prefix`, and it only writes `active_dir` when `--active-dir` is provided.

```bash
c4j setup
c4j setup --dry-run
c4j setup --active-dir ~/Workspaces/now
c4j setup --name-prefix @active/
```

### `c4j sync [--dry-run|--apply] [--direction active-to-cmux|cmux-to-active|both]`

Low-level sync command for scripts and advanced repair. For normal manual repair, use `c4j repair`.

- `active-to-cmux`: create missing cmux workspaces from active symlinks
- `cmux-to-active`: create missing active symlinks from cmux workspaces with the configured prefix
- `both`: run both directions

Default:

```bash
c4j sync --dry-run --direction active-to-cmux
```

Dry-run output ends with the exact `--apply` command to run when you want to make the planned changes.

### `c4j config get`

Prints the config file path and effective runtime settings.

### `c4j config set active-dir <path>`

Stores the default active registry in the config file. The path must already exist.

Aliases for the same setting:

- `workspace-dir`
- `workspace-file`

```bash
c4j config set active-dir ~/Workspaces/now
c4j config get
```

### `c4j config set name-prefix <prefix>`

Stores the prefix used for cmux workspace titles. The default is `@active/`.

```bash
c4j config set name-prefix "@active/"
c4j config set prefix "@active/"
c4j config get
```

Aliases for the same setting:

- `prefix`
- `workspace-prefix`

### `c4j config unset active-dir`

Removes the stored active registry setting and falls back to the default or environment variables.

### `c4j config unset name-prefix`

Removes the stored workspace title prefix and falls back to the default or environment variables.

### `c4j config path`

Prints the config file path.

### `c4j doctor`

Checks whether the active registry exists and whether a cmux executable is available.

### `c4j version`

Prints the CLI version.

## Installer Options

```bash
# Install a specific release.
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/v0.13.17/install.sh | C4J_REF=v0.13.17 bash -s -- --rc

# Install from main instead of the release pinned by the bootstrap script.
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/main/install.sh | C4J_REF=main bash -s -- --rc --allow-unsafe-source

# Download source somewhere else.
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/v0.13.17/install.sh | C4J_INSTALL_DIR="$HOME/src/c4j" bash -s -- --rc

# Preview all installer actions.
scripts/install.sh --dry-run

# Install to a custom bin directory.
scripts/install.sh --bin-dir "$HOME/.local/bin"

# Use a custom active registry.
scripts/install.sh --active-dir "$HOME/.c4j/active"

# Use a custom config file.
scripts/install.sh --config "$HOME/.c4j/config"

# Add alias and completion fallbacks to a shell rc file.
scripts/install.sh --rc --shell-rc "$HOME/.zshrc"

# Skip specific install steps.
scripts/install.sh --no-bin
scripts/install.sh --no-active-dir
scripts/install.sh --no-config
scripts/install.sh --no-rc
```

Environment overrides:

- `C4J_BIN_DIR`: default install directory for `c4j`
- `C4J_ACTIVE_DIR`: default active-project registry
- `C4J_CONFIG`: config file path
- `C4J_SHELL_RC`: shell rc file used by `--rc`
- `C4J_REPO_URL`: source remote used by `c4j update`
- `C4J_INSTALL_DIR`: local source checkout used by `c4j update`
- `C4J_UPDATE_REF`: optional ref override used by `c4j update`

## Runtime Defaults

- Active registry: `~/.c4j/active`
- Config file: `~/.c4j/config`
- cmux workspace prefix: `@active/`
- `add`: `--apply`, then `sync --direction both`
- `sync`: `--dry-run --direction active-to-cmux`

Runtime environment overrides:

- `C4J_ACTIVE_DIR`
- `C4J_CMUX_BIN`
- `C4J_NAME_PREFIX`
- `C4J_CONFIG`

Compatibility aliases remain available:

- `bin/cmux4justn`
- `CMUX4JUSTN_ACTIVE_DIR`
- `CMUX4JUSTN_CMUX_BIN`
- `CMUX4JUSTN_NAME_PREFIX`

## Optional launchd Sync

Automation is opt-in and dry-run by default.

```bash
# Print the plist without writing it.
scripts/launchd.sh print

# Write the plist without loading it.
scripts/launchd.sh install --apply

# Write and load the job.
scripts/launchd.sh install --apply --load

# Make the scheduled job apply changes instead of dry-running.
scripts/launchd.sh install --apply --load --sync-apply

# Unload and remove the job.
scripts/launchd.sh uninstall --apply --load
```

The default launchd label is `com.justn.c4j.sync`.

Test-safe overrides:

- `--active-dir`
- `--cmux`
- `--c4j`
- `--launch-agents-dir`
- `--launchctl`
- `--label`

## Safety Model

`c4j` is designed to avoid destructive workspace churn.

- It creates symlinks only when the target path exists.
- It refuses unsafe active names such as names containing `/` or `..`.
- It skips broken symlinks, duplicate targets, and conflicting existing paths.
- It requires cmux inventory to be readable before `--apply` sync creates workspaces.
- It only removes active symlinks or closes cmux workspaces when `c4j delete` is explicit.
- It never deletes real project directories.
- It does not overwrite existing executable installs that differ from the bundled CLI.
- Config values are plain `key=value` lines and are not shell-sourced.

## Development

Run the local test suite:

```bash
check_files=(bin/c4j bin/cmux4justn install.sh scripts/install.sh scripts/launchd.sh scripts/release.sh completions/c4j.bash)
while IFS= read -r test_file; do check_files+=("$test_file"); done < <(find lib -type f -name '*.bash' | sort)
while IFS= read -r test_file; do check_files+=("$test_file"); done < <(find test -type f \( -name '*.sh' -o -name '*.bash' \) | sort)
bash -n "${check_files[@]}"
for test_file in test/*.test.sh; do bash "$test_file"; done
```

Run shellcheck when available:

```bash
check_files=(bin/c4j bin/cmux4justn install.sh scripts/install.sh scripts/launchd.sh scripts/release.sh completions/c4j.bash)
while IFS= read -r test_file; do check_files+=("$test_file"); done < <(find lib -type f -name '*.bash' | sort)
while IFS= read -r test_file; do check_files+=("$test_file"); done < <(find test -type f \( -name '*.sh' -o -name '*.bash' \) | sort)
shellcheck -x "${check_files[@]}"
```

CI runs these checks on push and pull request.

## Release Checklist

Use the release script from a clean `main` checkout:

```bash
scripts/release.sh 0.13.4
```

Preview the sequence without changing files or remotes:

```bash
scripts/release.sh --dry-run 0.13.4
```

The script updates version references, runs local checks, commits, pushes `main`, waits for `main` CI, pushes the tag, waits for tag CI, and creates the GitHub Release. It fails before remote mutation when `gh` authentication or GitHub Actions visibility is unavailable.
