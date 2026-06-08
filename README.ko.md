# c4j

[English README](README.md)

`c4j`는 active project symlink와 cmux 워크스페이스를 동기화하는 macOS shell CLI입니다.

cmux 사용자가 프로젝트 추가, active 목록 확인, workspace title 동기화, `~/Workspaces` pinned anchor workspace 관리를 작은 CLI 하나로 처리할 수 있게 합니다.

`c4j`는 프로젝트 파일을 옮기지 않고, active registry에 symlink만 만들고, 필요한 cmux 워크스페이스만 생성합니다. 기본 동작은 보수적입니다. `c4j delete`를 명시적으로 실행할 때만 active symlink를 제거하거나 cmux 워크스페이스를 닫습니다.

## 기능

- plain Bash script 기반 한 줄 macOS 설치
- `~/.c4j/active` symlink 기반 active project registry
- `@active/` 같은 configurable title prefix로 cmux workspace sync
- `c4j anchor`를 통한 pinned cmux anchor workspace 관리
- 안전한 기본값: dry-run sync, 명시적 apply, 실제 프로젝트 디렉터리 삭제 없음

## 설치

```bash
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/v0.10.1/install.sh | bash
```

설치 스크립트는 기본적으로 다음 작업을 합니다.

- source를 `~/.local/share/c4j`에 다운로드
- `~/.local/bin/c4j`에 실행 파일 설치
- `~/.c4j/active` active registry 생성
- active registry 경로를 `~/.c4j/config`에 저장
- `--rc` 옵션이 없으면 shell rc 파일은 수정하지 않음

`~/.local/bin`이 `PATH`에 없으면 설치 스크립트가 shell rc에 추가할 `export` 줄을 출력합니다. 그 뒤 설정 상태를 확인합니다.

```bash
c4j doctor
```

## 빠른 시작

```bash
# 프로젝트를 active registry에 추가하고 cmux와 동기화합니다.
c4j add ~/Workspaces/repos/justn-hyeok/cmux4justn

# pinned cmux anchor workspace를 보장합니다.
c4j anchor

# 기본 @active/ prefix를 설정합니다. 필요하면 active registry 경로도 같이 넣습니다.
c4j setup --active-dir ~/Workspaces/now

# 프로젝트를 active registry에서 제거하고 cmux 워크스페이스도 닫습니다.
c4j delete cmux4justn

# active 프로젝트 목록을 봅니다.
c4j list

# 기본 active registry를 바꿉니다.
c4j config set active-dir ~/Workspaces/now

# cmux 워크스페이스 title prefix를 바꿉니다.
c4j config set name-prefix "@active/"

# 양방향 동기화를 미리 확인합니다.
c4j sync --direction both --dry-run

# 양방향 동기화를 실제 적용합니다.
c4j sync --direction both --apply
```

## 명령어

### `c4j add [--dry-run|--apply] <path>...`

하나 이상의 디렉터리를 active registry에 symlink로 추가한 뒤 `sync --direction both`를 실행합니다.

경로 없이 실행하면 새 프로젝트를 추가하지 않고 양방향 동기화만 실행합니다.

```bash
c4j add
```

### `c4j anchor [--dry-run|--apply] [--name <title>] [--cwd <path>]`

pinned cmux anchor workspace가 존재하도록 보장합니다. 기본값은 다음과 같습니다.

- title: `justn-is-always-around-here`
- cwd: `~/Workspaces`
- color: `Teal`

```bash
c4j anchor
c4j anchor --dry-run
c4j anchor --name justn-is-always-around-here --cwd ~/Workspaces
```

### `c4j delete [--dry-run|--apply] [--keep-cmux] <name-or-path>...`

하나 이상의 active symlink를 제거하고 대응되는 cmux 워크스페이스를 닫습니다.

`delete`는 기본값이 `--apply`입니다. 실제 프로젝트 디렉터리는 절대 삭제하지 않습니다.

