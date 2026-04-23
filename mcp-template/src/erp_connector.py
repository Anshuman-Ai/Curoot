"""
ERP Connector — Factory pattern for connecting to legacy databases.

Supports: PostgreSQL, MySQL, Oracle, SQL Server.
Reads configuration from environment variables set by Docker.
"""

import os
import json
import logging
from typing import Any, Dict, List, Optional
from datetime import datetime, timezone

logger = logging.getLogger("mcp_erp_connector")

# Database type from environment
DB_TYPE = os.getenv("TARGET_DB_TYPE", "postgres").lower().replace(" ", "")
DB_HOST = os.getenv("TARGET_DB_IP", "localhost")
DB_PORT = os.getenv("TARGET_DB_PORT", "5432")
DB_USER = os.getenv("TARGET_DB_USER", "readonly_user")
DB_PASS = os.getenv("TARGET_DB_PASS", "")
DB_NAME = os.getenv("TARGET_DB_NAME", "erp")
TABLE_NAME = os.getenv("TARGET_TABLE", "inventory")


class ERPConnector:
    """
    Factory-pattern connector to legacy enterprise databases.

    Performs low-frequency reads to avoid crashing fragile on-premise systems.
    All data is returned as a list of dicts conforming to the UniversalFilter schema.
    """

    def __init__(self) -> None:
        self.db_type = DB_TYPE
        self.db_host = DB_HOST
        self.db_port = DB_PORT
        self.table_name = TABLE_NAME
        self._last_sync: Optional[str] = None

    def _get_connection(self) -> Any:
        """Create a database connection based on the configured DB type."""
        if self.db_type in ("postgres", "postgresql"):
            import psycopg2
            return psycopg2.connect(
                host=DB_HOST,
                port=int(DB_PORT),
                user=DB_USER,
                password=DB_PASS,
                dbname=DB_NAME,
            )

        elif self.db_type == "mysql":
            import pymysql
            return pymysql.connect(
                host=DB_HOST,
                port=int(DB_PORT),
                user=DB_USER,
                password=DB_PASS,
                database=DB_NAME,
            )

        elif self.db_type == "oracle":
            import cx_Oracle  # type: ignore
            dsn = f"{DB_HOST}:{DB_PORT}/{DB_NAME}"
            return cx_Oracle.connect(user=DB_USER, password=DB_PASS, dsn=dsn)

        elif self.db_type in ("sqlserver", "mssql"):
            import pyodbc
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={DB_HOST},{DB_PORT};"
                f"DATABASE={DB_NAME};"
                f"UID={DB_USER};"
                f"PWD={DB_PASS}"
            )
            return pyodbc.connect(conn_str)

        else:
            raise ValueError(f"Unsupported database type: {self.db_type}")

    def pull_new_records(self) -> List[Dict[str, Any]]:
        """
        Pull new/updated records from the legacy database.

        Returns data formatted for the UniversalFilter schema:
          { node_id, status, location?: { lat, lng }, crisis_message? }
        """
        try:
            conn = self._get_connection()
            cursor = conn.cursor()

            # Query for records — uses a timestamp watermark if available
            if self._last_sync:
                query = f"SELECT * FROM {self.table_name} WHERE updated_at > %s ORDER BY updated_at ASC"
                cursor.execute(query, (self._last_sync,))
            else:
                query = f"SELECT * FROM {self.table_name} ORDER BY updated_at ASC LIMIT 100"
                cursor.execute(query)

            rows = cursor.fetchall()
            columns = [desc[0] for desc in cursor.description] if cursor.description else []

            # Update watermark
            self._last_sync = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

            conn.close()

            # Transform to UniversalFilter-compatible payloads
            results: List[Dict[str, Any]] = []
            for row in rows:
                record = dict(zip(columns, row))
                payload: Dict[str, Any] = {
                    "node_id": str(
                        record.get("id")
                        or record.get("node_id")
                        or record.get("internal_id", "UNKNOWN")
                    ),
                    "status": str(record.get("status", "operational")),
                }

                # Extract location if columns exist
                lat = record.get("lat") or record.get("latitude")
                lng = record.get("lng") or record.get("longitude")
                if lat is not None and lng is not None:
                    payload["location"] = {"lat": float(lat), "lng": float(lng)}

                # Detect crisis messages in status or dedicated field
                crisis = record.get("crisis_message") or record.get("raw_status")
                if crisis and any(
                    kw in str(crisis).upper()
                    for kw in ("CRISIS", "EMERGENCY", "CRITICAL", "SEVERE")
                ):
                    payload["crisis_message"] = str(crisis)
                    payload["status"] = "unknown"

                results.append(payload)

            logger.info("Pulled %d records from %s.%s", len(results), self.db_type, self.table_name)
            return results

        except Exception as exc:
            logger.error("ERP pull failed: %s", exc)
            return []
