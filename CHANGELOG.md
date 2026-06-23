# Changelog

## v0.13.0 - 2026-06-23

### Added

- Added `c4j cd <project-or-folder>` for quiet shell-directory jumps through the installed shell wrapper.
- Added active project completion support for `c4j cd`.

### Fixed

- Hardened shell rc updates to avoid truncating user rc files when c4j markers are malformed.
- Hardened launchd label handling and plist writes.
- Fixed completion gaps for `config unset cmux-bin`, `sync --cmux`, and worktree help aliases.
- Improved config validation and worktree move argument validation.
- Made update tests use portable in-place `sed`.

## v0.12.0 - 2026-06-10

### Added

- Added `c4j wt list`, `c4j wt delete`, and `c4j wt update` for browsing and managing worktrees.
- Added cmux-aware worktree listing so `c4j wt list` scopes to the current workspace when available, and falls back to the full managed worktree set otherwise.

### Changed

- Updated the installed shell wrapper and completion flow so successful `c4j wt ...` still cd's into the created or reused worktree.
- Updated install bootstrap references and release URLs to `v0.12.0`.

## v0.11.2 - 2026-06-10

### Fixed

- Made the installed shell wrapper change into the created or reused worktree after `c4j wt ...`.

## v0.11.1 - 2026-06-10

### Fixed

- Made `c4j worktree` fall back to the current cmux workspace's repo when the current directory is not a git repo.

## v0.11.0 - 2026-06-10

### Added

- Added `c4j worktree` for creating a git worktree from the current repo with a short `wt` alias.
- Added shorthand positional naming so `c4j wt for-feature1` creates a worktree named `for-feature1`.

### Changed

- Updated install bootstrap references and release URLs to `v0.11.0`.

## v0.10.1 - 2026-06-08

### Added

- Added `c4j setup` for quickly initializing the default `@active/` workspace prefix.
- Added shell completion for directory arguments and core command flags.

### Changed

- Removed the `import-now` command and folded reverse import behavior into `sync --direction cmux-to-active`.
- Updated install and release references to the `v0.10.1` hotfix.

## v0.10.0 - 2026-06-08

### Added

- Added `c4j anchor` to ensure the pinned cmux anchor workspace exists and is styled.

## v0.9.0 - 2026-06-08

### Changed

- Added dry-run apply hints to `sync` and `delete` output.

## v0.8.0 - 2026-06-08

### Changed

- Changed `c4j list` to render a sorted table by default.
- Added `c4j list --plain` and `--tsv` for script-friendly tab-separated output.

## v0.7.0 - 2026-06-08

### Changed

- Documented and tested persistent `name-prefix` configuration for cmux workspace titles.
- Added `prefix` and `workspace-prefix` aliases for the same config field.

## v0.6.0 - 2026-06-08

### Added

- Added cmux-to-active sync for importing configured workspace prefixes.

## v0.5.0 - 2026-06-08

### Added

- Added `c4j delete` for removing active symlinks and closing matching cmux workspaces.
- Added `c4j remove` and `c4j rm` aliases.
- Added `--keep-cmux` for registry-only deletes.

## v0.4.3 - 2026-06-08

### Fixed

- Made bootstrap source downloads quieter by avoiding git's annotated-tag and detached-HEAD installer noise.

## v0.4.2 - 2026-06-08

### Fixed

- Pinned the bootstrap install command to a release tag so downloads are not affected by moving `main` or raw URL propagation.
- Corrected installer option examples so pipeline environment variables apply to `bash`, not `curl`.

## v0.4.1 - 2026-06-08

### Fixed

- Suppressed the `BASH_SOURCE[0]` warning when running the bootstrap installer through `curl | bash`.

## v0.4.0 - 2026-06-08

### Added

- Added a root `install.sh` bootstrapper for one-line `curl | bash` installs.
- Documented `C4J_REF` and `C4J_INSTALL_DIR` for release pinning and custom source locations.

## v0.3.0 - 2026-06-08

### Added

- Added `c4j config get`, `set`, `unset`, and `path` commands.
- Added persistent config support via `~/.c4j/config`.
- Added `C4J_CONFIG` to override the config file path.
- Added `workspace-dir` and `workspace-file` aliases for the `active-dir` setting.

### Changed

- Installer now writes the selected active registry to the config file.
- `doctor` now reports config file status.
- README and Korean README now document persistent workspace/active registry configuration.

### Verification

- `bash -n bin/c4j bin/cmux4justn scripts/install.sh scripts/launchd.sh test/cmux4justn.test.sh`
- `bash test/cmux4justn.test.sh`
- `shellcheck bin/c4j bin/cmux4justn scripts/install.sh scripts/launchd.sh test/cmux4justn.test.sh`
- Fresh config set/get/unset test with temporary `HOME`

## v0.2.1 - 2026-06-08

### Changed

- Improved installer UX with a final setup summary and explicit next steps.
- Added a PATH notice when the install directory is not available in the current shell.
- Updated English and Korean README install guidance to match the installer output.

### Verification

- `bash -n bin/c4j bin/cmux4justn scripts/install.sh scripts/launchd.sh test/cmux4justn.test.sh`
- `bash test/cmux4justn.test.sh`
- `shellcheck bin/c4j bin/cmux4justn scripts/install.sh scripts/launchd.sh test/cmux4justn.test.sh`
- Fresh temporary HOME install with and without `~/.local/bin` on `PATH`

## v0.2.0 - 2026-06-08

### Added

- Added `bin/c4j` as the official CLI entrypoint.
- Added a safer installer flow that installs `c4j` into `~/.local/bin` by default.
- Added automatic creation of the active-project registry at `~/.c4j/active`.
- Added `C4J_*` environment variables for install and runtime configuration.
- Added launchd support under the `com.justn.c4j.sync` label.

### Changed

- Rebranded the user-facing command and documentation from `cmux4justn` to `c4j`.
- Changed the default active registry from `~/Workspaces/@active` to `~/.c4j/active`.
- Made shell rc edits opt-in via `scripts/install.sh --rc`.
- Updated CI, tests, and docs to validate the new `c4j` entrypoint.

### Compatibility

- Kept `bin/cmux4justn` as a compatibility entrypoint.
- Kept `CMUX4JUSTN_*` runtime environment variables as compatibility aliases.

### Verification

- `bash -n bin/c4j bin/cmux4justn scripts/install.sh scripts/launchd.sh test/cmux4justn.test.sh`
- `bash test/cmux4justn.test.sh`
- `shellcheck bin/c4j bin/cmux4justn scripts/install.sh scripts/launchd.sh test/cmux4justn.test.sh`
- `git diff --check`

## v0.1.3 - 2026-05-18

### Changed

- Fixed installer idempotency for existing quoted `c4j` aliases from earlier installs.
- Kept v0.1.2 CI, installer option, and launchd hardening changes.
