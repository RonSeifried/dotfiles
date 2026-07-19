#!/usr/bin/env python3
"""Stream a Gemini curl request without exposing credentials or prompts in argv."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from urllib.parse import urlparse


ALLOWED_HOST = "generativelanguage.googleapis.com"


def main() -> int:
    try:
        request = json.load(sys.stdin)
        api_key = request["apiKey"]
        body = request["body"]
        url = request["url"]
    except (json.JSONDecodeError, KeyError, TypeError) as error:
        print(f"invalid request payload: {error}", file=sys.stderr)
        return 2

    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.hostname != ALLOWED_HOST:
        print("refusing unexpected Gemini endpoint", file=sys.stderr)
        return 2
    if not isinstance(api_key, str) or not api_key or not isinstance(body, str):
        print("missing API key or request body", file=sys.stderr)
        return 2

    header_path: Path | None = None
    try:
        descriptor, raw_path = tempfile.mkstemp(prefix="gemini-header-")
        header_path = Path(raw_path)
        with os.fdopen(descriptor, "w", encoding="utf-8") as header:
            header.write("Content-Type: application/json\n")
            header.write(f"X-goog-api-key: {api_key}\n")
        os.chmod(header_path, 0o600)

        process = subprocess.Popen(
            [
                "curl", "-sS", "--no-buffer",
                "-H", f"@{header_path}",
                "-X", "POST",
                "--data-binary", "@-",
                url,
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=None,
            text=True,
        )
        assert process.stdin is not None
        assert process.stdout is not None
        process.stdin.write(body)
        process.stdin.close()
        for line in process.stdout:
            sys.stdout.write(line)
            sys.stdout.flush()
        return process.wait()
    finally:
        if header_path is not None:
            header_path.unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
