# Threat model

## Assets

- Email account addresses and folder structure.
- Message metadata and plain-text bodies returned to a client.
- Unsent message snapshots in the durable queue.
- The ability to create drafts or cause Outlook to send after human approval.

## Trust assumptions

- The interactive Windows account and classic Outlook profile are trusted.
- Installed MCP clients are trusted to receive mailbox data.
- The local host is not shared with untrusted users or containers.
- Human reviewers inspect recipients and content rather than mechanically approving.

## Threats and mitigations

### Prompt injection in email

Threat: a message tells the model to reveal secrets, run tools, or send data.

Mitigations:

- Every read/search response labels email as untrusted.
- HTML is not rendered.
- Attachments are not opened or downloaded.
- No MCP tool can approve or immediately send.
- Tool descriptions repeat the trust boundary.

Residual risk: the model host may expose unrelated powerful tools. Configure host-level permissions and do not treat model reasoning as an authorization boundary.

### Duplicate sends after a crash

Threat: retrying an ambiguous `Send()` call delivers twice.

Mitigations:

- Idempotency keys deduplicate queue creation.
- The queue commits `sending` before invoking Outlook.
- Startup changes orphaned `sending` rows to `unknown`.
- Unknown rows are never automatically retried.

### Unauthorized local access

Threat: another process or container on the workstation invokes the unauthenticated MCP endpoint.

Mitigations:

- Bind only to Windows loopback.
- Validate Host and Origin values.
- Do not expose a LAN listener.
- Limit OpenWebUI access to trusted users/groups.

Residual risk: loopback is not authentication. Docker Desktop containers can use the explicitly allowed host gateway. Use host firewalls, container trust controls, or a separate restricted OS account for stronger isolation.

### Approval bypass

Threat: an agent modifies SQLite or invokes Outlook through shell/code execution.

Mitigation: approval is absent from the MCP surface and requires an interactive confirmation program.

Residual risk: this is a workflow interlock, not an OS security boundary. An agent with unrestricted code execution as the same Windows user can bypass it. Do not grant arbitrary shell/filesystem tools to untrusted models if strict send prevention is required.

### Data leakage through logs and exports

Mitigations:

- Audit entries omit message content, subject, and recipients.
- Export excludes state, backups, logs, `.venv`, and credentials.
- Source control ignores those paths.
- Public examples use reserved `.invalid` addresses.

### Malicious attachments

Mitigation: the current tool surface exposes attachment metadata only. It does not save, open, scan, or execute attachments.

## Out of scope

- Protecting a compromised Windows account.
- Protecting against Outlook or provider compromise.
- Strong multi-user authorization.
- Malware scanning or content-disarm/reconstruction.
- Guaranteed delivery receipts.
- Running as a Windows service without an interactive Outlook profile.

## Recommended hardening

- Use a dedicated Windows account and Outlook profile for automation.
- Restrict that mailbox's permissions and sending identities.
- Limit MCP access to trusted clients.
- Keep arbitrary shell tools separate from mail-enabled sessions.
- Review `unknown` sends manually.
- Back up encrypted disks and protect the Windows sign-in.

