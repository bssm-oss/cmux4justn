# cmux4justn

Tiny personal CLI for syncing an `@active` symlink folder with cmux workspaces.

`@active` is a lightweight registry of projects you are actively touching. `cmux4justn` keeps that registry and cmux workspaces in sync without moving real project files.

## Install

```bash
scripts/install.sh
```

This adds a `c4j` alias to `~/.zshrc`. Open a new shell or run `source ~/.zshrc` before using the alias:

```bash
c4j doctor
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

v0.1.1 only creates missing symlinks or missing cmux workspaces. It does not delete, close, overwrite, rename, or retarget anything.

## Known Limits

- Automatic hourly/background sync is intentionally not enabled.
- Reverse sync requires `cmux --json list-workspaces` plus either `python3` or `jq` for JSON parsing.
- If cmux inventory cannot be read during `--apply`, the command fails instead of guessing.
