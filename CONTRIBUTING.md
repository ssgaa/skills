# 기여 안내

## 구조

```
skills/<이름>/                  스킬 하나 = 폴더 하나(폴더 이름 = name)
  SKILL.md                      frontmatter(name, description) + 지침
  scripts/ references/ assets/
tests/<이름>/                   스킬별 테스트(스킬 폴더 밖에 둔다)
.claude-plugin/marketplace.json 배포 목록: 플러그인과 플러그인에 담을 스킬 경로
scripts/validate_skills.py      SKILL.md 형식과 배포 목록 검증
.githooks/commit-msg            이 저장소의 커밋 메시지 검사
.github/workflows/ci.yml        PR마다 형식 검증, 테스트, PR 제목 검사
```

## 새 스킬 추가

1. `skills/<이름>/SKILL.md`를 만든다. 이름은 영어 소문자·숫자·하이픈으로 64자 이내로 짓고, 폴더 이름과 frontmatter의 `name`을 같게 한다.
2. frontmatter에는 표준 필드만 쓴다. `name`과 `description`(1024자 이내, 꺾쇠괄호 없이)은 필수이고, 필요하면 `license`, `compatibility`, `metadata`, `allowed-tools`를 쓴다. 특정 에이전트 전용 필드는 넣지 않는다. 그런 필드를 읽지 않는 에이전트가 많다.
3. 스킬 폴더 안의 본문과 참고 문서에는 특정 에이전트의 이름, 전용 설정 파일, 전용 명령을 쓰지 않는다. 도구마다 다른 부분은 "에이전트 도구의 설정"처럼 일반적으로 쓰고, 각 도구의 문서를 보라고 안내한다. 에이전트별 설치 방법은 README와 배포 목록에만 둔다.
4. 스킬 폴더는 혼자 동작해야 한다. 다른 스킬의 파일을 참조하지 않고, 필요한 스크립트와 문서는 자기 폴더에 둔다. SKILL.md가 참조하는 파일은 한 단계 아래(`scripts/`, `references/`, `assets/`)까지만 둔다. 실행 파일은 `bin/`이 아니라 `scripts/`에 둔다.
5. 스크립트가 있으면 `tests/<이름>/`에 테스트를 추가하고 `.github/workflows/ci.yml`에 단계를 넣는다.
6. 배포 목록에 등록한다. `.claude-plugin/marketplace.json`에서 알맞은 플러그인의 `skills`에 `./skills/<이름>`을 추가한다. 맞는 플러그인이 없으면 플러그인 항목을 새로 만든다. 스킬은 `/<플러그인>:<스킬>`로 불리니 플러그인 이름은 짧은 영어 소문자로 짓는다. 플러그인에 `version`은 적지 않는다. 적으면 그 값을 바꿀 때까지 사용자가 새 커밋을 받지 못한다. 목록에서 빠진 스킬은 CI가 잡는다.
7. README의 스킬 표에 한 줄을 추가한다.
8. PR 전에 확인한다.

   ```sh
   python3 scripts/validate_skills.py
   sh tests/commit/test_check_commit_msg.sh
   ```

   Claude Code가 있으면 `claude plugin validate .`로 배포 목록을 한 번 더 확인할 수 있다.

## 커밋 규칙

이 저장소도 commit 스킬의 표준을 따른다. 클론한 뒤 한 번 실행한다.

```sh
git config core.hooksPath .githooks
```
