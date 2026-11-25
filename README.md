# skills

[Agent Skills 공개 표준](https://agentskills.io/specification)(SKILL.md)으로 쓴 에이전트 스킬 모음입니다. 스킬 내용은 특정 에이전트에 묶이지 않게 쓰고, 설치 방법만 쓰는 도구에 따라 다릅니다.

## 들어 있는 스킬

| 스킬 | 플러그인 | 하는 일 |
| --- | --- | --- |
| [commit](skills/commit/SKILL.md) | `dev` | Conventional Commits 1.0.0 기반 커밋 표준대로 커밋을 나누고 메시지와 PR 제목을 쓴다. 메시지 검사기와 저장소 설치 안내가 들어 있다 |

## 설치

### Claude Code: 플러그인 마켓플레이스

이 저장소는 그 자체로 플러그인 마켓플레이스입니다(마켓플레이스 이름 `ssgaa`). Claude Code 세션에서 한 줄로 설치합니다.

```text
/plugin install dev --marketplace ssgaa/skills
```

마켓플레이스를 처음 추가할 때 확인을 한 번 묻고, 이어서 설치 범위를 고릅니다. 나만 모든 프로젝트에서 쓰려면 user, 이 저장소의 모두가 쓰게 하려면 project를 고릅니다. 이 한 줄 설치는 Claude Code 2.1.275 이상에서 됩니다. 그보다 오래된 버전이거나 터미널에서 바로 설치하려면 마켓플레이스를 먼저 추가합니다.

```sh
claude plugin marketplace add ssgaa/skills
claude plugin install dev@ssgaa
```

설치가 끝나면 스킬은 설명을 보고 알아서 불리고, 직접 부를 때는 `/dev:commit`을 입력합니다. 데스크톱 앱은 Code 탭의 **+ → Plugins → Add plugin**에서, VS Code는 `/plugins`의 **Marketplaces** 탭에서 `ssgaa/skills`를 추가한 뒤 설치합니다.

#### 업데이트

이 마켓플레이스는 자동 업데이트가 기본으로 꺼져 있습니다. `/plugin` → **Marketplaces** → `ssgaa` → **Enable auto-update**로 켜거나, 필요할 때 직접 갱신합니다.

```text
/plugin marketplace update ssgaa
```

#### 팀 저장소에 등록하기

팀이 함께 쓰는 저장소에서 한 번 실행하고, 바뀐 `.claude/settings.json`을 커밋합니다.

```sh
claude plugin marketplace add ssgaa/skills --scope project
claude plugin install dev@ssgaa --scope project
```

폴더를 신뢰한 팀원에게는 마켓플레이스가 자동으로 등록됩니다. 플러그인 내려받기는 팀원마다 `claude plugin install dev@ssgaa --scope project`를 한 번씩 실행해야 합니다.

### claude.ai

- **조직(Team·Enterprise)**: 관리자가 **Organization settings → Plugins & skills**에서 이 저장소를 연결하면 구성원에게 배포됩니다. 이 방식은 저장소가 비공개(또는 internal)여야 합니다.
- **개인**: 스킬 폴더를 zip으로 묶어 스킬로 올립니다(아래 [zip 만들기](#zip-만들기)).

자세한 방법은 [claude.ai 플러그인 안내](https://claude.com/docs/plugins/overview)를 참고하세요.

### 그 밖의 에이전트

Agent Skills 표준을 지원하는 에이전트는 스킬 폴더를 그대로 씁니다. 스킬 하나는 `skills/<이름>/` 폴더 하나이고, 스크립트와 참고 문서가 함께 동작하도록 폴더를 통째로 옮깁니다.

- **폴더에서 스킬을 읽는 에이전트**: 에이전트의 스킬 폴더에 복사하거나 링크합니다. 링크해 두면 `git pull`만으로 갱신됩니다.

  ```sh
  git clone https://github.com/ssgaa/skills.git
  ln -s "$PWD/skills/skills/commit" <에이전트의 스킬 폴더>/commit
  ```

- **스킬을 업로드하는 에이전트**: zip을 만들어 올립니다.

스킬 폴더 위치와 업로드 방법은 각 에이전트의 문서를 확인하세요.

### zip 만들기

저장소 루트에서 실행합니다.

```sh
(cd skills && zip -r ../commit.zip commit)
```

## 기여

새 스킬을 추가하거나 고치려면 [CONTRIBUTING.md](CONTRIBUTING.md)를 읽어 주세요.
