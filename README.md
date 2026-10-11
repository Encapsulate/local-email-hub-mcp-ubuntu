# Local Email Hub MCP — Ubuntu Edition

A privacy-focused, local email MCP server for Ubuntu and other systemd-based Linux distributions. It lets trusted AI clients search and read Gmail, create drafts and reply drafts, and queue outbound messages behind a separate human approval step.

The service binds only to `127.0.0.1`. It does not expose a send-now or approval tool to the model.

> **Upstream credit:** This project is an Ubuntu/Gmail port of [Knappen/local-email-hub-mcp](https://github.com/Knappen/local-email-hub-mcp). Knappen created the original Windows/classic-Outlook design, including its human approval boundary, durable queue, idempotency behavior, crash-to-unknown rule, and untrusted-email handling. This repository is a GitHub fork so that relationship remains visible. The Linux port replaces Outlook COM and PowerShell with IMAP/SMTP, Python, Bash, and a hardened systemd user service.

## Security model in one minute

- Email is hostile input. Search/read results carry an explicit prompt-injection warning.
- The server listens only on `http://127.0.0.1:18477/mcp`.
- MCP can create drafts or queue mail, but cannot approve or immediately send anything.
- A person must run `email-hub-approve`, inspect the immutable recipients/subject/body, and type an exact `SEND N` confirmation.
- Ambiguous SMTP failures become `unknown` and are never automatically retried.
- Credentials are entered locally with a hidden prompt and stored in a mode-`0600` file. They are never returned by an MCP tool or written to logs.
- Queue rows necessarily contain unsent message content. The state directory is private and excluded from Git.

Read [Privacy](docs/PRIVACY.md), [Threat model](docs/THREAT-MODEL.md), and [Architecture](docs/ARCHITECTURE.md) before connecting a sensitive mailbox.

## Current scope

Version 0.1 targets Gmail with a Google app password:

- Ubuntu 22.04, 24.04, or a comparable systemd-based Linux distribution
- Python 3.11 or newer
- Gmail or Google Workspace account with IMAP available
- Google two-step verification and an app password
- A local MCP client supporting Streamable HTTP

The mail backend is standards-based IMAP/SMTP, but the setup assistant currently supplies Gmail hostnames and the Gmail Drafts folder. Generic-provider and OAuth flows are future work.

## Tools

| Tool | Behavior |
|---|---|
| `email_health` | Checks configuration, IMAP connectivity, database integrity, backups, and queue counts. |
| `email_accounts` | Returns the configured account identity, never its credential. |
| `email_folders` | Lists IMAP folders. |
| `email_search` | Searches the selected folder and returns bounded message metadata. |
| `email_read` | Returns bounded plain-text content and attachment metadata. It never saves or opens attachments. |
| `email_create_draft` | Appends a new Gmail draft; never sends. |
| `email_create_reply_draft` | Creates a reply or reply-all draft; never sends. |
| `email_queue_send` | Stores an immutable, idempotent outbound request as `pending`. |
| `email_queue_status` | Reports queue state without approving or changing it. |

## Install on Ubuntu

Install the OS prerequisite if it is missing:

```bash
sudo apt update
sudo apt install -y git python3 python3-venv
```

Clone the Ubuntu fork and run its user-local installer:

```bash
git clone https://github.com/Encapsulate/local-email-hub-mcp-ubuntu.git
cd local-email-hub-mcp-ubuntu
./install.sh
```

The installer:

1. creates an isolated `.venv`;
2. installs the locked Python project dependencies;
3. creates private config/state directories;
4. installs `email-hub-configure`, `email-hub-status`, and `email-hub-approve` under `~/.local/bin`;
5. installs and enables a hardened per-user `linux-email-hub.service`;
6. performs real MCP initialize, list-tools, and health checks.

It does not ask for, discover, copy, or transmit mailbox credentials.

## Configure Gmail privately

First create a Google app password for this local service. Do not use your normal Google password, and never paste an app password into an AI chat, shell history, issue, log, or screenshot.

Run:

```bash
email-hub-configure
```

The local program prompts for:

- Gmail address;
- optional display name;
- Google app password using a hidden terminal prompt.

Before saving anything it authenticates to Gmail IMAP and SMTP without sending mail. On success it writes:

```text
~/.config/linux-email-hub/config.env       mode 0600, non-secret settings
~/.config/linux-email-hub/credentials.env  mode 0600, app password
```

Then it restarts the user service. Verify:

```bash
email-hub-status
systemctl --user status linux-email-hub.service
```

`email-hub-status` masks the account address and never prints the credential.

## Connect clients

The endpoint is:

```text
http://127.0.0.1:18477/mcp
```

### Codex CLI or IDE extension

```bash
codex mcp add email-hub --url http://127.0.0.1:18477/mcp
codex mcp list
```

Start a new Codex session after registration so it reloads the tool inventory.

### Hermes Agent

```bash
hermes mcp add --url http://127.0.0.1:18477/mcp --connect-timeout 30 email-hub
hermes mcp test email-hub
```

Answer **No** when asked whether server authentication is required, then enable the tools. Start a new Hermes session afterward.

### Other clients

Choose **MCP / Streamable HTTP**, enter the loopback URL above, and select no transport authentication. Only connect trusted local clients. Do not replace `127.0.0.1` with `0.0.0.0`, a LAN address, or a public tunnel.

## Everyday workflow

Read/search and draft calls happen through the MCP client. Sending is deliberately split:

1. The model calls `email_queue_send`.
2. The durable queue records recipients, subject, body, and an idempotency key as `pending`.
3. In a separate local terminal, run `email-hub-approve`.
4. Read the complete immutable snapshot.
5. Select one entry or all entries.
6. Type the exact displayed `SEND N` confirmation.
7. The background worker logs in to SMTP, changes the row to `sending` immediately before submission, and records `sent` only after confirmed success.

If the process or network fails after submission may have begun, the row becomes `unknown`. Check Gmail Sent mail manually before deciding whether to create a new queue item.

## Data locations

| Path | Contents |
|---|---|
| `~/.config/linux-email-hub/config.env` | Account identity and Gmail server settings. |
| `~/.config/linux-email-hub/credentials.env` | Gmail app password; mode 0600. |
| `~/.local/share/linux-email-hub/email-hub.sqlite3` | Queue and minimal audit metadata; mode 0600. |
| `~/.local/share/linux-email-hub/backups/` | Seven newest consistent SQLite backups. |
| `~/.local/share/linux-email-hub/email-hub.log` | Service lifecycle/errors without message content. |
| `~/.config/systemd/user/linux-email-hub.service` | Per-user hardened service definition. |

No mailbox data, credentials, runtime database, logs, or local paths belong in this repository.

## Reliability behavior

- SQLite WAL permits reads while queue changes commit.
- `synchronous=FULL` favors durable queue state over throughput.
- Backups run at startup and every six hours; the newest seven are retained.
- Idempotency keys prevent repeated tool calls from creating duplicate queue entries.
- Safe pre-submit connection/login failures retry with capped exponential backoff.
- Failures during SMTP submission are ambiguous and become non-retrying `unknown`.
- Any orphaned `sending` row becomes `unknown` on service startup.
- Streamable HTTP is stateless; durable state stays in SQLite and Gmail.

## Maintenance

```bash
systemctl --user restart linux-email-hub.service
journalctl --user -u linux-email-hub.service -f
email-hub-status
```

Update without touching credentials or state:

```bash
git pull --ff-only
./install.sh
```

Uninstall the service and commands while preserving private configuration/state:

```bash
./uninstall.sh
```

To remove retained data too, review and delete `~/.config/linux-email-hub/` and `~/.local/share/linux-email-hub/` yourself. They are intentionally not deleted automatically.

## Development and tests

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -e '.[dev]'
.venv/bin/python -m py_compile linux_email_hub.py approve.py configure.py verify_mcp.py
.venv/bin/pytest -q
```

Tests use `example.invalid` and temporary databases. They do not authenticate, create Gmail drafts, or send mail.

## Important limitations

- Loopback binding is not per-process authentication. Any process running as the same user may call the endpoint.
- The approval prompt is a workflow interlock, not a sandbox against arbitrary shell/filesystem access as the same user.
- Mail-enabled sessions should not also receive unrestricted code execution when handling untrusted messages.
- HTML is not rendered, but a bounded MIME message segment is fetched to extract plain text and attachment metadata.
- This project does not provide malware scanning, multi-user authorization, guaranteed delivery receipts, or protection for a compromised Linux account.

## Attribution and license

This Ubuntu port is maintained by Encapsulate and remains a fork of [Knappen/local-email-hub-mcp](https://github.com/Knappen/local-email-hub-mcp). The original concept and Windows implementation are credited to Knappen and the Local Email Hub contributors.

MIT licensed. The original copyright notice is preserved in [LICENSE](LICENSE).
