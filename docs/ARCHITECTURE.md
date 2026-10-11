# Architecture

## Components

```text
AI client / UI
    │ Streamable HTTP MCP
    ▼
Local Email Hub (127.0.0.1:18477)
    ├── Outlook COM adapter ──► classic Outlook profile ──► mail providers
    ├── SQLite WAL queue
    ├── background sender
    └── rotating backups

Human reviewer
    └── Approve-EmailHub.cmd ──► pending → approved
```

The language model never connects directly to a provider. It asks its host to invoke an MCP tool. Email Hub uses the already authenticated Outlook profile belonging to the interactive Windows user.

## Transport

`FastMCP` exposes stateless Streamable HTTP at `/mcp`. Stateless transport makes reconnects cheap; durable state lives in SQLite and Outlook rather than an MCP session.

The listener binds only to `127.0.0.1`. DNS-rebinding checks permit:

- `127.0.0.1`
- `localhost`
- IPv6 loopback
- `host.docker.internal` for Docker Desktop/OpenWebUI

This is not a network authentication layer. Any process able to reach the local endpoint can invoke read and draft tools.

## Outlook adapter

Each operation initializes COM on its worker thread, opens `Outlook.Application`, uses the MAPI namespace, and then uninitializes COM. This avoids sharing thread-affine COM objects across async MCP requests.

Email search scans a bounded number of recent messages. Message reads use Outlook's plain-text `Body`, not rendered HTML. Attachments are represented only by name, index, and size.

## Queue schema

The durable queue records:

- UUID queue identifier
- unique idempotency key
- requested Outlook account
- To/Cc/Bcc snapshot
- subject/body snapshot
- status timestamps
- attempt count and diagnostic error
- Outlook draft entry identifier when available

Queue content is sensitive. It is excluded from exports and source control.

## Send state machine

```text
pending ──human approval──► approved ──worker lease──► sending
   │                           │                         ├── confirmed call success ─► sent
   └──────── cancel* ─────────► cancelled*              └── ambiguous interruption ─► unknown

approved ──safe pre-send setup failure──► approved (backoff) ──after cap──► failed
```

`cancelled` is reserved in the schema for administrative tooling. The current MCP API cannot approve, cancel, or send immediately.

The critical design decision is the `sending → unknown` transition on startup. Once Outlook's `Send()` boundary may have been crossed, the program chooses possible manual follow-up over an automatic duplicate.

## Backups

SQLite's online backup API creates a consistent copy at startup and every six hours. The newest seven are retained. Export archives exclude the primary database, WAL/SHM files, and backups.

## Failure behavior

- MCP client disconnect: no durable work is lost.
- Email Hub restart: pending/approved work remains; orphaned sending work becomes unknown.
- Outlook unavailable before send: retry with capped exponential backoff.
- Outlook provider offline: Outlook controls synchronization; drafts remain in Outlook.
- Machine restart: per-user Startup shortcut starts Email Hub after sign-in.

## Why Outlook instead of provider-specific OAuth

Outlook already implements authentication and synchronization for Exchange, Microsoft 365, Gmail, and IMAP accounts. Reusing it avoids duplicating refresh tokens, client registrations, and provider-specific APIs in every agent host. The trade-off is Windows/classic-Outlook dependence.