```bash
c4j delete cmux4justn
c4j delete .
c4j delete --dry-run cmux4justn
c4j delete --keep-cmux cmux4justn
```

alias:

- `remove`
- `rm`

### `c4j setup [--dry-run|--apply] [--active-dir <path>] [--name-prefix <prefix>]`

기본 `@active/` workspace prefix를 설정합니다.

`setup`의 기본값은 `--apply`입니다. `--name-prefix`를 따로 주지 않으면 `name_prefix=@active/`를 저장하고, `--active-dir`를 넘겼을 때만 `active_dir`도 저장합니다.

```bash
c4j setup
c4j setup --dry-run
c4j setup --active-dir ~/Workspaces/now
c4j setup --name-prefix @active/
```

### `c4j sync [--dry-run|--apply] [--direction active-to-cmux|cmux-to-active|both]`

active registry와 cmux 워크스페이스 목록을 동기화합니다.

- `active-to-cmux`: active symlink를 기준으로 없는 cmux 워크스페이스 생성
- `cmux-to-active`: configured prefix가 붙은 cmux 워크스페이스를 기준으로 없는 active symlink 생성
- `both`: 양방향 실행

기본값:

```bash
c4j sync --dry-run --direction active-to-cmux
```

dry-run 출력 마지막에는 실제 반영할 때 실행할 정확한 `--apply` 명령이 표시됩니다.

### `c4j list [--plain]`

active symlink와 실제 target 경로를 표로 출력합니다.

script에서 쓰기 쉬운 tab-separated 출력이 필요하면 `--plain` 또는 `--tsv`를 사용합니다.

### `c4j config get`

config 파일 경로와 실제 적용되는 런타임 설정을 출력합니다.

### `c4j config set active-dir <path>`

기본 active registry를 config 파일에 저장합니다. 경로는 이미 존재해야 합니다.

같은 설정을 가리키는 alias:

- `workspace-dir`
- `workspace-file`

```bash
c4j config set active-dir ~/Workspaces/now
c4j config get
```

### `c4j config set name-prefix <prefix>`

cmux 워크스페이스 title에 붙일 prefix를 config 파일에 저장합니다. 기본값은 `@active/`입니다.

```bash
c4j config set name-prefix "@active/"
c4j config set prefix "@active/"
c4j config get
```

같은 설정을 가리키는 alias:

- `prefix`
- `workspace-prefix`

### `c4j config unset active-dir`

저장된 active registry 설정을 제거하고 기본값 또는 환경 변수 설정으로 돌아갑니다.

### `c4j config unset name-prefix`

저장된 workspace title prefix 설정을 제거하고 기본값 또는 환경 변수 설정으로 돌아갑니다.

### `c4j config path`

config 파일 경로를 출력합니다.

### `c4j doctor`

active registry가 있는지, cmux 실행 파일을 찾을 수 있는지 확인합니다.

### `c4j version`

CLI 버전을 출력합니다.

## 설치 옵션

```bash
# 특정 릴리즈를 설치합니다.
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/v0.10.1/install.sh | C4J_REF=v0.10.1 bash

# bootstrap script에 고정된 릴리즈 대신 main에서 설치합니다.
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/main/install.sh | C4J_REF=main bash

# source 다운로드 위치를 바꿉니다.
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/v0.10.1/install.sh | C4J_INSTALL_DIR="$HOME/src/c4j" bash

# 설치 작업을 미리 확인합니다.
scripts/install.sh --dry-run

# 다른 bin 디렉터리에 설치합니다.
scripts/install.sh --bin-dir "$HOME/.local/bin"

# 다른 active registry를 사용합니다.
scripts/install.sh --active-dir "$HOME/.c4j/active"

# 다른 config 파일을 사용합니다.
scripts/install.sh --config "$HOME/.c4j/config"

# shell rc 파일에 alias와 completion fallback을 추가합니다.
scripts/install.sh --rc --shell-rc "$HOME/.zshrc"

# 특정 설치 단계를 건너뜁니다.
scripts/install.sh --no-bin
scripts/install.sh --no-active-dir
scripts/install.sh --no-config
scripts/install.sh --no-rc
```

