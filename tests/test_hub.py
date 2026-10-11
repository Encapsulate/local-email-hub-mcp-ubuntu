import sqlite3
import tempfile
from pathlib import Path

import linux_email_hub as hub


def test_queue_idempotency_crash_recovery_and_backup():
    with tempfile.TemporaryDirectory(prefix="linux-email-hub-test-") as temp:
        root = Path(temp)
        old_db, old_backups = hub.DB_PATH, hub.BACKUPS
        try:
            hub.DB_PATH = root / "test.sqlite3"
            hub.BACKUPS = root / "backups"
            hub.BACKUPS.mkdir()
            hub.init_database()
            first = hub.queue_message(["nobody@example.invalid"], [], [], "test", "never sent", "fixed")
            second = hub.queue_message(["nobody@example.invalid"], [], [], "test", "never sent", "fixed")
            assert first["queued"] is True
            assert second["duplicate_prevented"] is True
            assert first["queue_id"] == second["queue_id"]
            with hub.database() as con:
                con.execute("UPDATE send_queue SET status='sending' WHERE id=?", (first["queue_id"],))
            hub.init_database()
            with hub.database() as con:
                status = con.execute("SELECT status FROM send_queue WHERE id=?", (first["queue_id"],)).fetchone()[0]
            assert status == "unknown"
            backup = hub.backup_database()
            with sqlite3.connect(backup) as con:
                assert con.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
        finally:
            hub.DB_PATH, hub.BACKUPS = old_db, old_backups


def test_address_splitting_rejects_header_injection():
    assert hub.split_addresses("a@example.com; b@example.com") == ["a@example.com", "b@example.com"]
    assert hub.split_addresses(["ok@example.com", "bad@example.com\nBcc:x@example.com"]) == ["ok@example.com"]

