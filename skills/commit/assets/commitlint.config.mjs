// Conventional Commits 1.0.0 기반 커밋 표준 — commitlint 설정 (commit 스킬)
// scripts/check_commit_msg.sh와 같은 규칙이다.
// husky + commitlint를 이미 쓰는 JS 저장소에서만 필요하다. 둘 중 하나만 걸어도 된다.
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const EMPTY_SUBJECTS = new Set([
  '수정', '변경', '업데이트', '작업', '반영', '커밋', '테스트', '임시',
  'wip', 'WIP', 'update', 'Update', 'fix', 'test', 'temp', 'tmp', 'misc',
]);

// AI 도구의 자동 표기:
// - AI를 공동 작성자로 올리는 Co-authored-by: noreply 주소(사람이 쓰는 GitHub noreply 주소는 제외)나 [bot] 계정
// - 세션·대화 링크 트레일러: <이름>-Session:
// - 링크가 붙은 생성 표기("Generated with/by [도구](…)")와 로봇 이모지로 시작하는 줄
function aiAttributionLines(raw) {
  return (raw ?? '').split(/\r?\n/).filter((line) => {
    const l = line.toLowerCase();
    if (l.startsWith('co-authored-by:')) {
      return (l.includes('noreply@') && !l.includes('users.noreply.github.com')) || l.includes('[bot]');
    }
    return /^[a-z0-9][a-z0-9-]*-session:/.test(l) || /generated (with|by) \[/.test(l) || line.startsWith('\u{1F916}');
  });
}

// 터미널에서 차지하는 칸 수. 전각 글자(U+3000–U+DFFF: 한글·한자·가나 등)와 U+10000 이상 문자는 2칸으로 센다.
// scripts/check_commit_msg.sh의 count_width와 같은 기준이다.
function displayWidth(line) {
  let width = 0;
  for (const ch of line) {
    const cp = ch.codePointAt(0);
    width += (cp >= 0x3000 && cp <= 0xdfff) || cp >= 0x10000 ? 2 : 1;
  }
  return width;
}

const TRAILER = /^([A-Za-z][A-Za-z0-9-]*|BREAKING CHANGE): /;

// 저장소가 따로 막는 패턴: 저장소 루트의 .commit-msg-deny(또는 COMMIT_MSG_DENY_FILE)
// 한 줄에 정규식 하나(대소문자 무시). #으로 시작하는 줄과 빈 줄은 건너뛴다.
function denyPatterns() {
  const file = process.env.COMMIT_MSG_DENY_FILE || join(process.cwd(), '.commit-msg-deny');
  if (!existsSync(file)) return [];
  return readFileSync(file, 'utf8')
    .split(/\r?\n/)
    .filter((s) => s.trim() !== '' && !s.trim().startsWith('#'))
    .map((s) => new RegExp(s, 'im'));
}

export default {
  extends: ['@commitlint/config-conventional'],
  plugins: [
    {
      rules: {
        'no-ai-attribution': ({ raw }) => {
          const lines = aiAttributionLines(raw);
          return [
            lines.length === 0,
            `AI 도구의 자동 표기(AI 공동 작성자 Co-authored-by, 생성 표기 문구, 세션 링크 트레일러)는 쓰지 않습니다. AI가 작성한 코드는 "Assisted-by: <에이전트 이름>" 한 줄로 표기합니다. 문제 줄: ${lines.join(' / ')}`,
          ];
        },
        'repo-deny-patterns': ({ raw }) => {
          const hits = denyPatterns().filter((re) => re.test(raw ?? ''));
          return [
            hits.length === 0,
            `이 저장소에서 쓰지 않기로 한 표기가 들어 있습니다(.commit-msg-deny): ${hits.map(String).join(', ')}`,
          ];
        },
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
        'body-max-line-width': ({ body }, _when, max = 72) => {
          const lines = (body ?? '')
            .split(/\r?\n/)
            .filter((l) => !l.includes('://') && !TRAILER.test(l) && displayWidth(l) > max);
          return [
            lines.length === 0,
            `본문 한 줄이 ${max}칸을 넘습니다(전각 글자는 2칸). 쉼표나 연결 어미 뒤에서 나눕니다. 문제 줄: ${lines.join(' / ')}`,
          ];
        },
        'body-sentence-per-line': ({ body }) => {
          const lines = (body ?? '').split(/\r?\n/).filter((l) => /다\. +\S/.test(l));
          return [
            lines.length === 0,
            `한 줄에 문장이 둘 이상입니다. 문장마다 새 줄에서 시작합니다. 문제 줄: ${lines.join(' / ')}`,
          ];
        },
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
    // 글자 수로 세면 한글 줄이 영어 줄의 두 배 폭까지 통과한다. 폭으로 세는 body-max-line-width를 쓴다.
    'body-max-line-length': [0],
    'body-max-line-width': [1, 'always', 72],
    'body-sentence-per-line': [1, 'always'],
    'footer-max-line-length': [1, 'always', 100],
    'no-ai-attribution': [2, 'always'],
    'repo-deny-patterns': [2, 'always'],
    'breaking-change-pair': [2, 'always'],
    'header-no-emoji': [2, 'always'],
    'subject-not-generic': [2, 'always'],
  },
};
