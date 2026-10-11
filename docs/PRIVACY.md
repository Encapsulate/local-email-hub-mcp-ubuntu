# Privacy

## Data that stays local

The service stores its Gmail app password, queue, audit metadata, logs, and backups only under the installing user's home directory. None of those files are part of the repository, and `.gitignore` excludes their expected names and formats.

The MCP endpoint is loopback-only. The project contains no telemetry, analytics SDK, crash uploader, cloud relay, public tunnel, or hosted service.

## Data sent to Gmail

The service connects directly to the configured Gmail IMAP and SMTP endpoints over verified TLS. Normal IMAP searches/reads, draft appends, and approved SMTP submissions necessarily send protocol requests to Google. No additional third party receives mailbox data from this software.

Your MCP client and selected model may receive data returned by tools. A local model keeps that content on the machine only if its host does not forward prompts, traces, or tool results elsewhere. Verify the privacy policy and configuration of every client/model provider you connect.

## Credentials

`email-hub-configure` accepts the app password with `getpass`, so terminal echo is disabled. It verifies IMAP and SMTP authentication before atomically writing a mode-`0600` credentials file. The app password is never:

- accepted through an MCP tool;
- included in tool results;
- placed in command-line arguments;
- written to service logs or audit rows;
- added to the repository.

The current release uses a local app-password file rather than a desktop keyring so a background systemd user service can start consistently. Anyone who can fully act as your Linux user can read that file. Use full-disk encryption, a strong login, screen locking, and a dedicated restricted mailbox if your threat model requires it.

## Mail and queue content

Search/read results go only to the calling MCP client. The service does not build a local mailbox index. It stores full content only for outbound messages explicitly queued for approval.

Queue backups contain those unsent messages. Seven backups are retained. Uninstalling preserves private state so uninstall cannot destroy mail-review evidence accidentally; deletion is a separate manual choice.

## Logs

Lifecycle and diagnostic logs omit message bodies, subjects, recipients, addresses, and credentials. Some remote-library exceptions may include server text; report any exception that unexpectedly contains sensitive provider data.

## Safe issue reports

Never attach real configuration, credentials, databases, logs containing provider data, mailbox screenshots, messages, or terminal environment dumps to a public issue. Reproduce with `example.invalid` addresses and synthetic content.

