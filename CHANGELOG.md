# Changelog

## v0.13.18 - 2026-06-25

### Changed

- Prepared v0.13.18 release.

## v0.13.17 - 2026-06-25

### Changed

- Prepared v0.13.17 release.

## v0.13.16 - 2026-06-25

### Changed

- Prepared v0.13.16 release.

## v0.13.15 - 2026-06-23

### Added

- Added `lib/c4j-worktree.bash` for worktree scope, target, list, render, and destination helpers.

### Changed

- Routed worktree commands through extracted helper functions when available while preserving standalone CLI fallback behavior.

## v0.13.14 - 2026-06-23

### Added

- Added `lib/c4j-cmux-active.bash` for cmux inventory, workspace lookup, active-name resolution, and prefix helpers.

### Changed

- Routed cmux/active helper calls through the extracted library when available while keeping standalone CLI fallback behavior.

## v0.13.13 - 2026-06-23

### Added

- Added `lib/c4j-config.bash` and `lib/c4j-output.bash` for config and TSV helper extraction.

### Changed

- Routed config/setup/doctor TSV output through the shared output helper while preserving public output.

## v0.13.12 - 2026-06-23

### Added

- Added `lib/c4j-contract.bash` for shared command, help topic, worktree subcommand, and action row names.

### Changed

- Updated completion, installer wrapper generation, and tests to consume the shared contract.

## v0.13.11 - 2026-06-23

### Added

- Added separate workflow tests for worktrees, installer wrappers, bootstrap/update, and launchd.

### Changed

- Kept the full legacy suite as parity coverage while exposing workflow failures through narrower test files.

## v0.13.10 - 2026-06-23

### Added

- Added shared test helpers under `test/lib/`.
- Added a separate help/go/cd smoke test while keeping the full suite for parity.

### Changed

- Updated CI and release checks to syntax-check, ShellCheck, and run all `test/*.test.sh` files.

## v0.13.9 - 2026-06-23

### Added

- Added `c4j repair` / `c4j reconcile` as a human-oriented two-way c4j/cmux reconciliation surface.

### Changed

- Moved `sync --direction ...` positioning toward script and advanced repair documentation while keeping compatibility.

## v0.13.8 - 2026-06-23

### Changed

- Reworked README and Korean README install examples around the `--rc` shell wrapper happy path.
- Simplified Quick Start around daily commands: `go`, `cd`, `wt`, `list`, and `delete`.
- Moved `add`, `sync`, `anchor`, `setup`, and `config` guidance into maintenance/advanced documentation.

## v0.13.7 - 2026-06-23

### Changed

- Added update dry-run observability: current version, target ref, target commit, and already-current status.

## v0.13.6 - 2026-06-23

### Changed

- Required `--allow-unsafe-source` for bootstrap/update flows that use custom repo URLs or non-`v*` refs.
- Kept default install/update on the trusted `v*` tag path.

## v0.13.5 - 2026-06-23

### Fixed

- Made bootstrap `install.sh --dry-run` avoid fetch, checkout, directory creation, and installer execution.
- Made bootstrap/update refuse dirty install source checkouts with a recovery-oriented error.

## v0.13.4 - 2026-06-23

### Changed

- Made CI require ShellCheck instead of skipping it when unavailable.
- Added `completions/c4j.bash` to CI syntax and ShellCheck coverage.
- Added CI `git diff --check`, macOS launchd plist linting, and fresh zsh wrapper smoke coverage.

## v0.13.3 - 2026-06-23

### Added

- Added `scripts/release.sh` as the canonical patch release path for version refs, local gates, `main` CI, tag CI, and GitHub Release creation.
- Added a release dry-run regression test so the automation can be exercised without GitHub credentials.

### Fixed

- Made fresh zsh completion sourcing initialize zsh completion before `bashcompinit`, avoiding `compdef` warnings in wrapper smoke tests.

## v0.13.2 - 2026-06-23

### Fixed

- Kept `c4j wt --dry-run` from creating the managed worktree base directory.
- Made `c4j wt delete` refuse dirty or untracked worktrees unless `--force` or `--discard` is passed.
- Changed no-argument `c4j add` to run a dry-run two-way sync by default; use `c4j add --apply` to change state.
- Updated install bootstrap references, docs, completion, and regression tests for the safety hotfix.

## v0.13.1 - 2026-06-23

### Fixed

- Fixed release/update tests so version fixture rewrites follow the current `VERSION` file instead of stale release literals.
- Fixed bootstrap install tests so tag checkouts do not depend on an existing local `main` branch.
- Updated install bootstrap references and release URLs to `v0.13.1`.

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
