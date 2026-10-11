# Architecture

## Components

```text
Trusted MCP client
    │ Streamable HTTP on loopback
    ▼
Local Email Hub MCP — Ubuntu Edition (127.0.0.1:18477)
    ├── Gmail IMAP adapter ──► search, read, folders, drafts
    ├── SQLite WAL queue  ──► pending/approved/sending state
    ├── Gmail SMTP worker ──► submission only after approval
    └── rotating SQLite backups

Human reviewer
    └── email-hub-approve ──► pending → approved
```

The model never receives a mailbox password and never connects directly to Gmail. Its host invokes bounded MCP tools. The service reads its app password from a private local file only when creating an authenticated IMAP or SMTP connection.

## Transport and trust boundary

FastMCP provides stateless Streamable HTTP at `/mcp`. The listener is fixed to `127.0.0.1` by default and enables DNS-rebinding protection for loopback hosts/origins. The project does not include a LAN or public-listener recipe.

Loopback is a host boundary, not process-level authentication. Other processes running as the same Linux user can reach the endpoint. Only trusted local clients should be used.

## IMAP behavior

- TLS certificate verification uses the operating system trust store.
- Search is server-side and results are capped.
- Reads are bounded and return plain text plus attachment metadata.
- HTML is not rendered.
- Drafts are appended with the IMAP `\\Draft` flag.
- Message identity uses an IMAP folder plus UID; callers should not assume a UID is portable across folders.

## Queue schema

The private SQLite queue records:

- queue UUID and unique idempotency key;
- To/Cc/Bcc snapshots;
- subject/body snapshot;
- state timestamps and attempt count;
- diagnostic error and RFC message ID.

Full queued content is required so the reviewer sees exactly what will be submitted. Audit rows omit recipients, subjects, bodies, and credentials.

## Send state machine

```text
pending ──human approval──► approved ──SMTP login succeeds──► sending
                                                               ├── confirmed success ─► sent
                                                               └── ambiguous failure ─► unknown

approved ──pre-submit connection/login failure──► approved + backoff
                                             └── after retry cap ─► failed
```

The worker authenticates before crossing the send boundary. It changes the row to `sending` immediately before `SMTP.send_message()`. Any exception from that call is ambiguous and becomes `unknown`, never an automatic retry. Startup converts orphaned `sending` rows to `unknown`.

## Storage and backups

State defaults to `~/.local/share/linux-email-hub`. SQLite uses WAL mode, `synchronous=FULL`, and a 30-second busy timeout. The online backup API creates a consistent backup at startup and every six hours; the newest seven are retained.

Configuration defaults to `~/.config/linux-email-hub`. The installer creates both directories with mode `0700`; files containing credentials or queue content use mode `0600`.

