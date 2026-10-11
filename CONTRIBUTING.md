# Contributing

This repository is the Ubuntu/Gmail port of Knappen's Local Email Hub MCP. Changes should preserve the original project's conservative mail-safety model.

## Development

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -e '.[dev]'
.venv/bin/python -m py_compile linux_email_hub.py approve.py configure.py verify_mcp.py
.venv/bin/pytest -q
```

Tests must not authenticate to a real mailbox, create provider drafts, or send mail.

## Privacy rules

Never commit or post:

- real email addresses, names, subjects, bodies, headers, folder names, or message identifiers;
- screenshots of a real mailbox;
- credentials, app passwords, OAuth tokens, cookies, API keys, or auth URLs;
- SQLite state, WAL/SHM files, backups, logs, or configuration files;
- workstation usernames, home paths, LAN addresses, or environment dumps.

Use `example.invalid` and synthetic content. Pull requests should explain behavior, privacy/security impact, failure semantics, and tests. Any change near SMTP submission must preserve the rule that ambiguous sends are never automatically retried.

