# Changelog

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
