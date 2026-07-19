#!/usr/bin/env python3
"""Atomically update one launcher frecency entry."""
import json
import os
import sys
import tempfile
import time
from pathlib import Path

path = Path(sys.argv[1])
key = sys.stdin.read() if sys.argv[2] == "-" else sys.argv[2]
path.parent.mkdir(parents=True, exist_ok=True)
try:
    data = json.loads(path.read_text()) if path.exists() else {}
except (OSError, json.JSONDecodeError):
    data = {}
item = data.get(key, {"count": 0, "last": 0})
data[key] = {"count": int(item.get("count", 0)) + 1, "last": int(time.time() * 1000)}
fd, tmp = tempfile.mkstemp(prefix="usage-", dir=path.parent)
try:
    with os.fdopen(fd, "w") as handle:
        json.dump(data, handle, separators=(",", ":"))
    os.replace(tmp, path)
finally:
    if os.path.exists(tmp):
        os.unlink(tmp)
