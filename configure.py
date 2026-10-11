from __future__ import annotations

import getpass
import os
import smtplib
import ssl
import subprocess
import tempfile
from pathlib import Path

from imapclient import IMAPClient

CONFIG_DIR = Path.home() / ".config/linux-email-hub"


def atomic_private_write(path: Path, text: str) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, name = tempfile.mkstemp(prefix=f".{path.name}.", dir=CONFIG_DIR, text=True)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(name, path)
    finally:
        try:
            os.unlink(name)
        except FileNotFoundError:
            pass


def main() -> int:
    print("Linux Email Hub — Gmail setup")
    print("Use a Google app password, not your normal Google password.")
    print("Nothing entered here is sent to chat or written to logs.\n")
    address = input("Gmail address: ").strip()
    display_name = input("Display name (optional): ").strip()
    app_password = getpass.getpass("Google app password (hidden): ").replace(" ", "").strip()
    if "@" not in address or not app_password:
        print("A valid-looking address and app password are required.")
        return 2
    print("Testing IMAP authentication…")
    with IMAPClient("imap.gmail.com", port=993, ssl=True, ssl_context=ssl.create_default_context()) as client:
        client.login(address, app_password)
        client.select_folder("INBOX", readonly=True)
    print("Testing SMTP authentication without sending mail…")
    with smtplib.SMTP_SSL("smtp.gmail.com", 465, timeout=30, context=ssl.create_default_context()) as client:
        client.login(address, app_password)
    atomic_private_write(
        CONFIG_DIR / "config.env",
        "\n".join([
            f"EMAIL_ADDRESS={address}", f"DISPLAY_NAME={display_name}",
            "IMAP_HOST=imap.gmail.com", "IMAP_PORT=993",
            "SMTP_HOST=smtp.gmail.com", "SMTP_PORT=465",
            "DRAFTS_FOLDER=[Gmail]/Drafts", "",
        ]),
    )
    atomic_private_write(CONFIG_DIR / "credentials.env", f"EMAIL_APP_PASSWORD={app_password}\n")
    print("Configuration saved with mode 0600. Restarting the user service…")
    subprocess.run(
        ["systemctl", "--user", "restart", "linux-email-hub.service"],
        check=True,
    )
    print("Done. Check with: email-hub-status")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
