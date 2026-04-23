"""
MCP Connector — Reference Implementation (main.py)

Entry point for the Model Context Protocol Docker container.
Runs the poll loop: pull_and_buffer → flush_buffer at a configurable frequency.

Architecture: Legacy DB → SQLite Shock Absorber → HTTPS Push → Curoot Cloud
"""

import os
import time
import logging

from erp_connector import ERPConnector
from sqlite_buffer import SQLiteBuffer
from sync_worker import SyncWorker

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [MCP] %(levelname)s %(message)s",
)
logger = logging.getLogger("mcp_main")

# Configuration from environment variables (set by Docker / docker-compose)
SYNC_FREQ = int(os.getenv("SYNC_FREQ", "60"))
BUFFER_PATH = os.getenv("BUFFER_PATH", "/app/buffer/sync_buffer.db")
WEBHOOK_URL = os.getenv(
    "INGESTION_WEBHOOK",
    "http://host.docker.internal:8000/api/v1/ingestion/telemetry",
)


def main() -> None:
    """Initialise components and start the polling loop."""
    logger.info("=" * 60)
    logger.info("  Curoot MCP Connector — Starting Up")
    logger.info("=" * 60)

    # 1. Initialise the ERP connector (reads from legacy DB)
    erp = ERPConnector()
    logger.info("ERP Connector ready: %s @ %s", erp.db_type, erp.db_host)

    # 2. Initialise the SQLite Shock Absorber
    buffer = SQLiteBuffer(BUFFER_PATH)
    logger.info("SQLite buffer ready at %s", BUFFER_PATH)

    # 3. Initialise the Sync Worker (pushes to cloud)
    worker = SyncWorker(buffer, WEBHOOK_URL)
    logger.info("Sync worker targeting %s", WEBHOOK_URL)

    logger.info("Poll frequency: every %d seconds", SYNC_FREQ)
    logger.info("-" * 60)

    # 4. Main polling loop
    while True:
        try:
            # Pull from legacy DB → write to local SQLite buffer
            records = erp.pull_new_records()
            if records:
                buffer.enqueue_batch(records)
                logger.info("Buffered %d new records", len(records))
            else:
                logger.info("No new records from ERP")

            # Flush buffer → push to Curoot cloud via HTTPS
            worker.flush()

        except KeyboardInterrupt:
            logger.info("Shutting down gracefully...")
            break
        except Exception as exc:
            logger.error("Sync cycle error: %s", exc)

        time.sleep(SYNC_FREQ)


if __name__ == "__main__":
    main()
