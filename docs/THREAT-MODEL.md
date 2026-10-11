# Threat model

## Protected assets

- Gmail address, folders, message metadata, and plain-text bodies.
- Gmail app password.
- Unsent queue snapshots and SQLite backups.
- The ability to create drafts or submit approved mail.

## Trust assumptions

- The Linux user account and OS trust store are trusted.
- The configured MCP clients and model hosts are trusted to receive selected mailbox data.
- The host is not shared with untrusted users or containers that can reach owner loopback.
- The human reviewer actually reads recipients and content before approval.

## Prompt injection in email

An email can tell a model to reveal secrets, invoke tools, or send data. Every search/read response marks email as untrusted; HTML is not rendered; attachment content is not exposed as a tool result; approval and immediate sending are absent from MCP.

Residual risk: a model host may provide unrelated shell, browser, filesystem, or network tools. Do not treat model reasoning as an authorization boundary. Prefer a session whose only email write capability is draft/queue creation.

## Duplicate or unintended sending

Queue creation is idempotent. SMTP connection/login failures are retried only before submission. Once submission may have begun, an error becomes `unknown` and is never retried automatically. The human must inspect Gmail Sent mail before acting.

Residual risk: SMTP success confirms server acceptance, not recipient delivery or inbox placement.

## Local unauthorized access

The listener is loopback-only and validates Host/Origin values. Private files use restrictive permissions, and the systemd service uses hardening directives.

Residual risk: loopback is not authentication. A process under the same user can call the MCP endpoint, read private files, modify SQLite, or connect to Gmail independently.

## Approval bypass

Approval is intentionally unavailable through MCP and requires an exact interactive confirmation.

Residual risk: an agent with arbitrary code execution as the owner can bypass the workflow. Keep unrestricted shell/filesystem tools separate from mail-enabled sessions when strict send prevention matters.

## Supply-chain and repository leakage

Dependencies are constrained and resolved in `uv.lock`; CI runs compilation and offline tests. Runtime state, credentials, databases, logs, virtual environments, caches, and build artifacts are ignored. Contributors must use synthetic mail and reserved domains.

Residual risk: package installation still trusts PyPI packages and the local Python/pip toolchain. Review lockfile changes and use a dedicated environment.

## Out of scope

- A compromised Linux account, kernel, Python runtime, Gmail account, or CA trust store.
- Strong multi-user authorization or per-client identities.
- Malware scanning or content-disarm/reconstruction.
- Guaranteed delivery or read receipts.
- Public/LAN service exposure.
- Automatic OAuth refresh flows in the current Gmail app-password release.

