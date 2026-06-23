# c4j

[English README](README.md)

`c4j`는 active project symlink와 cmux 워크스페이스를 동기화하는 macOS shell CLI입니다.

cmux 사용자가 프로젝트 추가, active 목록 확인, workspace title 동기화, `~/Workspaces` pinned anchor workspace 관리를 작은 CLI 하나로 처리할 수 있게 합니다.

`c4j`는 프로젝트 파일을 옮기지 않고, active registry에 symlink만 만들고, 필요한 cmux 워크스페이스만 생성합니다. 기본 동작은 보수적입니다. `c4j delete`를 명시적으로 실행할 때만 active symlink를 제거하거나 cmux 워크스페이스를 닫습니다.

## 기능

- plain Bash script 기반 한 줄 macOS 설치
- `~/.c4j/active` symlink 기반 active project registry
- `c4j go <name-or-path>`로 빠른 프로젝트 이동
- `c4j cd <name-or-path>`로 조용한 현재 shell 디렉터리 이동
- `@active/` 같은 configurable title prefix로 cmux workspace sync
- `c4j anchor`를 통한 pinned cmux anchor workspace 관리
- 현재 repo용 git worktree 생성
- 안전한 기본값: dry-run sync, 명시적 apply, 실제 프로젝트 디렉터리 삭제 없음

## 설치

```bash
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/v0.13.8/install.sh | bash -s -- --rc
```

설치 스크립트는 기본적으로 다음 작업을 합니다.

- source를 `~/.local/share/c4j`에 다운로드
- `~/.local/bin/c4j`에 실행 파일 설치
- `~/.c4j/active` active registry 생성
- active registry 경로를 `~/.c4j/config`에 저장
- `--rc` 옵션을 넘기면 shell wrapper와 completion fallback을 shell rc에 추가

`--rc` wrapper가 있어야 `c4j go`, `c4j cd`, `c4j wt`가 현재 shell 디렉터리를 바꿀 수 있습니다. `~/.local/bin`이 `PATH`에 없으면 설치 스크립트가 shell rc에 추가할 `export` 줄을 출력합니다. 그 뒤 설정 상태를 확인합니다.

```bash
c4j doctor
```

## 빠른 시작

```bash
# 현재 프로젝트를 열고 cmux workspace를 focus합니다.
c4j go .

# 이름으로 active 프로젝트를 엽니다.
c4j go cmux4justn

# cmux는 건드리지 않고 현재 shell 디렉터리만 옮깁니다.
c4j cd cmux4justn

# 현재 repo에서 worktree를 만들고 그 디렉터리로 이동합니다.
c4j wt feature-api

# 기존 worktree를 다시 찾습니다.
c4j wt list

# 끝난 managed worktree를 제거합니다.
c4j wt delete feature-api

# active 프로젝트 목록을 봅니다.
c4j list

# 프로젝트를 active registry에서 제거하고 cmux 워크스페이스도 닫습니다.
c4j delete cmux4justn

# 특정 명령어 도움말만 봅니다.
c4j help go
c4j help cd
c4j help wt
```

## 명령어

특정 명령어만 보고 싶으면 `c4j help <command>` 또는 `c4j <command> --help`를 씁니다.
자동화/에이전트용 출력 규칙은 `c4j help agent`에서 확인합니다.

### `c4j go [--dry-run|--apply] [--no-cmux] <name-or-path>`

active 프로젝트 이름이나 디렉터리 경로로 이동합니다. 아직 active가 아닌 경로를 넘기면 먼저 active registry에 추가합니다.

`go`는 기본값이 `--apply`입니다. 기존 `@active/<project>` cmux workspace가 있으면 선택하고, 없으면 새로 만든 뒤 `go-project` 행을 출력합니다. `scripts/install.sh --rc`로 설치한 shell wrapper는 이 행을 읽고 현재 셸 디렉터리를 프로젝트로 옮깁니다.

cmux는 건드리지 않고 셸 이동과 active symlink 관리만 하고 싶으면 `--no-cmux`를 씁니다.

```bash
c4j go cmux4justn
c4j go codeagora
c4j go .
c4j go ~/Workspaces/repos/bssm-oss/main/justn-hyeok/cmux4justn
c4j go --dry-run cmux4justn
c4j go --no-cmux cmux4justn
```

### `c4j cd [--dry-run|--apply] <name-or-path>`

active 프로젝트 이름이나 디렉터리 경로로 현재 shell 디렉터리만 옮깁니다. cmux는 건드리지 않고, 새 active symlink도 만들지 않습니다.

일반적인 `cd` helper처럼 `scripts/install.sh --rc`로 설치된 shell wrapper가 필요합니다. wrapper 없이 실행 파일만 직접 호출하면 부모 shell의 cwd를 바꿀 수 없어서 script용 target row만 출력합니다.

```bash
c4j cd cmux4justn
c4j cd .
c4j cd --dry-run codeagora
```

### `c4j worktree [--dry-run|--apply] [--repo <path>] [--name <name>]`

현재 repo용 git worktree를 `~/Workspaces/worktrees` 아래에 만듭니다. canonical repo 경로는 `~/Workspaces/repos` 구조를 그대로 따라갑니다.
repo 안에서 실행하면 현재 작업 디렉터리를 source repo로 사용합니다. 그 디렉터리가 git repo가 아니더라도 cmux 안에서 실행 중이면 현재 cmux workspace의 repo를 찾아서 씁니다. `--repo`를 주면 source path를 직접 지정할 수 있습니다.
첫 번째 positional argument가 worktree 이름이므로 `c4j wt for-feature1`처럼 쓰는 게 기본입니다.

