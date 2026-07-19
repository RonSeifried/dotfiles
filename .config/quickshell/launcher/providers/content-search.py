#!/usr/bin/env python3
"""Fast local-content query backed by plocate, with an fd fallback.

The output is JSON so paths containing tabs/newlines cannot corrupt QML parsing.
This process is intentionally short-lived: plocate consults its mmap-friendly
index and normally returns before a recursive fd walk has visited one project.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.parse
import xml.etree.ElementTree as ET

HOME = Path.home().resolve()
SKIP = {".cache", ".git", "node_modules", "target", "__pycache__", ".venv"}
KIND_EXTENSIONS = {
    "Image": {"png", "jpg", "jpeg", "webp", "gif", "svg", "avif", "heic"},
    "Document": {"pdf", "odt", "doc", "docx", "txt", "md", "rtf", "epub"},
    "Code": {"py", "js", "ts", "tsx", "jsx", "qml", "kdl", "rs", "go", "c", "cpp", "lua", "sh"},
    "Audio": {"mp3", "flac", "ogg", "m4a", "wav", "opus"},
    "Video": {"mp4", "mkv", "webm", "mov", "avi"},
}


def candidates(query: str) -> list[str]:
    recent: list[str] = []
    xbel = HOME / ".local/share/recently-used.xbel"
    try:
        tree = ET.parse(xbel)
        for bookmark in tree.findall("{*}bookmark"):
            href = bookmark.get("href", "")
            if not href.startswith("file://"):
                continue
            path = urllib.parse.unquote(urllib.parse.urlparse(href).path)
            if query.casefold() in Path(path).name.casefold():
                recent.append(path)
    except (OSError, ET.ParseError):
        pass
    if shutil.which("plocate"):
        cmd = ["plocate", "--ignore-case", "--existing", "--limit", "240", "--", query]
        try:
            result = subprocess.run(cmd, text=True, capture_output=True, timeout=1.2, check=False)
            if result.returncode == 0:
                return recent + result.stdout.splitlines()
        except (OSError, subprocess.TimeoutExpired):
            pass
    cmd = ["fd", "--absolute-path", "--hidden", "--color", "never", "--max-results", "120"]
    for item in SKIP:
        cmd += ["--exclude", item]
    cmd += ["--", query, str(HOME)]
    try:
        result = subprocess.run(cmd, text=True, capture_output=True, timeout=1.8, check=False)
        return recent + result.stdout.splitlines()
    except (OSError, subprocess.TimeoutExpired):
        return []


def kind(path: Path) -> str:
    if path.is_dir():
        return "Folder"
    suffix = path.suffix.lower().lstrip(".")
    for label, extensions in KIND_EXTENSIONS.items():
        if suffix in extensions:
            return label
    return "File"


def score(path: Path, query: str) -> int:
    name = path.name.casefold()
    q = query.casefold()
    value = 450
    if name == q:
        value = 1050
    elif path.stem.casefold() == q:
        value = 980
    elif name.startswith(q):
        value = 810
    elif q in name:
        value = 670
    parts = path.parts
    value -= max(0, len(parts) - len(HOME.parts) - 3) * 18
    text = str(path)
    if any(f"/{entry}/" in text for entry in SKIP) or "/go/pkg/mod/" in text:
        value -= 700
    if "/Documents/" in text or "/Pictures/" in text or "/Downloads/" in text:
        value += 70
    try:
        age_days = max(0, (__import__("time").time() - path.stat().st_mtime) / 86400)
        value += max(0, int(90 - age_days))
    except OSError:
        pass
    return value


def main() -> None:
    query = " ".join(sys.argv[1:]).strip()
    if len(query) < 2:
        print("[]")
        return
    found: list[dict[str, object]] = []
    seen: set[str] = set()
    for raw in candidates(query):
        try:
            path = Path(raw).resolve()
            path.relative_to(HOME)
        except (OSError, ValueError):
            continue
        value = str(path)
        if value in seen or any(part in SKIP for part in path.parts):
            continue
        seen.add(value)
        found.append({"path": value, "title": path.name or value, "kind": kind(path), "score": score(path, query)})
    found.sort(key=lambda item: (-int(item["score"]), str(item["title"]).casefold()))
    print(json.dumps(found[:50], ensure_ascii=False))


if __name__ == "__main__":
    main()
