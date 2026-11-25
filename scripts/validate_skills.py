#!/usr/bin/env python3
"""skills/ 아래 스킬이 Agent Skills 형식(https://agentskills.io/specification)을 지키는지 검사한다.

사용법: python3 scripts/validate_skills.py [스킬 폴더 ...]
인자가 없으면 skills/ 아래 모든 폴더를 검사하고, 배포 목록(.claude-plugin/marketplace.json)이 있으면
목록의 스킬 경로가 맞는지와 목록에서 빠진 스킬이 없는지도 검사한다. 위반이 하나라도 있으면 종료 코드 1.
PyYAML이 있으면 그것으로 frontmatter를 읽고, 없으면 간단한 내장 파서를 쓴다.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MARKETPLACE = ROOT / ".claude-plugin" / "marketplace.json"
ALLOWED_FIELDS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def unquote(value):
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
        return value[1:-1]
    return value


def simple_yaml(block):
    """키: 값 한 단계와 metadata 같은 들여쓴 맵 한 단계만 읽는 최소 파서."""
    data, current = {}, None
    for raw in block.splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        if raw[0] in " \t":
            if current is None:
                raise ValueError(f"들여쓰기 위치가 이상합니다: {raw.strip()}")
            key, _, value = raw.strip().partition(":")
            if not isinstance(data[current], dict):
                data[current] = {}
            data[current][key.strip()] = unquote(value.strip())
            continue
        key, sep, value = raw.partition(":")
        if not sep:
            raise ValueError(f"'키: 값' 형식이 아닙니다: {raw}")
        key, value = key.strip(), value.strip()
        data[key] = unquote(value) if value else {}
        current = key
    return data


def read_frontmatter(text):
    if not text.startswith("---\n"):
        raise ValueError("SKILL.md가 YAML frontmatter(---)로 시작하지 않습니다")
    end = text.find("\n---", 4)
    if end == -1:
        raise ValueError("frontmatter를 닫는 --- 줄이 없습니다")
    block, body = text[4:end], text[end + 4:]
    try:
        import yaml  # noqa: PLC0415
    except ImportError:
        data = simple_yaml(block)
    else:
        data = yaml.safe_load(block)
    if not isinstance(data, dict):
        raise ValueError("frontmatter는 '키: 값' 형태여야 합니다")
    return data, body


def check_skill(skill_dir):
    label = skill_dir.name
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        return [f"{label}: SKILL.md가 없습니다"]

    errors = []
    nested = sorted(str(p.relative_to(skill_dir)) for p in skill_dir.rglob("SKILL.md") if p != skill_md)
    if nested:
        errors.append(f"{label}: 스킬 하나에는 SKILL.md가 하나만 있어야 합니다. 하위 폴더의 파일: {', '.join(nested)}")

    try:
        meta, body = read_frontmatter(skill_md.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        return errors + [f"{label}: {exc}"]

    extra = sorted(set(meta) - ALLOWED_FIELDS)
    if extra:
        errors.append(f"{label}: 표준에 없는 frontmatter 필드는 쓰지 않습니다: {', '.join(extra)}")

    name = meta.get("name")
    if not isinstance(name, str) or not name:
        errors.append(f"{label}: name이 없습니다")
    else:
        if len(name) > 64:
            errors.append(f"{label}: name은 64자 이내여야 합니다({len(name)}자)")
        if not NAME_RE.match(name):
            errors.append(f"{label}: name은 영어 소문자·숫자·하이픈만 쓰고, 하이픈으로 시작·끝나거나 연달아 쓰지 않습니다: {name}")
        if name != skill_dir.name:
            errors.append(f"{label}: 폴더 이름과 name이 같아야 합니다(name: {name})")

    description = meta.get("description")
    if not isinstance(description, str) or not description.strip():
        errors.append(f"{label}: description이 없습니다")
    else:
        if len(description) > 1024:
            errors.append(f"{label}: description은 1024자 이내여야 합니다({len(description)}자)")
        if "<" in description or ">" in description:
            errors.append(f"{label}: description에는 꺾쇠괄호(< >)를 쓰지 않습니다. 일부 업로드 검증이 거부합니다")

    compatibility = meta.get("compatibility")
    if compatibility is not None and (not isinstance(compatibility, str) or len(compatibility) > 500):
        errors.append(f"{label}: compatibility는 500자 이내 문자열이어야 합니다")

    metadata = meta.get("metadata")
    if metadata is not None and not isinstance(metadata, dict):
        errors.append(f"{label}: metadata는 '키: 값' 맵이어야 합니다")

    if not body.strip():
        errors.append(f"{label}: SKILL.md 본문이 비어 있습니다")
    return errors


def check_marketplace(skill_dirs):
    """배포 목록이 있으면 스킬 경로와 누락을 검사한다. (오류 목록, 경고 목록)을 돌려준다."""
    if not MARKETPLACE.is_file():
        return [], []
    label = "배포 목록(marketplace.json)"
    try:
        data = json.loads(MARKETPLACE.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return [f"{label}: JSON을 읽을 수 없습니다: {exc}"], []

    errors, warnings = [], []
    if not isinstance(data.get("name"), str) or not data["name"]:
        errors.append(f"{label}: name이 없습니다")
    owner = data.get("owner")
    if not isinstance(owner, dict) or not owner.get("name"):
        errors.append(f"{label}: owner.name이 없습니다")
    plugins = data.get("plugins")
    if not isinstance(plugins, list) or not plugins:
        return errors + [f"{label}: plugins가 비어 있습니다"], warnings

    skills_root = (ROOT / "skills").resolve()
    all_skills = {d.name for d in skill_dirs}
    listed, names = set(), set()
    for index, plugin in enumerate(plugins):
        where = f"{label} plugins[{index}]"
        if not isinstance(plugin, dict):
            errors.append(f"{where}: 항목이 객체가 아닙니다")
            continue
        name = plugin.get("name")
        if not isinstance(name, str) or not NAME_RE.match(name):
            errors.append(f"{where}: 플러그인 name은 영어 소문자·숫자·하이픈으로 씁니다: {name}")
        elif name in names:
            errors.append(f"{where}: 플러그인 이름이 겹칩니다: {name}")
        else:
            names.add(name)
            where = f"{label} 플러그인 {name}"
        if "version" in plugin:
            warnings.append(f"{where}: version을 적으면 그 값을 바꿀 때까지 사용자가 새 커밋을 받지 못합니다")
        if plugin.get("source") not in ("./", "."):
            continue  # 저장소 루트가 아닌 소스는 이 저장소의 skills/를 담지 않는다
        skills = plugin.get("skills")
        if skills is None:
            listed |= all_skills  # 목록이 없으면 skills/ 전체를 담는다
            continue
        if isinstance(skills, str):
            skills = [skills]
        if not isinstance(skills, list) or not skills:
            errors.append(f"{where}: skills는 ./skills/<이름> 경로의 목록이어야 합니다")
            continue
        for path in skills:
            target = (ROOT / path).resolve() if isinstance(path, str) else None
            if not isinstance(path, str) or not path.startswith("./") \
                    or target.parent != skills_root or not (target / "SKILL.md").is_file():
                errors.append(f"{where}: skills/ 아래 스킬 폴더를 가리키지 않습니다: {path}")
                continue
            listed.add(target.name)

    for missing in sorted(all_skills - listed):
        errors.append(f"{label}: 스킬 {missing}이(가) 어느 플러그인에도 들어 있지 않습니다. 알맞은 플러그인의 skills에 ./skills/{missing}을 추가하세요")
    return errors, warnings


def main(argv):
    if argv:
        targets = [Path(a).resolve() for a in argv]
    else:
        skills_root = ROOT / "skills"
        targets = sorted(p for p in skills_root.iterdir() if p.is_dir()) if skills_root.is_dir() else []
    if not targets:
        print("검사할 스킬 폴더가 없습니다.", file=sys.stderr)
        return 1

    failed = 0
    for skill_dir in targets:
        errors = check_skill(skill_dir)
        if errors:
            failed += 1
            for line in errors:
                print(f"FAIL {line}")
        else:
            print(f"ok   {skill_dir.name}")
    print(f"\n스킬 {len(targets)}개 중 {len(targets) - failed}개 통과")

    if not argv:
        mp_errors, mp_warnings = check_marketplace(targets)
        for line in mp_warnings:
            print(f"경고 {line}")
        for line in mp_errors:
            print(f"FAIL {line}")
        if MARKETPLACE.is_file() and not mp_errors:
            print("ok   배포 목록(marketplace.json)")
        if mp_errors:
            failed += 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