설치 환경 변수:

- `C4J_BIN_DIR`: `c4j` 기본 설치 디렉터리
- `C4J_ACTIVE_DIR`: 기본 active registry 경로
- `C4J_CONFIG`: config 파일 경로
- `C4J_SHELL_RC`: `--rc`가 사용할 shell rc 파일

## 런타임 기본값

- Active registry: `~/.c4j/active`
- Config file: `~/.c4j/config`
- cmux 워크스페이스 prefix: `@active/`
- `add`: `--apply` 후 `sync --direction both`
- `sync`: `--dry-run --direction active-to-cmux`

런타임 환경 변수:

- `C4J_ACTIVE_DIR`
- `C4J_CMUX_BIN`
- `C4J_NAME_PREFIX`
- `C4J_CONFIG`

호환성 alias도 유지됩니다.

- `bin/cmux4justn`
- `CMUX4JUSTN_ACTIVE_DIR`
- `CMUX4JUSTN_CMUX_BIN`
- `CMUX4JUSTN_NAME_PREFIX`

## 선택 사항: launchd 자동 동기화

자동화는 opt-in이며 기본적으로 dry-run입니다.

```bash
# plist를 출력만 하고 파일은 쓰지 않습니다.
scripts/launchd.sh print

# plist를 쓰지만 load하지는 않습니다.
scripts/launchd.sh install --apply

# plist를 쓰고 launchd에 load합니다.
scripts/launchd.sh install --apply --load

# scheduled job이 dry-run이 아니라 실제 적용하도록 합니다.
scripts/launchd.sh install --apply --load --sync-apply

# unload 후 plist를 제거합니다.
scripts/launchd.sh uninstall --apply --load
```

기본 launchd label은 `com.justn.c4j.sync`입니다.

테스트용 override:

- `--active-dir`
- `--cmux`
- `--c4j`
- `--launch-agents-dir`
- `--launchctl`
- `--label`

## 안전 모델

`c4j`는 워크스페이스 상태를 망가뜨리지 않는 쪽으로 설계되어 있습니다.

- target path가 존재할 때만 symlink를 만듭니다.
- `/` 또는 `..`가 포함된 unsafe active name은 거부합니다.
- broken symlink, duplicate target, 충돌하는 기존 path는 건너뜁니다.
- `--apply` sync로 워크스페이스를 만들기 전에 cmux inventory를 읽을 수 있어야 합니다.
- 명시적으로 `c4j delete`를 실행할 때만 active symlink를 제거하거나 cmux 워크스페이스를 닫습니다.
- 실제 프로젝트 디렉터리는 절대 삭제하지 않습니다.
- 설치 대상 실행 파일이 기존 파일과 다르면 덮어쓰지 않습니다.
- config 값은 단순한 `key=value` 줄이며 shell source하지 않습니다.

## 개발

로컬 테스트:

```bash
bash -n bin/c4j bin/cmux4justn install.sh scripts/install.sh scripts/launchd.sh test/cmux4justn.test.sh
bash test/cmux4justn.test.sh
```

`shellcheck`가 있으면 함께 실행합니다.

```bash
shellcheck bin/c4j bin/cmux4justn install.sh scripts/install.sh scripts/launchd.sh test/cmux4justn.test.sh
```

CI는 push와 pull request에서 이 검사를 실행합니다.

## 릴리즈 체크리스트

1. `VERSION`과 `bin/cmux4justn`의 version string을 업데이트합니다.
2. `CHANGELOG.md`를 업데이트합니다.
3. syntax check, test, shellcheck, `git diff --check`를 실행합니다.
4. `main`에 commit/push합니다.
5. release tag를 만들고 push한 뒤 GitHub Release를 생성합니다.
