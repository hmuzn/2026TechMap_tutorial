#!/usr/bin/env python3
"""Keep Swift-DocC tutorial STEP focus synchronized with page scrolling."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


PATCH_MARKER = "__doccStepSyncV1"
LEGACY_PATCH_MARKER = "__doccStepSync"
PATCH_VERSION = "20260901-1"
SECTION_START = 'name:"SectionSteps"'
SECTION_END = '},props:{content:'
INDEX_SCRIPT_PATTERN = re.compile(
    r'(<script\b[^>]*\bsrc="[^"]*/js/index\.[^"]+?\.js)'
    r'(?:\?docc-step-sync=[^"]+)?("></script>)'
)


def topic_path(archive: Path) -> Path:
    candidates = [
        path
        for path in sorted((archive / "js").glob("topic.*.js"))
        if SECTION_START in path.read_text(encoding="utf-8")
        and "findClosestStepNode" in path.read_text(encoding="utf-8")
    ]
    if len(candidates) != 1:
        raise SystemExit(
            "SectionSteps가 들어 있는 DocC topic JavaScript를 하나만 찾아야 합니다: "
            f"{len(candidates)}개"
        )
    return candidates[0]


def section_bounds(document: str, path: Path) -> tuple[int, int]:
    marker = document.find(SECTION_START)
    if marker < 0:
        raise SystemExit(f"SectionSteps를 찾지 못했습니다: {path}")
    start = document.rfind("var ", 0, marker)
    end = document.find(SECTION_END, marker)
    if start < 0 or end < 0:
        raise SystemExit(f"SectionSteps 경계를 찾지 못했습니다: {path}")
    return start, end + 1


def replace_once(document: str, old: str, new: str, path: Path) -> str:
    count = document.count(old)
    if count != 1:
        raise SystemExit(
            f"DocC STEP 패치 대상이 하나여야 합니다: {path} ({old!r}, {count}개)"
        )
    return document.replace(old, new, 1)


def patched_section(section: str, path: Path) -> str:
    if PATCH_MARKER in section:
        return section
    if LEGACY_PATCH_MARKER in section:
        legacy_required = (
            ".35*window.innerHeight",
            "null!==t&&t!==this.activeStep&&this.onFocus(t)",
            "this.findClosestStepNode()",
        )
        if any(value not in section for value in legacy_required):
            raise SystemExit(f"기존 DocC STEP 패치 형식을 확인할 수 없습니다: {path}")
        migrated = section.replace(LEGACY_PATCH_MARKER, PATCH_MARKER)
        if PATCH_MARKER not in migrated:
            raise SystemExit(f"기존 DocC STEP 패치를 마이그레이션하지 못했습니다: {path}")
        return migrated

    mounted_pattern = re.compile(
        r"async mounted\(\)\{await\(0,([A-Za-z_$][\w$]*\.[A-Za-z_$][\w$]*)\)"
        r"\(8\),this\.findClosestStepNode\(\)\},methods:\{"
    )
    match = mounted_pattern.search(section)
    if match is None:
        raise SystemExit(f"SectionSteps mounted hook을 찾지 못했습니다: {path}")

    mounted = (
        f"async mounted(){{await(0,{match.group(1)})(8),"
        "this.findClosestStepNode(),"
        f"this.{PATCH_MARKER}=()=>{{this.{PATCH_MARKER}Queued||"
        f"(this.{PATCH_MARKER}Queued=!0,requestAnimationFrame(()=>{{"
        f"this.{PATCH_MARKER}Queued=!1,this.findClosestStepNode()}}))}},"
        f'window.addEventListener("scroll",this.{PATCH_MARKER},{{passive:!0}}),'
        f'window.addEventListener("resize",this.{PATCH_MARKER},{{passive:!0}})'
        "},"
        "beforeDestroy(){"
        f'window.removeEventListener("scroll",this.{PATCH_MARKER}),'
        f'window.removeEventListener("resize",this.{PATCH_MARKER})'
        "},methods:{"
    )
    section = section[: match.start()] + mounted + section[match.end() :]
    section = replace_once(
        section,
        ".333*window.innerHeight",
        ".35*window.innerHeight",
        path,
    )
    section = replace_once(
        section,
        "null!==t&&this.onFocus(t)",
        "null!==t&&t!==this.activeStep&&this.onFocus(t)",
        path,
    )
    section = replace_once(
        section,
        "this.onFocus(s)",
        "this.findClosestStepNode()",
        path,
    )
    return section


def topic_update(path: Path) -> tuple[Path, str, str]:
    original = path.read_text(encoding="utf-8")
    start, end = section_bounds(original, path)
    section = original[start:end]
    updated_section = patched_section(section, path)
    updated = original[:start] + updated_section + original[end:]
    return path, original, updated


def runtime_path(archive: Path, topic: Path) -> Path:
    topic_hash = topic.stem.removeprefix("topic.")
    candidates = [
        path
        for path in sorted((archive / "js").glob("index.*.js"))
        if topic_hash in path.read_text(encoding="utf-8")
    ]
    if len(candidates) != 1:
        raise SystemExit(
            "DocC topic chunk를 가리키는 index JavaScript를 하나만 찾아야 합니다: "
            f"{len(candidates)}개"
        )
    return candidates[0]


def runtime_update(path: Path) -> tuple[Path, str, str]:
    original = path.read_text(encoding="utf-8")
    version_suffix = f".js?docc-step-sync={PATCH_VERSION}"
    if version_suffix in original:
        return path, original, original

    suffix_pattern = re.compile(
        r'\+"\.js(?:\?docc-step-sync=[^"]+)?"\}\}\(\)'
    )
    replacement = f'+"{version_suffix}"}}}}()'
    updated, count = suffix_pattern.subn(replacement, original)
    if count != 1:
        raise SystemExit(
            f"DocC 동적 JavaScript 경로가 하나여야 합니다: {path} ({count}개)"
        )
    return path, original, updated


def index_updates(archive: Path) -> list[tuple[Path, str, str]]:
    paths = sorted(archive.rglob("index.html"))
    if not paths:
        raise SystemExit(f"DocC index.html을 찾지 못했습니다: {archive}")

    updates = []
    for path in paths:
        original = path.read_text(encoding="utf-8")
        updated, count = INDEX_SCRIPT_PATTERN.subn(
            rf'\1?docc-step-sync={PATCH_VERSION}\2', original
        )
        if count != 1:
            raise SystemExit(
                f"DocC index JavaScript 태그가 하나여야 합니다: {path} ({count}개)"
            )
        updates.append((path, original, updated))
    return updates


def write_updates(updates: list[tuple[Path, str, str]]) -> int:
    for path, original, _ in updates:
        if path.read_text(encoding="utf-8") != original:
            raise SystemExit(f"파일이 처리 중 변경되었습니다. 다시 실행하세요: {path}")

    changed = 0
    for path, original, updated in updates:
        if updated == original:
            continue
        path.write_text(updated, encoding="utf-8")
        changed += 1
    return changed


def check(archive: Path) -> None:
    topic = topic_path(archive)
    document = topic.read_text(encoding="utf-8")
    start, end = section_bounds(document, topic)
    section = document[start:end]
    required = (
        PATCH_MARKER,
        ".35*window.innerHeight",
        "null!==t&&t!==this.activeStep&&this.onFocus(t)",
        "this.findClosestStepNode()",
    )
    for value in required:
        if value not in section:
            raise SystemExit(f"DocC STEP 동기화 패치가 없습니다: {topic} ({value})")
    if ".333*window.innerHeight" in section or "this.onFocus(s)" in section:
        raise SystemExit(f"구버전 DocC STEP 선택 로직이 남아 있습니다: {topic}")

    runtime = runtime_path(archive, topic)
    runtime_document = runtime.read_text(encoding="utf-8")
    if f'.js?docc-step-sync={PATCH_VERSION}' not in runtime_document:
        raise SystemExit(f"DocC 동적 JavaScript 캐시 무효화가 없습니다: {runtime}")

    paths = sorted(archive.rglob("index.html"))
    for path in paths:
        document = path.read_text(encoding="utf-8")
        matches = INDEX_SCRIPT_PATTERN.findall(document)
        if len(matches) != 1 or f"?docc-step-sync={PATCH_VERSION}" not in document:
            raise SystemExit(f"DocC index JavaScript 캐시 무효화가 없습니다: {path}")

    print(f"DocC STEP-스크롤 동기화 검증: index.html {len(paths)}개")


def patch(archive: Path) -> None:
    topic = topic_path(archive)
    runtime = runtime_path(archive, topic)
    updates = [topic_update(topic), runtime_update(runtime), *index_updates(archive)]
    path_count = len(updates) - 2
    changed = write_updates(updates) > 0
    state = "적용" if changed else "이미 최신"
    print(f"DocC STEP-스크롤 동기화 {state}: index.html {path_count}개")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="렌더링된 DocC archive의 튜토리얼 STEP 선택을 스크롤과 동기화합니다."
    )
    parser.add_argument("archive", type=Path, help=".doccarchive 또는 .docc-build 경로")
    parser.add_argument("--check", action="store_true", help="패치 적용 상태를 검사합니다.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    archive = args.archive.resolve()
    if args.check:
        check(archive)
    else:
        patch(archive)


if __name__ == "__main__":
    main()
