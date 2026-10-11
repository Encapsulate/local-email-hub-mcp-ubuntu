# Local Email Hub MCP

A Windows-first, local Model Context Protocol (MCP) server that lets AI clients search and read mail, create new or reply drafts, and queue outbound messages through **classic Microsoft Outlook**.

The project is designed for local models and agents such as Qwen Code, Pi, Hermes Agent, DeepSeek Harness, OpenWebUI, and any MCP client that supports Streamable HTTP. Ollama and llama.cpp supply model inference; the agent or UI hosting the model supplies the MCP tools.

> [!IMPORTANT]
> Email is untrusted external input. This server returns message bodies as plain text with an explicit prompt-injection warning. Outbound messages cannot be approved through MCP: a person must review and approve the immutable queue snapshot in a separate local program.

## What it provides

- One Outlook-backed adapter for every Microsoft 365, Outlook.com, Gmail, or generic IMAP account already configured in the user's Outlook profile.
- A local Streamable HTTP MCP endpoint at `http://127.0.0.1:18477/mcp`.
- Nine tools for health, account/folder discovery, search/read, new drafts, reply drafts, durable send queueing, and queue status.
- SQLite durability using WAL mode, `synchronous=FULL`, integrity checks, and rotating consistent backups.
- Idempotency keys that prevent a repeated agent request from creating duplicate queue entries.
- Conservative crash handling: a process interruption during Outlook's `Send()` call becomes `unknown` and is never automatically retried.
- A human approval program outside the MCP tool surface.
- Turnkey PowerShell launchers, desktop shortcuts, startup recovery, client-registration helpers, and portable-bundle export.
- Loopback binding and DNS-rebinding protection, including a narrowly allowed `host.docker.internal` route for OpenWebUI on Docker Desktop.

## Requirements

- Windows 10 or 11.
- **Classic Outlook for Windows** installed and configured. The new Outlook app does not expose the COM automation API used here.
- Outlook must be usable by the same interactive Windows account running Email Hub.
- Python 3.11–3.14, unless using a portable bundle that contains `runtime\python`.
- At least one MCP-capable client.

No mailbox password, OAuth token, or app password is copied into Email Hub. Outlook remains responsible for provider authentication and synchronization.

## Quick start

Open PowerShell or Command Prompt in the cloned folder and run:

```powershell
.\Setup-EmailHub.cmd
```

The setup program:

1. Creates an isolated `.venv`.
2. Installs dependencies from `wheels\` when present, otherwise from PyPI.
3. Verifies Outlook access without printing mailbox addresses.
4. Starts the MCP service on loopback.
5. Performs a real MCP initialize/list-tools/health check.
6. Creates `Email Hub AIO`, `Email Hub Status`, and `Email Hub Approval` desktop shortcuts.
7. Creates a per-user Startup shortcut for recovery after sign-in.

Then register installed clients:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Register-EmailHub-Clients.ps1
```

Start a new client session—or use the client's MCP reload command—after registration.

## MCP endpoint

| Consumer | URL |
|---|---|
| Windows applications | `http://127.0.0.1:18477/mcp` |
| OpenWebUI in Docker Desktop | `http://host.docker.internal:18477/mcp` |

The server remains bound to `127.0.0.1`. Docker Desktop's host gateway can proxy the second URL without opening a listener on the LAN.

## Client setup

### Qwen Code

```powershell
qwen mcp add --scope user --transport http --timeout 30000 `
  --description "Local Outlook email with human-approved sending" `
  email-hub http://127.0.0.1:18477/mcp
```

Verify with `qwen mcp list`, then open a new Qwen Code session.

### Pi

```powershell
pi mcp add email-hub `
  --url http://127.0.0.1:18477/mcp `
  --exposure direct `
  --description "Local Outlook email with human-approved sending"
```

Verify with `pi mcp list`.

### Hermes Agent

```powershell
hermes mcp add --url http://127.0.0.1:18477/mcp --connect-timeout 30 email-hub
```

