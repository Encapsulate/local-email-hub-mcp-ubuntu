from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DB = ROOT / "state" / "email-hub.sqlite3"


def connect() -> sqlite3.Connection:
    con = sqlite3.connect(DB, timeout=30)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA journal_mode=WAL")
    con.execute("PRAGMA synchronous=FULL")
    return con


def pending() -> list[sqlite3.Row]:
    with connect() as con:
        return con.execute(
            "SELECT id,account,recipients_json,cc_json,bcc_json,subject,body,created_at FROM send_queue WHERE status='pending' ORDER BY created_at"
        ).fetchall()


def interactive() -> int:
    rows = pending()
    if not rows:
        print("No messages are waiting for approval.")
        return 0
    for number, row in enumerate(rows, start=1):
        print("\n" + "=" * 78)
        print(f"[{number}] Queue ID: {row['id']}")
        print(f"Account:  {row['account'] or '(Outlook default)'}")
        print(f"To:       {row['recipients_json']}")
        print(f"Cc:       {row['cc_json']}")
        print(f"Bcc:      {row['bcc_json']}")
        print(f"Subject:  {row['subject']}")
        print("-" * 78)
        print(row["body"])
    print("\nApproval is outside MCP. Carefully review recipients and content.")
    choice = input("Enter message number to approve, A for all, or press Enter to cancel: ").strip()
    if not choice:
        print("Nothing approved.")
        return 0
    selected = rows if choice.casefold() == "a" else [rows[int(choice) - 1]]
    confirmation = input(f"Type SEND {len(selected)} to approve: ").strip()
    if confirmation != f"SEND {len(selected)}":
        print("Confirmation did not match. Nothing approved.")
        return 2
    with connect() as con:
        for row in selected:
            con.execute(
                "UPDATE send_queue SET status='approved', approved_at=datetime('now'), next_attempt_at=datetime('now') WHERE id=? AND status='pending'",
                (row["id"],),
            )
    print(f"Approved {len(selected)} message(s). The durable sender will process them.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()
    if args.list:
        for row in pending():
            print(f"{row['id']} | {row['recipients_json']} | {row['subject']}")
        return 0
    return interactive()


if __name__ == "__main__":
    raise SystemExit(main())

