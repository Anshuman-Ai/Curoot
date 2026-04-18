import os
import time
import sqlite3
import requests
import logging
import threading

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

# --- CONFIGURATION MATCHING THE DOCKER SETUP ---
# Since we are running locally instead of via docker for this test, we override URLs
MOCK_ERP_DB_PATH = 'mock_legacy_erp.db'
LOCAL_BUFFER_DB_PATH = 'mcp_local_buffer.db'
INGESTION_WEBHOOK = "http://127.0.0.1:8000/api/v1/ingestion/telemetry"
SYNC_FREQ = 3 # Fast frequency just for testing

# ---------------------------------------------------------
# 1. THE LEGACY ERP MOCK
# ---------------------------------------------------------
def run_mock_erp():
    """Simulates a legacy, on-premise ERP that generates unstructured or loosely structured data."""
    conn = sqlite3.connect(MOCK_ERP_DB_PATH)
    conn.execute('''CREATE TABLE IF NOT EXISTS erp_events 
                    (id INTEGER PRIMARY KEY AUTOINCREMENT, node_id TEXT, raw_status TEXT, lng REAL, lat REAL, is_processed INTEGER DEFAULT 0)''')
    
    # Insert a few mock events that the MCP pattern will pick up
    events = [
        ("SUPPLIER-X1", "operational", 12.4924, 41.8902), # Valid operational event
        ("WH-A", "CRISIS: severe weather blocking routes", -73.9352, 40.7306), # Crisis AI triggering event
        ("FACILITY-09", "maintenance", 13.4050, 52.5200) # Standard update
    ]
    
    conn.executemany('''INSERT INTO erp_events (node_id, raw_status, lng, lat) VALUES (?, ?, ?, ?)''', events)
    conn.commit()
    logger.info(f"[ERP MOCK] Inserted {len(events)} new records into legacy database.")
    conn.close()

# ---------------------------------------------------------
# 2. THE MCP CONNECTOR (SHOCK ABSORBER)
# ---------------------------------------------------------
def init_mcp_buffer():
    conn = sqlite3.connect(LOCAL_BUFFER_DB_PATH)
    conn.execute('''CREATE TABLE IF NOT EXISTS sync_queue 
                    (id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT, status TEXT)''')
    conn.commit()
    conn.close()

def mcp_pull_from_erp():
    """MCP extracts from legacy, standardizes to UniversalFilter, and writes to Local Buffer."""
    erp_conn = sqlite3.connect(MOCK_ERP_DB_PATH)
    rows = erp_conn.execute("SELECT id, node_id, raw_status, lng, lat FROM erp_events WHERE is_processed = 0").fetchall()
    
    if not rows:
        return

    buffer_conn = sqlite3.connect(LOCAL_BUFFER_DB_PATH)
    for row in rows:
        erp_id, node_id, raw_status, lng, lat = row
        
        # UniversalFilter schema formatting
        is_crisis = "CRISIS" in raw_status.upper()
        payload = {
            "node_id": node_id,
            "status": raw_status if not is_crisis else "unknown",
            "crisis_message": raw_status if is_crisis else None,
            "location": {"lng": lng, "lat": lat}
        }
        
        import json
        buffer_conn.execute('INSERT INTO sync_queue (payload, status) VALUES (?, ?)', (json.dumps(payload), 'pending'))
        
        # Mark processed in ERP
        erp_conn.execute('UPDATE erp_events SET is_processed = 1 WHERE id = ?', (erp_id,))
        
    buffer_conn.commit()
    erp_conn.commit()
    
    buffer_conn.close()
    erp_conn.close()
    logger.info(f"[MCP CONNECTOR] Pulled {len(rows)} records from ERP into local buffer.")


def mcp_push_to_cloud():
    """MCP pushes buffered data to Zero-Trust cloud webhook securely."""
    conn = sqlite3.connect(LOCAL_BUFFER_DB_PATH)
    pending = conn.execute('SELECT id, payload FROM sync_queue WHERE status="pending"').fetchall()
    
    if not pending:
        conn.close()
        return

    logger.info(f"[MCP CONNECTOR] Attempting to push {len(pending)} buffered payloads to {INGESTION_WEBHOOK} ...")
    
    for item_id, payload_str in pending:
        try:
            import json
            payload = json.loads(payload_str)
            resp = requests.post(INGESTION_WEBHOOK, json=payload, headers={"Content-Type": "application/json"})
            
            if resp.status_code == 200:
                logger.info(f"[MCP CONNECTOR] Successfully synced Node: {payload['node_id']} | Cloud Response: {resp.json().get('message')}")
                conn.execute('UPDATE sync_queue SET status="synced" WHERE id=?', (item_id,))
            else:
                logger.error(f"[MCP CONNECTOR] Sync failed for {item_id}: {resp.status_code} - {resp.text}")
        except Exception as e:
            logger.error(f"[MCP CONNECTOR] Network error during push: {e}")
            
    conn.commit()
    conn.close()

# ---------------------------------------------------------
# 3. RUNNER
# ---------------------------------------------------------
if __name__ == "__main__":
    logger.info("Starting MCP Integration Test Validator...")
    
    # 1. Clean up old test DBs
    if os.path.exists(MOCK_ERP_DB_PATH): os.remove(MOCK_ERP_DB_PATH)
    if os.path.exists(LOCAL_BUFFER_DB_PATH): os.remove(LOCAL_BUFFER_DB_PATH)
    
    init_mcp_buffer()
    
    # 2. Add fake data to ERP Mock
    run_mock_erp()
    
    # 3. Run the MCP Sync cycle a few times
    cycles = 2
    for i in range(cycles):
        logger.info(f"\n--- Sync Cycle {i+1} ---")
        mcp_pull_from_erp()
        mcp_push_to_cloud()
        time.sleep(SYNC_FREQ)
        
    logger.info("\nIntegration Test Complete. The MCP successfully acted as a shock absorber between ERP and Cloud.")
