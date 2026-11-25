#!/bin/sh
# Conventional Commits 1.0.0 기반 커밋 표준 검사기 (commit 스킬)
#
# 사용법
#   check_commit_msg.sh <메시지 파일>       commit-msg 훅. git이 메시지 파일 경로를 넘긴다
#   check_commit_msg.sh -                  표준 입력으로 받은 메시지를 검사
#   check_commit_msg.sh --title <파일|->   PR 제목처럼 한 줄 헤더만 검사
#
# 저장소 루트의 .commit-msg-deny에 패턴을 적으면 그 패턴도 막는다(경로는 COMMIT_MSG_DENY_FILE로 바꿀 수 있다).
#
# 종료 코드: 0 통과, 1 표준 위반, 2 사용법 오류
# POSIX sh로 작성해 macOS, Linux, Git Bash(Windows)에서 같은 결과가 나오게 했다.

TYPES='feat fix docs style refactor perf test build ci chore revert'
MAX_HEADER=72
WARN_WIDTH=72

mode=full
if [ "${1:-}" = "--title" ]; then
  mode=title
  shift
fi
src=${1:-}
if [ -z "$src" ]; then
  echo "사용법: $0 [--title] <메시지 파일 | ->" >&2
  exit 2
fi
if [ "$src" != "-" ] && [ ! -r "$src" ]; then
  echo "메시지 파일을 읽을 수 없습니다: $src" >&2
  exit 2
fi

read_msg() {
  if [ "$src" = "-" ]; then cat; else cat -- "$src"; fi
}

# git이 커밋할 때 지우는 부분(주석 줄, verbose 모드의 diff 구분선 아래)과 앞쪽 빈 줄은 검사에서 뺀다.
msg=$(read_msg | tr -d '\r' | sed -e '/^# -* >8 -*$/,$d' -e '/^#/d' | sed -e '/./,$!d')
header=$(printf '%s\n' "$msg" | sed -n '1p')

if [ -z "$header" ]; then
  echo "커밋 메시지가 비어 있습니다." >&2
  exit 1
fi

# git이 자동으로 만드는 메시지는 건너뛴다.
case $header in
  'Merge '*|'Revert "'*|'fixup! '*|'squash! '*|'amend! '*) exit 0 ;;
esac

errors=0
err() { printf '  - %s\n' "$1" >&2; errors=$((errors + 1)); }
warn() { printf '  ! %s\n' "$1" >&2; }

# UTF-8에서 이어지는 바이트(0x80-0xBF)를 빼고 세면 로케일과 상관없이 글자 수가 나온다.
count_chars() { printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '; }

# 터미널에서 차지하는 칸 수. 전각 글자(U+3000-U+DFFF: 한글·한자·가나 등, 첫 바이트 0xE3-0xED)와
# U+10000 이상 문자(첫 바이트 0xF0-0xF4)는 2칸으로 센다. commitlint 설정의 displayWidth와 같은 기준이다.
count_width() {
  _chars=$(count_chars "$1")
  _wide=$(printf '%s' "$1" | LC_ALL=C tr -cd '\343-\355\360-\364' | wc -c | tr -d ' ')
  echo $((_chars + _wide))
}

# 1) type과 헤더 형식
type=$(printf '%s\n' "$header" | LC_ALL=C sed -n 's/^\([A-Za-z]*\).*/\1/p')
case " $TYPES " in
  *" $type "*) type_ok=1 ;;
  *) type_ok=0 ;;
esac

if [ -z "$type" ]; then
  err "헤더가 type으로 시작하지 않습니다. 형식: type(scope): 제목 / type: $TYPES"
elif [ "$type_ok" -eq 0 ]; then
  lower=$(printf '%s' "$type" | LC_ALL=C tr '[:upper:]' '[:lower:]')
  case " $TYPES " in
    *" $lower "*) err "type은 소문자로 씁니다: '$type' -> '$lower'" ;;
    *) err "'$type'은(는) 허용된 type이 아닙니다. 다음 중 하나를 씁니다: $TYPES" ;;
  esac
