# c4j

[한국어 README](README.ko.md)

`c4j` is a small shell CLI that keeps an active-project symlink registry and cmux workspaces in sync.

It is intentionally conservative: it creates missing symlinks and missing cmux workspaces, but it does not delete, close, overwrite, rename, or retarget existing work.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/main/install.sh | bash
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

# List active projects.
c4j list

# Change the default active registry.
c4j config set active-dir ~/Workspaces/now

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

### `c4j sync [--dry-run|--apply] [--direction active-to-cmux|cmux-to-active|both]`

Synchronizes the active registry and cmux workspace list.

- `active-to-cmux`: create missing cmux workspaces from active symlinks
- `cmux-to-active`: create missing active symlinks from cmux workspaces with the configured prefix
- `both`: run both directions

Default:

```bash
c4j sync --dry-run --direction active-to-cmux
```

### `c4j list`

Prints active symlinks and their resolved targets.

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

### `c4j config unset active-dir`

Removes the stored active registry setting and falls back to the default or environment variables.

### `c4j config path`

Prints the config file path.

### `c4j doctor`

Checks whether the active registry exists and whether a cmux executable is available.

### `c4j version`

Prints the CLI version.

## Installer Options

```bash
# Install a specific release.
C4J_REF=v0.4.0 curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/main/install.sh | bash

# Download source somewhere else.
C4J_INSTALL_DIR="$HOME/src/c4j" curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/main/install.sh | bash

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
- It does not remove active symlinks.
- It does not close cmux workspaces.
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
