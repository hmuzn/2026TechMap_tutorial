#!/usr/bin/env python3
"""Add the desktop tutorial-code highlight helper to a DocC archive."""

from __future__ import annotations

import argparse
import hashlib
import html as html_module
import json
import re
from pathlib import Path


START_MARKER = "<!-- docc-step-highlight-scroll:start -->"
END_MARKER = "<!-- docc-step-highlight-scroll:end -->"
ROOT_REDIRECT_START_MARKER = "<!-- docc-root-redirect:start -->"
ROOT_REDIRECT_END_MARKER = "<!-- docc-root-redirect:end -->"
SCRIPT_NAME = "docc-step-highlight-scroll.js"
LANDING_PATH = "tutorials/spatialobjectdrums/"
BASE_URL_PATTERN = re.compile(r"\bvar baseUrl = (\"(?:[^\"\\]|\\.)*\")")


def index_paths(archive: Path) -> list[Path]:
    paths = sorted(archive.rglob("index.html"))
    if not paths:
        raise SystemExit(f"DocC index.html을 찾지 못했습니다: {archive}")
    return paths


def base_url(document: str, index_path: Path) -> str:
    match = BASE_URL_PATTERN.search(document)
    if match is None:
        raise SystemExit(f"DocC baseUrl을 찾지 못했습니다: {index_path}")

    base_url = json.loads(match.group(1))
    if not isinstance(base_url, str):
        raise SystemExit(f"DocC baseUrl이 문자열이 아닙니다: {index_path}")
    if not base_url.endswith("/"):
        base_url += "/"
    return base_url


def script_version(script_path: Path) -> str:
    return hashlib.sha256(script_path.read_bytes()).hexdigest()[:12]


def script_url(document: str, index_path: Path, version: str) -> str:
    return f"{base_url(document, index_path)}js/{SCRIPT_NAME}?v={version}"


def injected_block(url: str) -> str:
    escaped_url = html_module.escape(url, quote=True)
    return (
        f'{START_MARKER}\n'
        f'<script defer="defer" src="{escaped_url}"></script>\n'
        f'{END_MARKER}'
    )


def root_redirect_block(url: str) -> str:
    escaped_url = html_module.escape(url, quote=True)
    return (
        f'{ROOT_REDIRECT_START_MARKER}\n'
        f'<meta http-equiv="refresh" content="0;url={escaped_url}">\n'
        f'<link rel="canonical" href="{escaped_url}">\n'
        f'{ROOT_REDIRECT_END_MARKER}'
    )


def updated_document(document: str, block: str, index_path: Path) -> str:
    has_start = START_MARKER in document
    has_end = END_MARKER in document
    if has_start or has_end:
        if document.count(START_MARKER) != 1 or document.count(END_MARKER) != 1:
            raise SystemExit(f"기존 DocC 강조 이동 마커가 손상되었습니다: {index_path}")
        start = document.index(START_MARKER)
        end = document.index(END_MARKER, start) + len(END_MARKER)
        return document[:start] + block + document[end:]

    if "</body>" not in document:
        raise SystemExit(f"DocC index.html에 </body>가 없습니다: {index_path}")
    return document.replace("</body>", f"{block}</body>", 1)


def updated_root_redirect(document: str, block: str, index_path: Path) -> str:
    has_start = ROOT_REDIRECT_START_MARKER in document
    has_end = ROOT_REDIRECT_END_MARKER in document
    if has_start or has_end:
        if (
            document.count(ROOT_REDIRECT_START_MARKER) != 1
            or document.count(ROOT_REDIRECT_END_MARKER) != 1
        ):
            raise SystemExit(f"기존 DocC 루트 이동 마커가 손상되었습니다: {index_path}")
        start = document.index(ROOT_REDIRECT_START_MARKER)
        end = document.index(ROOT_REDIRECT_END_MARKER, start) + len(
            ROOT_REDIRECT_END_MARKER
        )
        return document[:start] + block + document[end:]

    if "</head>" not in document:
        raise SystemExit(f"DocC index.html에 </head>가 없습니다: {index_path}")
    return document.replace("</head>", f"{block}</head>", 1)


def write_if_unchanged(path: Path, original: str, updated: str) -> bool:
    if updated == original:
        return False
    if path.read_text(encoding="utf-8") != original:
        raise SystemExit(f"파일이 처리 중 변경되었습니다. 다시 실행하세요: {path}")
    path.write_text(updated, encoding="utf-8")
    return True


def install_script(archive: Path, script_path: Path) -> bool:
    if not script_path.is_file():
        raise SystemExit(f"강조 이동 스크립트를 찾지 못했습니다: {script_path}")

    script = script_path.read_text(encoding="utf-8")
    destination = archive / "js" / SCRIPT_NAME
    destination.parent.mkdir(parents=True, exist_ok=True)

    if destination.is_file():
        original = destination.read_text(encoding="utf-8")
        return write_if_unchanged(destination, original, script)

    destination.write_text(script, encoding="utf-8")
    return True


