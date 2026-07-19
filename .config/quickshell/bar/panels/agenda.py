#!/usr/bin/env python3
"""Optional calendar/task adapters for CalendarPanel."""
from __future__ import annotations
import json
import shutil
import subprocess


def run(command: list[str]) -> str:
    try:
        return subprocess.run(command, capture_output=True, text=True, timeout=2, check=False).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


events: list[dict[str, str]] = []
if shutil.which("khal"):
    raw = run(["khal", "list", "today", "7d", "--format", "{start-time}|{title}|{location}"])
    for line in raw.splitlines():
        if "|" not in line:
            continue
        start, title, *location = line.split("|")
        events.append({"time": start.strip(), "title": title.strip(), "detail": "|".join(location).strip(), "kind": "event"})

tasks: list[dict[str, str]] = []
if shutil.which("task"):
    try:
        data = json.loads(run(["task", "status:pending", "due.before:tomorrow", "export"]) or "[]")
        for task in data[:5]:
            tasks.append({"time": "Task", "title": task.get("description", "Untitled"), "detail": task.get("project", ""), "kind": "task"})
    except json.JSONDecodeError:
        pass

print(json.dumps({"items": (events + tasks)[:8], "hasCalendar": bool(shutil.which("khal")), "hasTasks": bool(shutil.which("task"))}))
