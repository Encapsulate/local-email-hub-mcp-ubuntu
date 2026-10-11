# Security policy

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting feature for this repository. Do not open a public issue containing mailbox data, credentials, message content, local paths, queue databases, logs, or proof-of-concept data taken from a real account.

Include the affected commit/version, Windows and classic Outlook versions, impact, reproducible steps using synthetic data, and any suggested mitigation.

## Supported versions

Until the project reaches a stable major release, security fixes target the latest `main` branch and newest GitHub release.

## Security posture

This project is a local workflow tool, not a hardened multi-user mail gateway. Read [docs/THREAT-MODEL.md](docs/THREAT-MODEL.md) before granting it access to sensitive accounts.