else
  re_types=$(printf '%s' "$TYPES" | tr ' ' '|')
  if ! printf '%s\n' "$header" | LC_ALL=C grep -Eq "^($re_types)(\([a-z0-9][a-z0-9._/-]*\))?!?: [^ ]"; then
    err "형식은 type(scope)!: 제목 입니다. scope는 영어 소문자·숫자·-_./ 로 쓰고, 콜론 뒤에 한 칸 띄우고 제목을 씁니다."
  fi
fi

# 2) 내용 없는 제목
subject=$(printf '%s\n' "$header" | sed -n 's/^[^:]*: *//p')
case $subject in
  '수정'|'변경'|'업데이트'|'작업'|'반영'|'커밋'|'테스트'|'임시'|\
  'wip'|'WIP'|'update'|'Update'|'fix'|'test'|'temp'|'tmp'|'misc')
    err "제목 '$subject'만으로는 무엇이 바뀌었는지 알 수 없습니다. 바뀐 대상을 넣어 씁니다(예: 결제 버튼 비활성화 조건 수정)." ;;
esac

# 3) 길이
len=$(count_chars "$header")
if [ "$len" -gt "$MAX_HEADER" ]; then
  err "헤더가 ${len}자입니다. ${MAX_HEADER}자 이내로 줄입니다(한글 제목은 30자 안팎 권장)."
fi

# 4) 마침표
case $header in
  *.) err "헤더 끝에 마침표를 찍지 않습니다." ;;
esac

# 5) 이모지: 4바이트 문자, 기호·딩뱃 블록(U+2600-27BF), 이모지 변형 선택자(U+FE0F)
if printf '%s' "$header" | LC_ALL=C grep -q "$(printf '[\360-\364]')" \
  || printf '%s' "$header" | LC_ALL=C grep -q "$(printf '\342[\230-\236]')" \
  || printf '%s' "$header" | LC_ALL=C grep -q "$(printf '\357\270\217')"; then
  err "헤더에는 이모지를 쓰지 않습니다."
fi

if [ "$mode" = full ]; then
  # 6) 헤더 다음 줄은 비운다
  line2=$(printf '%s\n' "$msg" | sed -n '2p' | tr -d ' \t')
  if [ -n "$line2" ]; then
    err "헤더와 본문 사이에 빈 줄을 둡니다."
  fi

  # 7) 호환성 깨짐은 헤더의 !와 BREAKING CHANGE 푸터를 함께 쓴다
  bang=0
  if printf '%s\n' "$header" | LC_ALL=C grep -Eq '^[a-z]+(\([^)]*\))?!: '; then bang=1; fi
  footer=0
  if printf '%s\n' "$msg" | LC_ALL=C grep -Eq '^BREAKING[ -]CHANGE: '; then footer=1; fi
  if [ "$bang" -eq 1 ] && [ "$footer" -eq 0 ]; then
    err "헤더에 !를 붙였으면 푸터에 'BREAKING CHANGE: <무엇이 달라지는지>'를 씁니다."
  elif [ "$bang" -eq 0 ] && [ "$footer" -eq 1 ]; then
    err "BREAKING CHANGE 푸터가 있으면 헤더의 type(scope) 뒤에 !를 붙입니다."
  fi

  # 8) 본문 줄바꿈 (경고만)
  #    - 한 줄에 "~다."로 끝난 문장 뒤에 다음 문장이 이어지면
  #    - 한 줄이 72칸을 넘으면. URL이 든 줄과 `키: 값` 트레일러 줄은 뺀다
  printf '%s\n' "$msg" | sed -n '3,$p' | while IFS= read -r line || [ -n "$line" ]; do
    if printf '%s\n' "$line" | LC_ALL=C grep -Eq '다[.] +[^ ]'; then
      warn "한 줄에 문장이 둘 이상입니다. 문장마다 새 줄에서 시작합니다: $line"
    fi
    case $line in *://*) continue ;; esac
    if printf '%s\n' "$line" | LC_ALL=C grep -Eq '^([A-Za-z][A-Za-z0-9-]*|BREAKING CHANGE): '; then continue; fi
    w=$(count_width "$line")
    if [ "$w" -gt "$WARN_WIDTH" ]; then
      warn "본문 한 줄이 ${w}칸입니다(전각 글자는 2칸). ${WARN_WIDTH}칸을 넘지 않게 쉼표나 연결 어미 뒤에서 나눕니다: $line"
    fi
  done
