"""
Sync Worker — Append-Only HTTPS Push from SQLite buffer to Curoot Cloud.

Reads pending payloads from the local SQLite buffer and pushes them
to the platform's Zero-Trust ingestion webhook via secure HTTPS.
"""

import logging
from typing import Optional

import requests

from sqlite_buffer import SQLiteBuffer

logger = logging.getLogger("mcp_sync_worker")


class SyncWorker:
    """
    Pushes buffered telemetry from the local SQLite Shock Absorber
    to the Curoot cloud ingestion endpoint via append-only HTTPS POST.

    Each payload is individually acknowledged — on success the buffer
    item is marked 'synced'; on failure it remains 'pending' for retry.
    """

    def __init__(self, buffer: SQLiteBuffer, webhook_url: str) -> None:
        self.buffer = buffer
        self.webhook_url = webhook_url
        self._session = requests.Session()
        self._session.headers.update({"Content-Type": "application/json"})

    def flush(self, batch_size: int = 50) -> int:
        """
        Push all pending payloads to the cloud webhook.
        Returns the number of successfully synced items.
        """
        pending = self.buffer.dequeue_pending(limit=batch_size)
        if not pending:
            return 0

        logger.info("Flushing %d payloads to %s", len(pending), self.webhook_url)
        synced_count = 0

        for item_id, payload in pending:
            try:
                resp = self._session.post(
                    self.webhook_url,
                    json=payload,
                    timeout=30,
                )
                if resp.status_code == 200:
                    self.buffer.mark_synced(item_id)
                    synced_count += 1
                    result = resp.json()
                    logger.info(
                        "✓ Synced payload %d (node: %s) — %s",
                        item_id,
                        payload.get("node_id", "?"),
                        result.get("message", "OK"),
                    )
                else:
                    logger.error(
                        "✗ Sync failed for %d: HTTP %d — %s",
                        item_id,
                        resp.status_code,
                        resp.text[:200],
                    )
            except requests.exceptions.ConnectionError:
                logger.error(
                    "✗ Connection refused for payload %d — is the backend running?",
                    item_id,
                )
                break  # Stop flushing if backend is down
            except requests.exceptions.Timeout:
                logger.error("✗ Timeout for payload %d", item_id)
            except Exception as exc:
                logger.error("✗ Unexpected error for payload %d: %s", item_id, exc)

        stats = self.buffer.get_stats()
        logger.info(
            "Flush complete: %d synced | Buffer stats: %s",
            synced_count,
            stats,
        )
        return synced_count