def validate_base_urls(paths: list[Path], expected: str | None) -> None:
    if expected is None:
        return
    if not expected.startswith("/") or not expected.endswith("/"):
        raise SystemExit("--expected-base-url은 /로 시작하고 끝나야 합니다.")
    for path in paths:
        actual = base_url(path.read_text(encoding="utf-8"), path)
        if actual != expected:
            raise SystemExit(
                f"DocC baseUrl이 공개 경로와 다릅니다: {path} ({actual!r}, 예상 {expected!r})"
            )


def inject(archive: Path, script_path: Path, expected_base_url: str | None) -> None:
    changed = install_script(archive, script_path)
    paths = index_paths(archive)
    validate_base_urls(paths, expected_base_url)
    version = script_version(script_path)

    for path in paths:
        original = path.read_text(encoding="utf-8")
        block = injected_block(script_url(original, path, version))
        updated = updated_document(original, block, path)
        changed = write_if_unchanged(path, original, updated) or changed

    root_index = archive / "index.html"
    root_document = root_index.read_text(encoding="utf-8")
    landing_url = base_url(root_document, root_index) + LANDING_PATH
    redirect_block = root_redirect_block(landing_url)
    updated_root = updated_root_redirect(root_document, redirect_block, root_index)
    changed = write_if_unchanged(root_index, root_document, updated_root) or changed

    state = "적용" if changed else "이미 최신"
    print(f"DocC STEP 강조 자동 이동 {state}: index.html {len(paths)}개")


def check(archive: Path, script_path: Path, expected_base_url: str | None) -> None:
    if not script_path.is_file():
        raise SystemExit(f"강조 이동 스크립트를 찾지 못했습니다: {script_path}")

    destination = archive / "js" / SCRIPT_NAME
    if not destination.is_file():
        raise SystemExit(f"DocC 강조 이동 JavaScript가 없습니다: {destination}")
    if destination.read_text(encoding="utf-8") != script_path.read_text(encoding="utf-8"):
        raise SystemExit(f"DocC 강조 이동 JavaScript가 소스와 다릅니다: {destination}")

    paths = index_paths(archive)
    validate_base_urls(paths, expected_base_url)
    version = script_version(script_path)
    for path in paths:
        document = path.read_text(encoding="utf-8")
        expected = injected_block(script_url(document, path, version))
        if document.count(START_MARKER) != 1 or document.count(END_MARKER) != 1:
            raise SystemExit(f"DocC 강조 이동 마커 수가 올바르지 않습니다: {path}")
        start = document.index(START_MARKER)
        end = document.index(END_MARKER, start) + len(END_MARKER)
        if document[start:end] != expected:
            raise SystemExit(f"DocC 강조 이동 script 경로가 올바르지 않습니다: {path}")

    root_index = archive / "index.html"
    root_document = root_index.read_text(encoding="utf-8")
    landing_url = base_url(root_document, root_index) + LANDING_PATH
    expected_redirect = root_redirect_block(landing_url)
    if (
        root_document.count(ROOT_REDIRECT_START_MARKER) != 1
        or root_document.count(ROOT_REDIRECT_END_MARKER) != 1
    ):
        raise SystemExit(f"DocC 루트 이동 마커 수가 올바르지 않습니다: {root_index}")
    redirect_start = root_document.index(ROOT_REDIRECT_START_MARKER)
    redirect_end = root_document.index(
        ROOT_REDIRECT_END_MARKER, redirect_start
    ) + len(ROOT_REDIRECT_END_MARKER)
    if root_document[redirect_start:redirect_end] != expected_redirect:
        raise SystemExit(f"DocC 루트 이동 경로가 올바르지 않습니다: {root_index}")

    print(f"DocC STEP 강조 자동 이동 검증: index.html {len(paths)}개")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="렌더링된 DocC archive에 데스크톱 STEP 강조 자동 이동을 추가합니다."
    )
    parser.add_argument("archive", type=Path, help=".doccarchive 또는 .docc-build 경로")
    parser.add_argument(
        "--script",
        type=Path,
        default=Path(__file__).with_name(SCRIPT_NAME),
        help="설치할 JavaScript 파일",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="모든 index.html과 설치된 JavaScript가 최신인지 검사합니다.",
    )
    parser.add_argument(
        "--expected-base-url",
        help="모든 index.html에서 요구할 공개 baseUrl (예: /my-repository/)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    archive = args.archive.resolve()
    script_path = args.script.resolve()
    if args.check:
        check(archive, script_path, args.expected_base_url)
    else:
        inject(archive, script_path, args.expected_base_url)


if __name__ == "__main__":
    main()
