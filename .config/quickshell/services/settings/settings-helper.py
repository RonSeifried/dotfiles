#!/usr/bin/env python3
"""Small atomic JSON writer used by SettingsState."""
from __future__ import annotations

import json
import os
from pathlib import Path
import sys
import tempfile


def write(path: Path, raw: str) -> None:
    data = json.loads(raw)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def delete(path: Path) -> None:
    path.unlink(missing_ok=True)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "write-stdin":
        write(Path(sys.argv[2]), sys.stdin.read())
    elif len(sys.argv) == 3 and sys.argv[1] == "delete":
        delete(Path(sys.argv[2]))
    elif len(sys.argv) == 4 and sys.argv[1] == "write":
        # Non-sensitive settings may still use the compact argv form.
        write(Path(sys.argv[2]), sys.argv[3])
    else:
        raise SystemExit(
            "usage: settings-helper.py write PATH JSON | write-stdin PATH | delete PATH"
        )
