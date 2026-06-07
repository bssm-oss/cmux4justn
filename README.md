# c4j

Tiny personal CLI for syncing an active-project symlink folder with cmux workspaces.

`~/.c4j/active` is a lightweight registry of projects you are actively touching. `c4j` keeps that registry and cmux workspaces in sync without moving real project files.

## Install

```bash
scripts/install.sh
```

This installs `c4j` into `~/.local/bin` by default. Make sure `~/.local/bin` is on `PATH`, then run:

```bash
c4j doctor
```

Installer options:

```bash
# install an executable copy into a custom bin dir
scripts/install.sh --bin-dir "$HOME/.local/bin"

# use a different active-project registry
scripts/install.sh --active-dir "$HOME/.c4j/active"

# add an alias fallback to a shell rc file
scripts/install.sh --rc --shell-rc "$HOME/.zshrc"

# preview all changes safely
scripts/install.sh --dry-run --shell-rc /tmp/cmux4justn.rc --bin-dir /tmp/cmux4justn-bin
```

## Usage

Add a project to the active registry and sync cmux:

```bash
c4j add /path/to/project
```

Sync without adding a path:

```bash
c4j add
```

Preview sync:

```bash
c4j sync --direction both --dry-run
```

Apply sync:

```bash
c4j sync --direction both --apply
```

List active projects:

```bash
c4j list
```

Check setup:

```bash
c4j doctor
```

## Defaults

- Active dir: `~/.c4j/active`
- cmux workspace prefix: `@active/`
- `sync` default: `--dry-run --direction active-to-cmux`
- `add` default: `--apply`, then `sync --direction both`

## Safety

v0.2.0 only creates missing symlinks or missing cmux workspaces. It does not delete, close, overwrite, rename, or retarget anything.

## Safe Smoke Test

This checks a fresh clone without touching your real active registry, cmux workspace list, or shell rc file:

```bash
tmp=$(mktemp -d)
git clone https://github.com/bssm-oss/cmux4justn "$tmp/c4j"
cd "$tmp/c4j"
bin/c4j version
scripts/install.sh --dry-run
test/cmux4justn.test.sh
```

`bin/cmux4justn` remains as a compatibility entrypoint.

This is CI-safe and mirrors what the GitHub Actions workflow validates.

## Optional launchd hourly sync

Automation is opt-in and intentionally conservative.

```bash
# preview the launchd job plist (no writes)
scripts/launchd.sh print

# write plist only (still not loaded/running)
scripts/launchd.sh install --apply

# write and load (enables scheduled runs)
scripts/launchd.sh install --apply --load

# default scheduled command uses --dry-run; require explicit apply mode
scripts/launchd.sh install --apply --load --sync-apply

# unload and remove
scripts/launchd.sh uninstall --apply --load
```

Test-safe overrides are available for scripted environments: `--active-dir`, `--cmux`, `--launch-agents-dir`, and `--launchctl`.

## Known Limits

- Automatic hourly/background sync is intentionally not enabled.
- Reverse sync requires `cmux --json list-workspaces` plus either `python3` or `jq` for JSON parsing.
- If cmux inventory cannot be read during `--apply`, the command fails instead of guessing.