Choose **No** when asked whether authentication is required, then enable the tools. Verify with:

```powershell
hermes mcp test email-hub
```

### DeepSeek Harness

Add this patch row to the applicable profile's `cordis.patch.yml`:

```yaml
- insert:
    - id: mcp-email-hub
      name: '@deepseek-ai/dsh-mcp-client'
      config:
        serverName: email-hub
        transport: streamable-http
        url: http://127.0.0.1:18477/mcp
        toolCallTimeoutMs: 120000
        failOnStartupError: false
```

The registration helper appends this row to existing `web` and `headless` profiles and creates a backup first. It does not force-restart Harness, preserving active work.

### OpenWebUI

Open **Admin Settings → Integrations → External Tool Servers**, then add:

- Name: `Email Hub`
- Type: `MCP (Streamable HTTP)`
- URL: `http://host.docker.internal:18477/mcp`
- Authentication: none

Restrict the connection to trusted users or groups through OpenWebUI's access controls. OpenWebUI must support native Streamable HTTP MCP connections.

### Ollama and llama.cpp

Ollama and llama.cpp are model runtimes. They return tool calls, but the calling application executes tools. Configure Email Hub in Qwen Code, Pi, Hermes, Harness, OpenWebUI, or another agent host using an Ollama/llama.cpp model. Avoid registering the same tool at multiple layers in one conversation because duplicated tool definitions reduce reliability.

## Tools

| Tool | Behavior |
|---|---|
| `email_health` | Tests Outlook, SQLite integrity, backups, and queue counts. |
| `email_accounts` | Lists accounts in the active Outlook profile. |
| `email_folders` | Lists mail folders and stable Outlook identifiers. |
| `email_search` | Searches recent Inbox or selected-folder messages. |
| `email_read` | Returns one message as plain text plus attachment metadata. |
| `email_create_draft` | Saves a new Outlook draft; never sends. |
| `email_create_reply_draft` | Saves reply or reply-all draft; never sends. |
| `email_queue_send` | Saves an immutable, idempotent outbound request as `pending`. |
| `email_queue_status` | Reports queue state without approving or modifying it. |

Email Hub deliberately does not expose attachment download/open, delete, approval, or immediate-send tools.

## Sending workflow

1. The agent calls `email_queue_send`.
2. Email Hub saves recipients, subject, and body in the local durable queue with status `pending`.
3. Run `Approve-EmailHub.cmd` or choose approval from `Email-Hub-AIO.cmd`.
4. Review the complete immutable snapshot.
5. Select the entry and type the exact `SEND N` confirmation.
6. The background worker marks it `sending`, asks Outlook to send, then records `sent`.

If the process stops while Outlook is sending, the entry becomes `unknown`. Email Hub will not retry it. Inspect Outlook's Sent Items before deciding what to do next.

## Reliability model

- SQLite WAL allows readers while queue state is being committed.
- `synchronous=FULL` favors durability over write speed; queue volume is small.
- A consistent backup is taken on service start and every six hours.
- The newest seven backups are retained under `state\backups`.
- Startup converts orphaned `sending` entries to `unknown`.
- Pre-send connection/setup failures retry with capped exponential backoff.
- Failures at or after the ambiguous send boundary do not retry.
- The MCP transport is stateless HTTP, so clients can reconnect without losing server-side work.
- Outlook owns provider sync and preserves drafts independently of MCP sessions.

See [Architecture](docs/ARCHITECTURE.md) for the state machine and [Threat model](docs/THREAT-MODEL.md) for security boundaries.

## Everyday operation

Run `Email-Hub-AIO.cmd` for:

1. Health/status and safe recovery.
2. Human send approval.
3. Client registration/repair.
4. Runtime repair.
5. Portable export.
6. OpenWebUI integration setup.

You can also use the individual commands:

```text
Setup-EmailHub.cmd
Status-EmailHub.cmd
Approve-EmailHub.cmd
Export-EmailHub.cmd
```

## Portable bundles

Source-only bundle:

