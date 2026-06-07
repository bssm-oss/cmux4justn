# Changelog

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
