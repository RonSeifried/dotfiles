#!/usr/bin/env python3
"""Format docker mcp server inspect JSON for rofi navigation.
Modes:
  overview           — compact header + metadata
  tools              — one line per tool (selectable)
  tool <toolname>    — full detail for one tool
"""
import json, sys, re, textwrap

data     = json.load(sys.stdin)
readme   = data.get('readme', '')
tools    = data.get('tools', [])
name     = sys.argv[1] if len(sys.argv) > 1 else 'server'
mode     = sys.argv[2] if len(sys.argv) > 2 else 'overview'
W        = 64

# ── markdown helpers ──────────────────────────────────────────
def strip_md(text):
    text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
    text = re.sub(r'\*(.+?)\*',     r'\1', text)
    text = re.sub(r'`([^`]+)`',     r'\1', text)
    text = re.sub(r'\[([^\]]+)\]\([^\)]+\)', r'\1', text)
    text = re.sub(r'!\[[^\]]*\]\([^\)]+\)',  '',     text)
    return text.strip()

def wrap(text, indent=2):
    return '\n'.join(
        textwrap.fill(text, width=W,
                      initial_indent=' ' * indent,
                      subsequent_indent=' ' * indent).splitlines()
    )

# ── secret extraction ─────────────────────────────────────────
def _is_placeholder(val):
    """Return True if val looks like a placeholder that the user must replace."""
    if not val:
        return True
    s = str(val).strip()
    if not s:
        return True
    # Angle-bracket templates: <YOUR_KEY>, <value>
    if re.match(r'^<[^>]+>$', s):
        return True
    # Shell variable: ${VAR_NAME}
    if re.match(r'^\$\{[^}]+\}$', s):
        return True
    # Starts with YOUR_ / your_ (case insensitive)
    if re.match(r'^your[_\-]', s, re.I):
        return True
    # Contains the word "your" anywhere: xoxb-your-bot-token, add-your-token
    if re.search(r'\byour\b', s, re.I):
        return True
    # Common placeholder words at the start
    if re.match(r'^(changeme|replace|example|placeholder|insert|todo|fill_in)', s, re.I):
        return True
    # Masked with asterisks: ntn_****, sk-*****, ****
    if re.search(r'\*{3,}', s):
        return True
    # All dashes/underscores: "---", "___"
    if re.match(r'^[_\-]+$', s):
        return True
    # Value is literally the env var name used as a placeholder value:
    # e.g. sk_STRIPE_SECRET_KEY  →  ^[a-z]{2,4}_[A-Z][A-Z0-9_]+$
    if re.match(r'^[a-z]{2,5}_[A-Z][A-Z0-9_]+$', s):
        return True
    # Slack-style format-example IDs: T01234567, C76543210
    if re.match(r'^[A-Z]\d{7,}$', s):
        return True
    # Comma-separated format-example IDs: "C01234567, C76543210"
    if re.match(r'^[A-Z]\w+(?:\s*,\s*[A-Z]\w+)+$', s) and re.search(r'\d', s):
        return True
    return False

def extract_secrets(readme):
    """
    Primary: parse the 'Use this MCP Server' JSON block.
    Extract env vars from docker -e args; keep only those whose
    env object value looks like a placeholder (needs user input).
    Fallback: backtick-quoted UPPER_CASE identifiers.
    """
    blocks = re.findall(r'```json\s*(.*?)```', readme, re.DOTALL)
    for block in blocks:
        try:
            cfg = json.loads(block)
        except json.JSONDecodeError:
            continue
        servers = cfg.get('mcpServers', {})
        for srv_cfg in servers.values():
            args    = srv_cfg.get('args', [])
            env_obj = srv_cfg.get('env', {})

            # collect vars passed via -e in docker args
            dash_e: list[str] = []
            for i, a in enumerate(args):
                if a == '-e' and i + 1 < len(args):
                    dash_e.append(args[i + 1])

            if not dash_e and not env_obj:
                continue

            # if var is missing from env_obj entirely → must be set by user
            secrets = sorted(
                v for v in (dash_e or list(env_obj))
                if v not in env_obj or _is_placeholder(env_obj.get(v, ''))
            )
            # if nothing filtered out, return all dash_e vars
            return secrets if secrets else sorted(dash_e)

    # Fallback: backtick regex
    candidates = re.findall(r'`([A-Z][A-Z0-9_]{2,})`', readme)
    filtered = sorted(set(
        v for v in candidates
        if re.search(r'(KEY|TOKEN|SECRET|PASSWORD|PASS|_ID$|_API|_URL)', v)
        or re.search(r'^(BRAVE|GITHUB|OPENAI|ANTHROPIC|AWS|GOOGLE|AZURE|SLACK|DISCORD)', v)
    ))
    return filtered or sorted(set(candidates))

