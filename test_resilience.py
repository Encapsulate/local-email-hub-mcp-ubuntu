import sqlite3
import tempfile
from pathlib import Path

import email_hub as hub


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="email-hub-test-") as temp:
        root = Path(temp)
        hub.DB_PATH = root / "test.sqlite3"
        hub.BACKUPS = root / "backups"
        hub.BACKUPS.mkdir()
        hub.init_database()

        first = hub.queue_message(
            account="",
            to=["nobody@example.invalid"],
            cc=[],
            bcc=[],
            subject="Email Hub resilience test",
            body="This is local test data and will never be approved or sent.",
            idempotency_key="resilience-test-fixed-key",
        )
        second = hub.queue_message(
            account="",
            to=["nobody@example.invalid"],
            cc=[],
            bcc=[],
            subject="Email Hub resilience test",
            body="This is local test data and will never be approved or sent.",
            idempotency_key="resilience-test-fixed-key",
        )
        assert first["queued"] is True
        assert second["duplicate_prevented"] is True
        assert first["queue_id"] == second["queue_id"]

        with hub.database() as con:
            con.execute("UPDATE send_queue SET status='sending' WHERE id=?", (first["queue_id"],))
        hub.init_database()
        with hub.database() as con:
            status = con.execute(
                "SELECT status FROM send_queue WHERE id=?", (first["queue_id"],)
            ).fetchone()[0]
        assert status == "unknown"
        backup = hub.backup_database()
        backup_con = sqlite3.connect(backup)
        try:
            check = backup_con.execute("PRAGMA integrity_check").fetchone()[0]
        finally:
            backup_con.close()
        assert check == "ok"
        print("PASS idempotency duplicate prevention")
        print("PASS crash-during-send changes to non-retrying unknown state")
        print("PASS consistent SQLite backup integrity")


if __name__ == "__main__":
    main()