```powershell
.\Export-EmailHub.ps1
```

Offline-capable bundle when you already have a clean portable Python runtime and downloaded wheels:

```powershell
.\Export-EmailHub.ps1 `
  -RuntimeSource 'C:\portable-python-3.12' `
  -WheelSource '.\wheels' `
  -Destination '.\artifacts\email-hub-portable.zip'
```

Prepare wheels for Python 3.12 on Windows:

```powershell
python -m pip download --dest .\wheels -r .\requirements.txt
```

The exporter excludes `.git`, virtual environments, state databases, queued messages, logs, and credentials. Always inspect an archive before distributing it.

## Data locations

All paths are relative to the project directory:

| Path | Contents |
|---|---|
| `state\email-hub.sqlite3` | Queue and minimal audit metadata. |
| `state\backups\` | Rotating consistent database backups. |
| `logs\email-hub.log` | Service lifecycle/backup diagnostics; message content is omitted. |
| `logs\service.err.log` | MCP/HTTP runtime diagnostics. |

Queue rows necessarily contain the full unsent message so a person can review the exact snapshot. Protect the Windows account and project directory accordingly.

## Privacy and security

- Message bodies are returned only as plain text.
- Every read result is wrapped in an untrusted-content warning.
- HTML is not rendered by the MCP server.
- Attachments are listed but never saved or opened.
- Audit entries omit recipients, subjects, and bodies.
- The portable exporter excludes all runtime state.
- The public repository contains no mailbox addresses, messages, tokens, or workstation-specific paths.

The approval program is a safety interlock, not a hard sandbox. A coding agent with unrestricted shell/filesystem access under the same Windows account could modify the SQLite database or invoke Outlook independently. Limit powerful tools, use client confirmation policies, and consider a separate restricted Windows account when facing hostile models or untrusted users.

## Testing

Tests do not send mail or create Outlook drafts:

```powershell
python -m py_compile email_hub.py admin.py verify_mcp.py test_resilience.py
python test_resilience.py
python verify_mcp.py
```

`test_resilience.py` verifies duplicate prevention, crash-to-unknown behavior, and consistent backup integrity using a temporary database. `verify_mcp.py` requires the running local service and performs MCP discovery plus `email_health`.

## Troubleshooting

### Health reports no Outlook connection

- Confirm classic Outlook opens normally under the same Windows user.
- Finish any first-run or profile dialogs in Outlook.
- Do not run Email Hub as `LocalSystem` or a different service account.

### Port 18477 is already in use

Set `EMAIL_HUB_PORT` before starting and update every client URL:

```powershell
$env:EMAIL_HUB_PORT = '19477'
.\Start-EmailHub.ps1
```

The default launchers and verification script assume `18477`; update them together for a permanent change.

### OpenWebUI returns 421

Use `http://host.docker.internal:18477/mcp`, not the container's `127.0.0.1`. Current releases include this host in MCP DNS-rebinding protection while the socket remains bound to Windows loopback.

### A queued message is `unknown`

Do not blindly resend it. Search Outlook Sent Items using recipient, subject, and time. The state is intentionally non-retrying because delivery may already have succeeded.

### A client cannot see newly added tools

Start a new client session or use its MCP reload command. Tool definitions are commonly cached per session.

## Project layout

```text
email_hub.py                    MCP server, Outlook adapter, queue worker
admin.py                        Human approval program
Setup-EmailHub.*                Runtime installation and shortcuts
Start-EmailHub.ps1              Idempotent background launch
Status-EmailHub.*               Health check and safe recovery
Register-EmailHub-Clients.ps1   Client setup helper
Email-Hub-AIO.*                 All-in-one menu
Export-EmailHub.*               Privacy-preserving portable export
test_resilience.py              Non-delivery durability tests
verify_mcp.py                   Live MCP verification
docs/                           Architecture and threat model
```

## Contributing

Issues and pull requests are welcome. Do not include real message content, account addresses, Outlook identifiers, credentials, database files, logs, or screenshots containing personal information. See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).