# ── parse README ──────────────────────────────────────────────
def get_desc():
    past_h1 = False
    for line in readme.split('\n'):
        s = strip_md(line.strip())
        if line.startswith('# '): past_h1 = True; continue
        if past_h1 and s and not line.startswith(('#','|','-','!')):
            if len(s) > 15: return s
    return ''

author   = re.search(r'\*\*Author\*\*\|.*?\[([^\]]+)\]', readme)
repo     = re.search(r'\*\*Repository\*\*\|(https://[^\s|]+)', readme)
license_ = re.search(r'\*\*Licen[cs]e\*\*\|([^\|\n]+)', readme)
env_vars = extract_secrets(readme)

enabled_tools  = [t for t in tools if t.get('enabled')]
disabled_tools = [t for t in tools if not t.get('enabled')]

# ══════════════════════════════════════════════════════════════
if mode == 'secrets':
    for s in env_vars:
        print(s)

elif mode == 'overview':
    BAR = '─' * W
    print(BAR)
    print(f'  {name}')
    print(BAR)
    desc = get_desc()
    if desc:
        for line in wrap(desc).splitlines():
            print(line)
    print()
    if author:   print(f'  Author:   {author.group(1)}')
    if repo:     print(f'  Repo:     {repo.group(1)[:W-12]}')
    if license_: print(f'  License:  {license_.group(1).strip()}')
    print()
    print(BAR)
    print(f'  {len(enabled_tools)} / {len(tools)} tools enabled   ·   {len(env_vars)} secret(s)')
    print(BAR)

# ══════════════════════════════════════════════════════════════
elif mode == 'tools':
    for t in tools:
        st    = '✓' if t.get('enabled') else '○'
        tname = t['name']
        tdesc = strip_md(t.get('description', '').split('\n')[0])
        max_d = W - len(tname) - 8
        if len(tdesc) > max_d:
            tdesc = tdesc[:max_d-3] + '...'
        print(f'  {st}  {tname}  —  {tdesc}')

# ══════════════════════════════════════════════════════════════
elif mode == 'tool':
    tname = sys.argv[3] if len(sys.argv) > 3 else ''
    tool  = next((t for t in tools if t['name'] == tname), None)
    if not tool:
        print(f'Tool "{tname}" not found.')
        sys.exit(0)

    BAR  = '─' * W
    THIN = '·' * W
    st   = '✓  enabled' if tool.get('enabled') else '○  disabled'
    print(BAR)
    print(f'  {tool["name"]}   [{st}]')
    print(BAR)
    desc = strip_md(tool.get('description', ''))
    if desc:
        for line in wrap(desc).splitlines():
            print(line)
    args = tool.get('arguments', [])
    if args:
        print()
        print(THIN)
        print(f'  Parameters ({len(args)}):')
        print(THIN)
        for a in args:
            req  = '' if a.get('required', True) else '  (optional)'
            atyp = a.get('type', '')
            anam = a.get('name', '')
            adesc = strip_md(a.get('desc', a.get('description', '')))
            print(f'  •  {anam}  [{atyp}]{req}')
            if adesc:
                for line in wrap(adesc, indent=6).splitlines():
                    print(line)
    print(BAR)
