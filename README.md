# c4j

[한국어 README](README.ko.md)

`c4j` is a macOS shell CLI for keeping active project symlinks and cmux workspaces in sync.

It gives cmux users a small workspace manager for adding projects, listing active work, syncing workspace titles, importing legacy `now-i-work-in-*` workspaces, and keeping a pinned anchor workspace at `~/Workspaces`.

`c4j` is intentionally conservative: it creates missing symlinks and missing cmux workspaces, and only removes active symlinks or closes cmux workspaces when `c4j delete` is explicit.

## Features

- One-line macOS install with a plain Bash script.
- Active project registry backed by symlinks in `~/.c4j/active`.
- cmux workspace sync with configurable title prefixes such as `@active/` or `now-i-work-in-`.
- Legacy `now-i-work-in-*` import for existing cmux workspace setups.
- Pinned cmux anchor workspace support through `c4j anchor`.
- Safe defaults: dry-run sync, explicit apply, and no real project directory deletion.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/v0.10.0/install.sh | bash
```

The installer:

- downloads the source into `~/.local/share/c4j`
- installs `c4j` into `~/.local/bin/c4j`
- creates the active-project registry at `~/.c4j/active`
- writes the active registry path to `~/.c4j/config`
- leaves shell rc files alone unless `--rc` is passed

If `~/.local/bin` is not on `PATH`, the installer prints the exact export line to add to your shell rc. Then check the setup:

```bash
c4j doctor
```

## Quick Start

```bash
# Add a project and sync cmux.
c4j add ~/Workspaces/repos/justn-hyeok/cmux4justn

# Ensure the pinned cmux anchor workspace exists.
c4j anchor

# Remove a project from the active registry and close its cmux workspace.
c4j delete cmux4justn

# Import legacy now-i-work-in-* cmux workspaces.
c4j import-now --apply

# List active projects.
c4j list

# Change the default active registry.
c4j config set active-dir ~/Workspaces/now

# Change the cmux workspace title prefix.
c4j config set name-prefix "now-i-work-in-"

# Preview a full two-way sync.
c4j sync --direction both --dry-run

# Apply a full two-way sync.
c4j sync --direction both --apply
```

## Commands

### `c4j add [--dry-run|--apply] <path>...`

Adds one or more directories to the active registry as symlinks, then runs `sync --direction both`.

With no path, `add` only runs the two-way sync:

```bash
c4j add
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

### `c4j import-now [--dry-run|--apply]`

Imports legacy cmux workspaces named `now-i-work-in-*` into the active registry.

`import-now` defaults to `--dry-run`. It creates active symlinks only; it does not rename or close existing cmux workspaces.

```bash
c4j import-now
c4j import-now --apply
c4j import-now --legacy-prefix now-i-work-in-
```

### `c4j sync [--dry-run|--apply] [--direction active-to-cmux|cmux-to-active|both]`

Synchronizes the active registry and cmux workspace list.

- `active-to-cmux`: create missing cmux workspaces from active symlinks
- `cmux-to-active`: create missing active symlinks from cmux workspaces with the configured prefix
- `both`: run both directions

Default:

```bash
c4j sync --dry-run --direction active-to-cmux
```

Dry-run output ends with the exact `--apply` command to run when you want to make the planned changes.

### `c4j list [--plain]`

Prints active symlinks and their resolved targets as a table.

Use `--plain` or `--tsv` for script-friendly tab-separated output.

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
c4j config set name-prefix "now-i-work-in-"
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
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/v0.10.0/install.sh | C4J_REF=v0.10.0 bash

# Install from main instead of the release pinned by the bootstrap script.
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/main/install.sh | C4J_REF=main bash

# Download source somewhere else.
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/v0.10.0/install.sh | C4J_INSTALL_DIR="$HOME/src/c4j" bash

# Preview all installer actions.
scripts/install.sh --dry-run

# Install to a custom bin directory.
scripts/install.sh --bin-dir "$HOME/.local/bin"

# Use a custom active registry.
scripts/install.sh --active-dir "$HOME/.c4j/active"

# Use a custom config file.
scripts/install.sh --config "$HOME/.c4j/config"

# Add an alias fallback to a shell rc file.
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
bash -n bin/c4j bin/cmux4justn install.sh scripts/install.sh scripts/launchd.sh test/cmux4justn.test.sh
bash test/cmux4justn.test.sh
```

Run shellcheck when available:

```bash
shellcheck bin/c4j bin/cmux4justn install.sh scripts/install.sh scripts/launchd.sh test/cmux4justn.test.sh
```

CI runs these checks on push and pull request.

## Release Checklist

1. Update `VERSION` and the version string in `bin/cmux4justn`.
2. Update `CHANGELOG.md`.
3. Run syntax checks, tests, shellcheck, and `git diff --check`.
4. Commit and push `main`.
5. Tag the release, push the tag, and create a GitHub Release.