기본 worktree 이름은 `<repo>-<branch>`입니다. 같은 이름이 이미 있으면 `-2`, `-3`처럼 번호를 붙입니다. `--name`을 주면 worktree 이름을 직접 지정할 수 있습니다.

`worktree`의 기본값은 `--apply`입니다. `wt`, `pane`, `make-pane`은 alias입니다.
`scripts/install.sh`로 설치된 셸 wrapper를 쓰면, 성공한 `c4j wt ...`가 현재 셸 디렉터리를 생성/재사용한 worktree로 바로 옮깁니다.
`c4j wt list`는 cmux 워크스페이스 안에서는 현재 워크스페이스의 worktree만 보여주고, 워크스페이스 밖에서는 찾을 수 있는 전체 managed worktree를 보여줍니다.
`c4j wt prune`은 현재 스코프의 stale worktree 메타데이터를 정리하고, `c4j wt move`는 지정한 worktree를 새 경로로 옮깁니다.
`c4j wt delete`와 `c4j wt update`는 예전 이름 호환용 alias로 남겨둡니다.

```bash
c4j worktree
c4j worktree --dry-run
c4j wt for-feature1
c4j wt list
c4j wt prune
c4j wt move api api-v2
c4j worktree --repo ~/Workspaces/repos/bssm-oss/main/justn-hyeok/cmux4justn
c4j worktree --name api
```

### `c4j list [--plain]`

active symlink와 실제 target 경로를 표로 출력합니다.

script에서 쓰기 쉬운 tab-separated 출력이 필요하면 `--plain` 또는 `--tsv`를 사용합니다.

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

## 유지보수와 고급 사용

아래 명령어는 복구, 대량 reconcile, 설정 변경, script 용도에 가깝습니다. 일반적인 daily workflow는 `go`, `cd`, `wt`, `list`, `delete`에서 시작하면 됩니다.

### `c4j add [--dry-run|--apply] <path>...`

하나 이상의 디렉터리를 active registry에 symlink로 추가한 뒤 `sync --direction both`를 실행합니다.

경로 없이 실행하면 새 프로젝트를 추가하지 않고 양방향 동기화를 미리 봅니다.

```bash
c4j add
c4j add --apply
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

### `c4j update [--dry-run|--apply] [--ref <ref>] [--repo-url <url>] [--install-dir <path>] [--allow-unsafe-source]`

`c4j` 자체를 최신 태그로 다시 설치합니다. 기본적으로 `https://github.com/bssm-oss/cmux4justn.git`의 `v*` 태그 중 가장 최신을 찾아서 `~/.local/share/c4j`에서 다시 설치합니다.

`--ref`로 신뢰하는 `v*` 태그를 고정할 수 있고, `--install-dir`로 로컬 소스 checkout 경로를 바꿀 수 있습니다. 다른 `--repo-url`이나 `v*`가 아닌 ref는 `--allow-unsafe-source`가 필요합니다.

```bash
c4j update
c4j update --dry-run
c4j update --ref v0.13.8
c4j update --repo-url <url> --ref <ref> --allow-unsafe-source
```

dry-run 출력에는 현재 CLI 버전, target ref, resolved target commit, local source checkout이 이미 최신인지 여부가 포함됩니다.

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
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/v0.13.8/install.sh | C4J_REF=v0.13.8 bash -s -- --rc

# bootstrap script에 고정된 릴리즈 대신 main에서 설치합니다.
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/main/install.sh | C4J_REF=main bash -s -- --rc --allow-unsafe-source

# source 다운로드 위치를 바꿉니다.
curl -fsSL https://raw.githubusercontent.com/bssm-oss/cmux4justn/v0.13.8/install.sh | C4J_INSTALL_DIR="$HOME/src/c4j" bash -s -- --rc

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
- `C4J_REPO_URL`: `c4j update`가 참조하는 소스 remote
- `C4J_INSTALL_DIR`: `c4j update`가 쓰는 로컬 source checkout
- `C4J_UPDATE_REF`: `c4j update`의 ref override

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
bash -n bin/c4j bin/cmux4justn install.sh scripts/install.sh scripts/launchd.sh scripts/release.sh test/cmux4justn.test.sh completions/c4j.bash
bash test/cmux4justn.test.sh
```

`shellcheck`가 있으면 함께 실행합니다.

```bash
shellcheck -x bin/c4j bin/cmux4justn install.sh scripts/install.sh scripts/launchd.sh scripts/release.sh test/cmux4justn.test.sh completions/c4j.bash
```

CI는 push와 pull request에서 이 검사를 실행합니다.

## 릴리즈 체크리스트

깨끗한 `main` checkout에서 release script를 실행합니다.

```bash
scripts/release.sh 0.13.4
```

파일이나 remote를 바꾸지 않고 순서만 확인하려면 dry-run을 사용합니다.

```bash
scripts/release.sh --dry-run 0.13.4
```

이 스크립트는 version reference 갱신, local check, commit, `main` push, `main` CI 대기, tag push, tag CI 대기, GitHub Release 생성을 순서대로 수행합니다. `gh` 인증이나 GitHub Actions 조회가 불가능하면 remote mutation 전에 실패합니다.
