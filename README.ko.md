# c4j

[English README](README.md)

`c4j`는 지금 작업 중인 프로젝트 목록과 cmux 워크스페이스를 맞춰 주는 작은 shell CLI입니다.

프로젝트 파일을 옮기지 않고, active registry에 symlink만 만들고, 필요한 cmux 워크스페이스만 생성합니다. 기본 동작은 보수적입니다. 기존 symlink나 워크스페이스를 삭제하거나, 닫거나, 덮어쓰거나, 다른 경로로 바꾸지 않습니다.

## 설치

```bash
git clone https://github.com/bssm-oss/cmux4justn ~/.local/share/c4j
cd ~/.local/share/c4j
scripts/install.sh
```

설치 스크립트는 기본적으로 다음 작업을 합니다.

- `~/.local/bin/c4j`에 실행 파일 설치
- `~/.c4j/active` active registry 생성
- `--rc` 옵션이 없으면 shell rc 파일은 수정하지 않음

`~/.local/bin`이 `PATH`에 없으면 설치 스크립트가 shell rc에 추가할 `export` 줄을 출력합니다. 그 뒤 설정 상태를 확인합니다.

```bash
c4j doctor
```

## 빠른 시작

```bash
# 프로젝트를 active registry에 추가하고 cmux와 동기화합니다.
c4j add ~/Workspaces/repos/justn-hyeok/cmux4justn

# active 프로젝트 목록을 봅니다.
c4j list

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

### `c4j sync [--dry-run|--apply] [--direction active-to-cmux|cmux-to-active|both]`

active registry와 cmux 워크스페이스 목록을 동기화합니다.

- `active-to-cmux`: active symlink를 기준으로 없는 cmux 워크스페이스 생성
- `cmux-to-active`: configured prefix가 붙은 cmux 워크스페이스를 기준으로 없는 active symlink 생성
- `both`: 양방향 실행

기본값:

```bash
c4j sync --dry-run --direction active-to-cmux
```

### `c4j list`

active symlink와 실제 target 경로를 출력합니다.

### `c4j doctor`

active registry가 있는지, cmux 실행 파일을 찾을 수 있는지 확인합니다.

### `c4j version`

CLI 버전을 출력합니다.

## 설치 옵션

```bash
# 설치 작업을 미리 확인합니다.
scripts/install.sh --dry-run

# 다른 bin 디렉터리에 설치합니다.
scripts/install.sh --bin-dir "$HOME/.local/bin"

# 다른 active registry를 사용합니다.
scripts/install.sh --active-dir "$HOME/.c4j/active"

# shell rc 파일에 alias fallback을 추가합니다.
scripts/install.sh --rc --shell-rc "$HOME/.zshrc"

# 특정 설치 단계를 건너뜁니다.
scripts/install.sh --no-bin
scripts/install.sh --no-active-dir
scripts/install.sh --no-rc
```

설치 환경 변수:

- `C4J_BIN_DIR`: `c4j` 기본 설치 디렉터리
- `C4J_ACTIVE_DIR`: 기본 active registry 경로
- `C4J_SHELL_RC`: `--rc`가 사용할 shell rc 파일

## 런타임 기본값

- Active registry: `~/.c4j/active`
- cmux 워크스페이스 prefix: `@active/`
- `add`: `--apply` 후 `sync --direction both`
- `sync`: `--dry-run --direction active-to-cmux`

런타임 환경 변수:

- `C4J_ACTIVE_DIR`
- `C4J_CMUX_BIN`
- `C4J_NAME_PREFIX`

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
- active symlink를 삭제하지 않습니다.
- cmux 워크스페이스를 닫지 않습니다.
- 설치 대상 실행 파일이 기존 파일과 다르면 덮어쓰지 않습니다.

## 개발

로컬 테스트:

```bash
bash -n bin/c4j bin/cmux4justn scripts/install.sh scripts/launchd.sh test/cmux4justn.test.sh
bash test/cmux4justn.test.sh
```

`shellcheck`가 있으면 함께 실행합니다.

```bash
shellcheck bin/c4j bin/cmux4justn scripts/install.sh scripts/launchd.sh test/cmux4justn.test.sh
```

CI는 push와 pull request에서 이 검사를 실행합니다.

## 릴리즈 체크리스트

1. `VERSION`과 `bin/cmux4justn`의 version string을 업데이트합니다.
2. `CHANGELOG.md`를 업데이트합니다.
3. syntax check, test, shellcheck, `git diff --check`를 실행합니다.
4. `main`에 commit/push합니다.
5. release tag를 만들고 push한 뒤 GitHub Release를 생성합니다.
