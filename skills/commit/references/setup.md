# 저장소에 커밋 표준(Conventional Commits 1.0.0 기반) 깔기

사용자가 요청한 것만 설치한다. 각 단계는 따로 설치해도 된다. 설치 파일은 스킬의 `assets/`와 `scripts/`에 있다. 설치를 마치면 그 변경도 표준에 맞춰 커밋한다(예: `ci: 커밋 메시지·PR 제목 검사 추가`).

| 단계 | 하는 일 | 언제 |
| --- | --- | --- |
| 1 | 에이전트 도구의 커밋 자동 표기 끄기 | AI 에이전트로 커밋하는 모든 저장소 |
| 2 | commit-msg 훅으로 메시지 검사 | 커밋마다 표준을 지키게 할 때(머지 커밋·리베이스 방식) |
| 3 | commitlint 설정 | husky + commitlint를 이미 쓰는 JS 저장소 |
| 4 | PR 제목 검사 | 스쿼시 머지를 쓰는 GitHub 저장소 |
| 5 | 문서에 남기기 | 항상 |

스쿼시 머지만 쓰는 저장소는 브랜치 커밋이 머지 때 합쳐지므로 2번을 건너뛰고 4번만 깔아도 된다.

## 1. 에이전트 도구의 커밋 자동 표기 끄기

AI 에이전트 도구 중에는 커밋이나 PR에 표기를 자동으로 붙이는 것이 있다. AI를 공동 작성자로 올리는 `Co-authored-by` 트레일러, "Generated with …" 같은 생성 문구, 세션 링크가 대표적이다. 이 표준은 그런 표기 대신 `Assisted-by: <에이전트 이름>` 한 줄만 쓴다.

- 쓰는 도구에 이런 표기를 끄거나 문구를 바꾸는 설정이 있으면, 끄거나 `Assisted-by: <에이전트 이름>`으로 바꾼다. 설정 이름과 위치는 도구마다 다르니 그 도구의 문서를 확인한다.
- 도구가 저장소 단위 설정을 지원하면 그 설정 파일에 넣어 커밋한다. 그러면 저장소를 쓰는 모두에게 적용된다.
- 조직 관리자가 정책으로 표기를 정해 두었으면 저장소 설정으로는 바뀌지 않는다. 그럴 땐 사용자에게 관리자 확인이 필요하다고 알린다.
- 설정이 없거나 확실하지 않아도 괜찮다. 2번 훅이 마지막에 막는다.

## 2. commit-msg 훅 — 언어와 상관없이 쓰는 기본값

`scripts/check_commit_msg.sh`를 저장소의 훅으로 넣는다. POSIX sh라 Node나 Python 없이 macOS, Linux, Git Bash에서 돈다.

```sh
mkdir -p .githooks
cp <스킬 폴더>/scripts/check_commit_msg.sh .githooks/commit-msg
chmod +x .githooks/commit-msg
git config core.hooksPath .githooks
```

- `.githooks/`는 커밋해서 공유한다. `git config core.hooksPath .githooks`는 각자 한 번씩 실행해야 하므로 5번 문서에 적는다.
- 저장소가 이미 husky, lefthook, pre-commit을 쓰면 `core.hooksPath`를 바꾸지 않는다(기존 훅이 꺼진다). 대신 그 도구에서 스크립트를 부른다.
  - husky: `.husky/commit-msg` 파일 내용을 `sh .githooks/commit-msg "$1"`로 둔다.
  - lefthook (`lefthook.yml`):

    ```yaml
    commit-msg:
      commands:
        commit-standard:
          run: sh .githooks/commit-msg {1}
    ```

  - pre-commit (`.pre-commit-config.yaml`), 설치 후 `pre-commit install --hook-type commit-msg` 실행:

    ```yaml
    repos:
      - repo: local
        hooks:
          - id: commit-standard
            name: 커밋 표준 검사 (Conventional Commits)
            entry: sh .githooks/commit-msg
            language: system
            stages: [commit-msg]
    ```

