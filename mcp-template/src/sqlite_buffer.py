"""
SQLite Shock Absorber — Local buffer between legacy DB and cloud.

Prevents read-heavy polling from crashing the legacy database by
decoupling the read (pull) phase from the write (push) phase.
"""

import json
import sqlite3
import logging
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger("mcp_sqlite_buffer")


class SQLiteBuffer:
    """
    Local SQLite database acting as a "Shock Absorber" between
    the legacy ERP and the Curoot cloud ingestion endpoint.

    Operations are append-only on insert; status transitions from
    'pending' → 'synced' on successful push.
    """

    def __init__(self, db_path: str) -> None:
        self.db_path = db_path
        self._init_db()

    def _init_db(self) -> None:
        """Create the sync_queue table if it doesn't exist."""
        conn = sqlite3.connect(self.db_path)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS sync_queue (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                payload TEXT NOT NULL,
                status TEXT DEFAULT 'pending',
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                synced_at TEXT
            )
        """)
        conn.commit()
        conn.close()
        logger.info("Buffer DB initialised at %s", self.db_path)

    def enqueue(self, payload: Dict[str, Any]) -> None:
        """Add a single payload to the sync queue."""
        conn = sqlite3.connect(self.db_path)
        conn.execute(
            "INSERT INTO sync_queue (payload, status) VALUES (?, ?)",
            (json.dumps(payload), "pending"),
        )
        conn.commit()
        conn.close()

    def enqueue_batch(self, payloads: List[Dict[str, Any]]) -> None:
        """Add multiple payloads to the sync queue in one transaction."""
        conn = sqlite3.connect(self.db_path)
        conn.executemany(
            "INSERT INTO sync_queue (payload, status) VALUES (?, ?)",
            [(json.dumps(p), "pending") for p in payloads],
        )
        conn.commit()
        conn.close()
        logger.info("Enqueued %d payloads to buffer", len(payloads))

    def dequeue_pending(self, limit: int = 50) -> List[Tuple[int, Dict[str, Any]]]:
        """
        Fetch pending payloads from the queue.
        Returns list of (id, payload_dict) tuples.
        """
        conn = sqlite3.connect(self.db_path)
        rows = conn.execute(
            "SELECT id, payload FROM sync_queue WHERE status = 'pending' ORDER BY id ASC LIMIT ?",
            (limit,),
        ).fetchall()
        conn.close()
        return [(row[0], json.loads(row[1])) for row in rows]

    def mark_synced(self, item_id: int) -> None:
        """Mark a single queue item as successfully synced."""
        conn = sqlite3.connect(self.db_path)
        conn.execute(
            "UPDATE sync_queue SET status = 'synced', synced_at = CURRENT_TIMESTAMP WHERE id = ?",
            (item_id,),
        )
        conn.commit()
        conn.close()

    def mark_failed(self, item_id: int) -> None:
        """Mark a single queue item as failed."""
        conn = sqlite3.connect(self.db_path)
        conn.execute(
            "UPDATE sync_queue SET status = 'failed' WHERE id = ?",
            (item_id,),
        )
        conn.commit()
        conn.close()

    def get_stats(self) -> Dict[str, int]:
        """Return counts of pending, synced, and failed items."""
        conn = sqlite3.connect(self.db_path)
        result: Dict[str, int] = {}
        for status in ("pending", "synced", "failed"):
            count = conn.execute(
                "SELECT COUNT(*) FROM sync_queue WHERE status = ?", (status,)
            ).fetchone()
            result[status] = count[0] if count else 0
        conn.close()
        return result
