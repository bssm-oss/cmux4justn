# cmux4justn

Tiny personal CLI for syncing an `@active` symlink folder with cmux workspaces.

`@active` is a lightweight registry of projects you are actively touching. `cmux4justn` keeps that registry and cmux workspaces in sync without moving real project files.

## Install

```bash
scripts/install.sh
```

This adds a `c4j` alias to `~/.zshrc` by default. Open a new shell or run `source ~/.zshrc` before using the alias:

```bash
c4j doctor
```

Installer options:

```bash
# target a different shell rc file
scripts/install.sh --shell-rc /path/to/.zshrc

# install an executable copy into a custom bin dir
scripts/install.sh --bin-dir "$HOME/.local/bin"

# install binary copy without editing shell rc
scripts/install.sh --bin-dir "$HOME/.local/bin" --no-rc

# preview all changes safely
scripts/install.sh --dry-run --shell-rc /tmp/cmux4justn.rc --bin-dir /tmp/cmux4justn-bin
```

## Usage

Add a project to `@active` and sync cmux:

```bash
cmux4justn add /path/to/project
```

Sync without adding a path:

```bash
cmux4justn add
```

Preview sync:

```bash
cmux4justn sync --direction both --dry-run
```

Apply sync:

```bash
cmux4justn sync --direction both --apply
```

List active projects:

```bash
cmux4justn list
```

Check setup:

```bash
cmux4justn doctor
```

## Defaults

- Active dir: `/Users/justn/Workspaces/@active`
- cmux workspace prefix: `@active/`
- `sync` default: `--dry-run --direction active-to-cmux`
- `add` default: `--apply`, then `sync --direction both`

## Safety

v0.1.3 only creates missing symlinks or missing cmux workspaces. It does not delete, close, overwrite, rename, or retarget anything.

## Safe Smoke Test

This checks a fresh clone without touching your real `@active`, cmux workspace list, or shell rc file:

```bash
tmp=$(mktemp -d)
git clone https://github.com/bssm-oss/cmux4justn "$tmp/cmux4justn"
cd "$tmp/cmux4justn"
bin/cmux4justn version
scripts/install.sh --dry-run
test/cmux4justn.test.sh
```

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