fi

# 9) AI 도구의 자동 표기는 쓰지 않는다. AI 사용은 Assisted-by 한 줄로만 남긴다.
#    - AI를 공동 작성자로 올리는 Co-authored-by: noreply 주소(사람이 쓰는 GitHub noreply 주소는 제외)나 [bot] 계정
#    - 세션·대화 링크 트레일러: <이름>-Session:
#    - 링크가 붙은 생성 표기("Generated with/by [도구](…)")와 로봇 이모지로 시작하는 줄
ai_lines=$(printf '%s\n' "$msg" | LC_ALL=C awk '
  { l = tolower($0) }
  l ~ /^co-authored-by:/ && ((l ~ /noreply@/ && l !~ /users\.noreply\.github\.com/) || l ~ /\[bot\]/) { print; next }
  l ~ /^[a-z0-9][a-z0-9-]*-session:/ { print; next }
  l ~ /generated (with|by) \[/ { print; next }
')
robot_lines=$(printf '%s\n' "$msg" | LC_ALL=C grep "^$(printf '\360\237\244\226')" || true)
ai_hits=$(printf '%s\n%s\n' "$ai_lines" "$robot_lines" | sed '/^$/d' | awk '!seen[$0]++')
if [ -n "$ai_hits" ]; then
  err "AI 도구의 자동 표기(AI 공동 작성자 Co-authored-by, 생성 표기 문구, 세션 링크 트레일러)는 쓰지 않습니다. AI가 작성한 코드는 'Assisted-by: <에이전트 이름>' 한 줄로 표기합니다."
  printf '%s\n' "$ai_hits" | sed 's/^/      문제 줄: /' >&2
fi

# 10) 저장소가 따로 막는 패턴: 저장소 루트의 .commit-msg-deny(또는 COMMIT_MSG_DENY_FILE)
#     한 줄에 확장 정규식 하나(대소문자 무시). #으로 시작하는 줄과 빈 줄은 건너뛴다.
deny_file=${COMMIT_MSG_DENY_FILE:-}
if [ -z "$deny_file" ]; then
  top=$(git rev-parse --show-toplevel 2>/dev/null || true)
  if [ -n "$top" ]; then deny_file="$top/.commit-msg-deny"; fi
fi
if [ -n "$deny_file" ] && [ -r "$deny_file" ]; then
  deny_hits=$(tr -d '\r' < "$deny_file" | sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' \
    | while IFS= read -r pat || [ -n "$pat" ]; do
        printf '%s\n' "$msg" | grep -Ei -- "$pat" || true
      done | awk '!seen[$0]++')
  if [ -n "$deny_hits" ]; then
    err "이 저장소에서 쓰지 않기로 한 표기가 들어 있습니다(.commit-msg-deny)."
    printf '%s\n' "$deny_hits" | sed 's/^/      문제 줄: /' >&2
  fi
fi

if [ "$errors" -gt 0 ]; then
  printf '\n커밋 표준(Conventional Commits 1.0.0 기반)에 맞지 않습니다(%s건). 형식: type(scope)!: 제목 / 빈 줄 / 본문 / 빈 줄 / 푸터\n' "$errors" >&2
  exit 1
fi
exit 0
