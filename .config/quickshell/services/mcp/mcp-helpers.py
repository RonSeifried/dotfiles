#!/usr/bin/env python3
"""JSON wrapper around `docker mcp` for the Quickshell MCP Manager.

All subcommands print a single JSON value on stdout.
On failure: prints {"error": "<msg>"} and exits non-zero.

Subcommands:
  catalog                            → [{name, description}]
  servers                            → [{name, enabled}]
  server-inspect <name>              → {name, description, author, repo, license,
                                        tools: [{name, enabled, description}],
                                        secrets: [{catalogKey, envName}]}
  server-enable <name>               → {ok: bool}
  server-disable <name>              → {ok: bool}
  clients                            → [{name, connected}]
  client-connect <name>              → {ok, message}
  client-disconnect <name>           → {ok, message}
  tools                              → [{name, description}]
  tool-inspect <name>                → {raw: "<text>"}
  secrets                            → {<catalogKey>: true}    (presence only)
  secret-set <catalogKey> <value>    → {ok: bool}              (value via stdin if "-")
  secret-rm <catalogKey>             → {ok: bool}
  ensure-gateway-config              → {ok: bool, patched: bool}
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HOME = Path(os.environ.get("HOME", str(Path.home())))
SECRETS_ENV = Path(os.environ.get("SECRETS_ENV", HOME / ".docker/mcp/secrets.env"))
CATALOG_FILE = Path(
    os.environ.get("CATALOG_FILE", HOME / ".docker/mcp/catalogs/docker-mcp.yaml")
)
CLAUDE_JSON = Path(os.environ.get("CLAUDE_JSON", HOME / ".claude.json"))

SUPPORTED_CLIENTS = [
    "claude-code", "claude-desktop", "cline", "codex", "continue", "crush",
    "cursor", "gemini", "goose", "gordon", "kiro", "lmstudio", "opencode",
    "sema4", "vscode", "zed",
]

ANSI = re.compile(r"\x1b\[[0-9;]*m")


def strip_ansi(s: str) -> str:
    return ANSI.sub("", s)


def run(*args: str, check: bool = False, timeout: int = 90) -> subprocess.CompletedProcess:
    return subprocess.run(
        list(args),
        capture_output=True,
        text=True,
        check=check,
        timeout=timeout,
    )


def emit(value) -> None:
    json.dump(value, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def die(msg: str, code: int = 1) -> None:
    emit({"error": msg})
    sys.exit(code)


# ── catalog ───────────────────────────────────────────────────
def cmd_catalog():
    cp = run("docker", "mcp", "catalog", "show")
    if cp.returncode != 0:
        die(strip_ansi(cp.stderr).strip() or "catalog show failed")
    # Names are ANSI-bold ("\x1b[1m<name>\x1b[0m") indented 2 spaces;
    # descriptions follow at indent 4. Parse before stripping ANSI.
    items: list[dict] = []
    cur_name = ""
    cur_desc_parts: list[str] = []

    def flush():
        if cur_name:
            items.append({
                "name": cur_name,
                "description": " ".join(cur_desc_parts).strip(),
            })

    for raw in cp.stdout.splitlines():
        m = re.match(r"^  \x1b\[1m([^\x1b]+)\x1b\[0m\s*$", raw)
        if m:
            flush()
            cur_name = m.group(1).strip()
            cur_desc_parts = []
            continue
        if cur_name and raw.startswith("    "):
            cur_desc_parts.append(strip_ansi(raw).strip())
    flush()
    # Drop header artefacts
    items = [
        it for it in items
        if it["name"] and "MCP Server Directory" not in it["name"]
    ]
    emit(items)


# ── servers (enabled) ─────────────────────────────────────────
def cmd_servers():
    cp = run("docker", "mcp", "server", "ls")
    if cp.returncode != 0:
        die(strip_ansi(cp.stderr).strip() or "server ls failed")
    items = []
    for line in strip_ansi(cp.stdout).splitlines():
        m = re.match(r"^([a-z][a-z0-9_-]*)\b", line)
        if m:
            items.append({"name": m.group(1), "enabled": True})
    emit(items)


# ── server inspect (parses docker mcp + catalog yaml) ─────────
def _parse_readme(readme: str) -> dict:
    def grab(pat: str) -> str:
        m = re.search(pat, readme)
        return m.group(1).strip() if m else ""

    return {
        "author": grab(r"\*\*Author\*\*\|.*?\[([^\]]+)\]"),
        "repo": grab(r"\*\*Repository\*\*\|(https://[^\s|]+)"),
        "license": grab(r"\*\*Licen[cs]e\*\*\|([^\|\n]+)"),
        "description": grab(r"\*\*Description\*\*\|([^\|\n]+)"),
    }


def _catalog_secrets(server: str) -> list[dict]:
    """Returns [{catalogKey, envName}] for a server from the catalog yaml."""
    if not CATALOG_FILE.exists():
        return []
    try:
        lines = CATALOG_FILE.read_text().splitlines(keepends=True)
    except OSError:
        return []

    out: list[dict] = []
    in_server = False
    server_indent: int | None = None
    in_secrets = False
    secrets_indent: int | None = None

    i = 0
    while i < len(lines):
        raw = lines[i].rstrip("\n")
        stripped = raw.lstrip()
        indent = len(raw) - len(stripped)

        if not in_server:
            if re.match(r"\s+" + re.escape(server) + r":\s*$", raw):
                in_server = True
                server_indent = indent
            i += 1
            continue

        if not stripped or stripped.startswith("#"):
            i += 1
            continue
        if server_indent is not None and indent <= server_indent and stripped:
            break

        if re.match(r"secrets:\s*$", stripped) and not in_secrets:
            in_secrets = True
            secrets_indent = indent
            i += 1
            continue

        if in_secrets:
            if (
                secrets_indent is not None
                and indent <= secrets_indent
                and stripped
                and not stripped.startswith("-")
            ):
                in_secrets = False
                continue
            if stripped.startswith("- name:"):
                cname = stripped[len("- name:"):].strip()
                env_val = ""
                j = i + 1
                while j < len(lines):
                    nxt_raw = lines[j].rstrip("\n")
                    nxt = nxt_raw.lstrip()
                    nxt_indent = len(nxt_raw) - len(nxt)
                    if nxt_indent <= indent and nxt and not nxt.startswith("-"):
                        break
                    m = re.match(r"env:\s*(\S.*)$", nxt)
                    if m:
                        env_val = m.group(1).strip()
                        break
                    j += 1
                if cname:
                    out.append({
                        "catalogKey": cname,
                        "envName": env_val or cname.upper().replace(".", "_"),
                    })
        i += 1

    return out


def _is_placeholder(val: str) -> bool:
    if not val:
        return True
    s = val.strip()
    if not s:
        return True
    if re.match(r"^<[^>]+>$", s):
        return True
    if re.match(r"^\$\{[^}]+\}$", s):
        return True
    if re.match(r"^your[_\-]", s, re.I):
        return True
    if re.search(r"\byour\b", s, re.I):
        return True
    if re.match(r"^(changeme|replace|example|placeholder|insert|todo|fill_in)", s, re.I):
        return True
    if re.search(r"\*{3,}", s):
        return True
    if re.match(r"^[_\-]+$", s):
        return True
    if re.match(r"^[a-z]{2,5}_[A-Z][A-Z0-9_]+$", s):
        return True
    return False


def _readme_secrets(readme: str) -> list[dict]:
    """Fallback: parse 'Use this MCP Server' JSON block for -e env names."""
    for block in re.findall(r"```json\s*(.*?)```", readme, re.DOTALL):
        try:
            cfg = json.loads(block)
        except json.JSONDecodeError:
            continue
        servers = cfg.get("mcpServers", {})
        for srv_cfg in servers.values():
            args = srv_cfg.get("args", [])
            env_obj = srv_cfg.get("env", {})
            dash_e = []
            for k, a in enumerate(args):
                if a == "-e" and k + 1 < len(args):
                    dash_e.append(args[k + 1])
            if not dash_e and not env_obj:
                continue
            names = [
                v for v in (dash_e or list(env_obj))
                if v not in env_obj or _is_placeholder(str(env_obj.get(v, "")))
            ]
            return [{"catalogKey": n, "envName": n} for n in sorted(names or dash_e)]
    return []


def cmd_server_inspect(name: str):
    cp = run("docker", "mcp", "server", "inspect", name)
    if cp.returncode != 0:
        die(strip_ansi(cp.stderr).strip() or f"inspect {name} failed")
    try:
        data = json.loads(cp.stdout)
    except json.JSONDecodeError as e:
        die(f"inspect: invalid JSON ({e})")

    readme = data.get("readme", "")
    meta = _parse_readme(readme)
    tools = []
    for t in data.get("tools", []):
        tools.append({
            "name": t.get("name", ""),
            "enabled": bool(t.get("enabled")),
            "description": t.get("description", "").split("\n", 1)[0],
        })

    secrets = _catalog_secrets(name) or _readme_secrets(readme)

    emit({
        "name": name,
        "description": meta["description"],
        "author": meta["author"],
        "repo": meta["repo"],
        "license": meta["license"],
        "tools": tools,
        "secrets": secrets,
    })


# ── enable / disable ──────────────────────────────────────────
def cmd_server_enable(name: str):
    cp = run("docker", "mcp", "server", "enable", name)
    if cp.returncode != 0:
        die(strip_ansi(cp.stderr).strip() or f"enable {name} failed")
    emit({"ok": True})


def cmd_server_disable(name: str):
    cp = run("docker", "mcp", "server", "disable", name)
    if cp.returncode != 0:
        die(strip_ansi(cp.stderr).strip() or f"disable {name} failed")
    emit({"ok": True})


# ── clients ───────────────────────────────────────────────────
def cmd_clients():
    cp = run("docker", "mcp", "client", "ls", "--global")
    text = strip_ansi(cp.stdout) if cp.returncode == 0 else ""
    items = []
    for cli in SUPPORTED_CLIENTS:
        m = re.search(r"●\s+" + re.escape(cli) + r":\s*(\w+)", text)
        items.append({
            "name": cli,
            "connected": bool(m and m.group(1).lower() == "connected"),
        })
    emit(items)


def cmd_client_connect(name: str):
    cp = run("docker", "mcp", "client", "connect", "--global", name)
    msg = strip_ansi((cp.stdout or "") + (cp.stderr or "")).strip()
    if cp.returncode != 0:
        die(msg or f"connect {name} failed")
    emit({"ok": True, "message": msg})


def cmd_client_disconnect(name: str):
    cp = run("docker", "mcp", "client", "disconnect", "--global", name)
    msg = strip_ansi((cp.stdout or "") + (cp.stderr or "")).strip()
    if cp.returncode != 0:
        die(msg or f"disconnect {name} failed")
    emit({"ok": True, "message": msg})


# ── tools ─────────────────────────────────────────────────────
def cmd_tools():
    cp = run("docker", "mcp", "tools", "ls")
    if cp.returncode != 0:
        die(strip_ansi(cp.stderr).strip() or "tools ls failed")
    items = []
    for line in strip_ansi(cp.stdout).splitlines():
        m = re.match(r"^\s*-\s+(\S+)\s*-?\s*(.*)$", line)
        if m:
            items.append({"name": m.group(1), "description": m.group(2).strip()})
    emit(items)


def cmd_tool_inspect(name: str):
    cp = run("docker", "mcp", "tools", "inspect", name)
    text = strip_ansi((cp.stdout or "") + (cp.stderr or ""))
    emit({"raw": text})


# ── secrets ───────────────────────────────────────────────────
def _ensure_secrets_file() -> None:
    SECRETS_ENV.parent.mkdir(parents=True, exist_ok=True)
    if not SECRETS_ENV.exists():
        SECRETS_ENV.touch()
    os.chmod(SECRETS_ENV, 0o600)


def _read_secrets() -> dict[str, str]:
    if not SECRETS_ENV.exists():
        return {}
    out: dict[str, str] = {}
    for line in SECRETS_ENV.read_text().splitlines():
        if not line or line.lstrip().startswith("#"):
            continue
        if "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v
    return out


def _write_secrets(d: dict[str, str]) -> None:
    _ensure_secrets_file()
    body = "".join(f"{k}={v}\n" for k, v in d.items())
    fd, tmp_path = tempfile.mkstemp(
        prefix=".secrets.env.", dir=str(SECRETS_ENV.parent)
    )
    try:
        with os.fdopen(fd, "w") as f:
            f.write(body)
        os.chmod(tmp_path, 0o600)
        os.replace(tmp_path, SECRETS_ENV)
    except Exception:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


def cmd_secrets():
    _ensure_secrets_file()
    emit({k: True for k in _read_secrets().keys()})


def cmd_secret_set(key: str, value: str):
    if value == "-":
        value = sys.stdin.read().rstrip("\n")
    d = _read_secrets()
    d[key] = value
    _write_secrets(d)
    emit({"ok": True})


def cmd_secret_rm(key: str):
    d = _read_secrets()
    d.pop(key, None)
    _write_secrets(d)
    emit({"ok": True})


# ── gateway config patch ──────────────────────────────────────
def cmd_ensure_gateway_config():
    if not CLAUDE_JSON.exists():
        emit({"ok": True, "patched": False})
        return
    try:
        d = json.loads(CLAUDE_JSON.read_text())
    except json.JSONDecodeError as e:
        die(f"~/.claude.json invalid JSON ({e})")

    mcp_docker = d.get("mcpServers", {}).get("MCP_DOCKER", {})
    if not mcp_docker:
        emit({"ok": True, "patched": False})
        return

    args = mcp_docker.get("args", [])
    if "--secrets" in args:
        emit({"ok": True, "patched": False})
        return

    args.extend(["--secrets", str(SECRETS_ENV)])
    mcp_docker["args"] = args
    d["mcpServers"]["MCP_DOCKER"] = mcp_docker
    CLAUDE_JSON.write_text(json.dumps(d, indent=2))
    emit({"ok": True, "patched": True})


# ── dispatch ──────────────────────────────────────────────────
COMMANDS = {
    "catalog":               (cmd_catalog, 0),
    "servers":               (cmd_servers, 0),
    "server-inspect":        (cmd_server_inspect, 1),
    "server-enable":         (cmd_server_enable, 1),
    "server-disable":        (cmd_server_disable, 1),
    "clients":               (cmd_clients, 0),
    "client-connect":        (cmd_client_connect, 1),
    "client-disconnect":     (cmd_client_disconnect, 1),
    "tools":                 (cmd_tools, 0),
    "tool-inspect":          (cmd_tool_inspect, 1),
    "secrets":               (cmd_secrets, 0),
    "secret-set":            (cmd_secret_set, 2),
    "secret-rm":             (cmd_secret_rm, 1),
    "ensure-gateway-config": (cmd_ensure_gateway_config, 0),
}


def main() -> None:
    if len(sys.argv) < 2:
        die("usage: mcp-helpers.py <command> [args...]")
    cmd = sys.argv[1]
    args = sys.argv[2:]
    if cmd not in COMMANDS:
        die(f"unknown command: {cmd}")
    fn, want = COMMANDS[cmd]
    if len(args) != want:
        die(f"{cmd}: expected {want} args, got {len(args)}")
    try:
        fn(*args)
    except subprocess.TimeoutExpired:
        die(f"{cmd}: timeout")
    except Exception as e:
        die(f"{cmd}: {e}")


if __name__ == "__main__":
    main()
