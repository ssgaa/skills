// Conventional Commits 1.0.0 기반 커밋 표준 — commitlint 설정 (commit 스킬)
// .githooks/commit-msg(scripts/check_commit_msg.sh)와 같은 규칙이다.
// husky + commitlint를 이미 쓰는 JS 저장소에서만 필요하다. 둘 중 하나만 걸어도 된다.

const CLAUDE_ATTRIBUTION =
  /^(co-authored-by:.*noreply@anthropic\.com|claude-session:)|generated with \[claude code\]/im;
const EMPTY_SUBJECTS = new Set([
  '수정', '변경', '업데이트', '작업', '반영', '커밋', '테스트', '임시',
  'wip', 'WIP', 'update', 'Update', 'fix', 'test', 'temp', 'tmp', 'misc',
]);

export default {
  extends: ['@commitlint/config-conventional'],
  plugins: [
    {
      rules: {
        'no-claude-attribution': ({ raw }) => [
          !CLAUDE_ATTRIBUTION.test(raw ?? ''),
          'Claude 기본 표기(Co-Authored-By: Claude…, Generated with Claude Code, Claude-Session:)는 쓰지 않습니다. AI가 작성한 코드는 "Assisted-by: Claude Code" 한 줄로 표기합니다.',
        ],
        'breaking-change-pair': ({ header, raw }) => {
          const bang = /^[a-z]+(\([^)]*\))?!: /.test(header ?? '');
          const footer = /^BREAKING[ -]CHANGE: /m.test(raw ?? '');
          return [
            bang === footer,
            '호환성을 깨는 변경은 헤더 type(scope) 뒤의 !와 "BREAKING CHANGE:" 푸터를 함께 씁니다.',
          ];
        },
        'header-no-emoji': ({ header }) => [
          !/[\p{Extended_Pictographic}\u{FE0F}]/u.test(header ?? ''),
          '헤더에는 이모지를 쓰지 않습니다.',
        ],
        'subject-not-generic': ({ subject }) => [
          !EMPTY_SUBJECTS.has((subject ?? '').trim()),
          '제목만으로 무엇이 바뀌었는지 알 수 있게 바뀐 대상을 넣어 씁니다(예: 결제 버튼 비활성화 조건 수정).',
        ],
      },
    },
  ],
  rules: {
    'type-enum': [
      2,
      'always',
      ['feat', 'fix', 'docs', 'style', 'refactor', 'perf', 'test', 'build', 'ci', 'chore', 'revert'],
    ],
    'scope-case': [2, 'always', 'lower-case'],
    // 기본값을 두면 "docs: README 설치 안내 갱신", "build: Node 22로 업그레이드"처럼
    // 대문자 고유명사로 시작하는 한국어 제목을 위반으로 잡는다. 그래서 끈다.
    'subject-case': [0],
    'subject-full-stop': [2, 'never', '.'],
    'header-max-length': [2, 'always', 72],
    'body-leading-blank': [2, 'always'],
    'body-max-line-length': [1, 'always', 100],
    'footer-max-line-length': [1, 'always', 100],
    'no-claude-attribution': [2, 'always'],
    'breaking-change-pair': [2, 'always'],
    'header-no-emoji': [2, 'always'],
    'subject-not-generic': [2, 'always'],
  },
};