- 기본 검사가 못 잡는 표기가 있으면 저장소 루트에 `.commit-msg-deny`를 두고 패턴을 적는다. 한 줄에 확장 정규식 하나를 쓰고(대소문자 무시), `#`으로 시작하는 줄과 빈 줄은 건너뛴다. 3번 commitlint 설정도 같은 파일을 읽는다.

  ```
  # 예: 어떤 도구가 붙이는 공동 작성자 서명
  ^Co-authored-by: Example Agent
  ```

검사기가 막는 것:

- 헤더 형식(type 11개, 소문자 scope, `: ` 뒤 제목), 대상 없는 제목("수정", "WIP" 등), 72자 넘는 헤더, 헤더 끝 마침표, 헤더의 이모지
- 헤더와 본문 사이 빈 줄 누락, `!`와 `BREAKING CHANGE:` 중 하나만 있는 경우
- AI 도구의 자동 표기: noreply 주소나 `[bot]` 계정의 `Co-authored-by`(사람이 쓰는 GitHub noreply 주소는 허용), 링크가 붙은 생성 문구, 로봇 이모지로 시작하는 줄, `<이름>-Session:` 트레일러
- `.commit-msg-deny`의 패턴

본문 한 줄이 100자를 넘으면 경고만 한다. `Merge`, `Revert "…"`, `fixup!`, `squash!`, `amend!`로 시작하는 자동 메시지는 건너뛴다.

설치 후 확인:

```sh
printf 'feat(auth): 카카오 로그인 추가\n' | sh .githooks/commit-msg -   # 통과(종료 코드 0)
printf 'Feat: 로그인 수정.\n' | sh .githooks/commit-msg -              # 실패(종료 코드 1)
```

## 3. (선택) commitlint — husky를 쓰는 JS 저장소

`assets/commitlint.config.mjs`를 저장소 루트에 둔다. 2번 검사기와 같은 규칙이다. 한국어 제목이 README·API처럼 대문자 고유명사로 시작하면 기본 `subject-case` 규칙이 위반으로 잡기 때문에 그 규칙은 꺼 두었다.

```sh
npm i -D @commitlint/cli @commitlint/config-conventional
echo 'npx --no -- commitlint --edit "$1"' > .husky/commit-msg
```

2번 검사기와 3번 commitlint는 둘 중 하나만 걸어도 된다. 4번 PR 제목 검사는 2번 파일을 쓰므로, commitlint만 쓰는 저장소도 `.githooks/commit-msg` 파일은 커밋해 둔다(`core.hooksPath` 설정은 안 해도 된다).

## 4. PR 제목 검사 — GitHub Actions

스쿼시 머지에서는 PR 제목이 main의 커밋 제목이 되므로 PR 제목도 같은 규칙으로 검사한다.

1. `assets/pr-title.yml`을 `.github/workflows/pr-title.yml`로 복사한다. 2번의 `.githooks/commit-msg`를 `--title` 모드로 불러 한 줄 헤더만 검사한다.
2. 저장소 Settings → General → Pull Requests에서 스쿼시 머지의 기본 커밋 메시지를 PR 제목(또는 PR 제목과 설명)으로 지정하도록 사용자에게 안내한다. 저장소 관리자 권한이 필요한 화면 설정이라 직접 바꾸지 않는다.
3. 이 검사를 머지 필수 조건으로 걸려면 브랜치 보호 규칙의 required status checks에 `pr-title`을 추가하도록 안내한다.

## 5. 문서에 남기기

- `CONTRIBUTING.md`(없으면 README)에 SKILL.md 3~6장의 요약과 4장 type 표, `git config core.hooksPath .githooks` 안내를 넣는다.
- `AGENTS.md`처럼 에이전트가 읽는 지침 파일이 있으면 "커밋 메시지와 PR 제목은 Conventional Commits 1.0.0 기반 커밋 표준(commit 스킬)을 따른다. AI 도구의 자동 표기 대신 `Assisted-by: <에이전트 이름>`을 쓴다."를 넣는다. 이 스킬을 쓰지 않는 에이전트도 같은 규칙을 보게 하려는 것이다.
