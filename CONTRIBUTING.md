# Contributing

Thank you for helping improve Local Email Hub MCP.

## Development

1. Use Windows with Python 3.12 for parity with release builds.
2. Create a virtual environment: `python -m venv .venv`.
3. Install: `.\.venv\Scripts\python.exe -m pip install -r requirements.txt`.
4. Run non-delivery tests: `.\.venv\Scripts\python.exe test_resilience.py`.
5. Run syntax checks: `.\.venv\Scripts\python.exe -m py_compile email_hub.py admin.py verify_mcp.py test_resilience.py`.

Live Outlook and MCP checks are optional for pull requests. Never run send tests against a real recipient.

## Privacy rules

Do not commit:

- Email addresses, names, subjects, bodies, or Outlook entry/store IDs.
- Screenshots of real mailboxes.
- SQLite state, WAL/SHM files, backups, or logs.
- OAuth tokens, passwords, API keys, authentication URLs, or environment dumps.
- Machine-specific user/profile paths.

Use addresses under `example.invalid` in tests and documentation.

## Pull requests

Explain the behavior change, security implications, failure behavior, and tests. Changes near the send boundary must preserve the rule that an ambiguous send is never automatically retried.

