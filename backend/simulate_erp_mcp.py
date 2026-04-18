import sqlite3
import requests
import time
import json
import os

# --- MOCK ERP SETTINGS ---
MOCK_ERP_DB = "legacy_erp_mock.db"
MCP_BUFFER_DB = "mcp_buffer_mock.db"
INGESTION_WEBHOOK = "http://127.0.0.1:8000/api/v1/ingestion/telemetry"

def setup_mock_erp():
    """Simulates a legacy PostgreSQL/ERP database having internal data."""
    print("[1] Provisioning Legacy ERP Database Simulator...")
    conn = sqlite3.connect(MOCK_ERP_DB)
    # Create a table mimicking legacy ERP node records
    conn.execute('''CREATE TABLE IF NOT EXISTS erp_nodes
                    (id INTEGER PRIMARY KEY, internal_id TEXT, status TEXT, lat REAL, lng REAL, is_synced INTEGER)''')
    conn.execute("DELETE FROM erp_nodes")
    
    # Insert some mock records (some operational, some with crisis)
    records = [
        ("NODE-A1", "operational", 40.7128, -74.0060),
        ("NODE-B2", "delayed", 34.0522, -118.2437),
        ("WH-CHICAGO", "unknown", 41.8781, -87.6298) # We will simulate a crisis message for this
    ]
    for r in records:
        conn.execute("INSERT INTO erp_nodes (internal_id, status, lat, lng, is_synced) VALUES (?, ?, ?, ?, 0)", r)
    
    conn.commit()
    conn.close()
    print("    -> Legacy ERP database seeded with mock data.\n")

def init_mcp_buffer():
    """Initializes the Zero-Trust local buffer (the Shock Absorber)."""
    print("[2] Initializing Local MCP Buffer (Shock Absorber)...")
    conn = sqlite3.connect(MCP_BUFFER_DB)
    conn.execute('''CREATE TABLE IF NOT EXISTS sync_queue 
                    (id INTEGER PRIMARY KEY, payload TEXT, status TEXT)''')
    conn.commit()
    conn.close()

def pull_and_buffer():
    """Reads from Legacy ERP -> Writes to Secure SQLite Buffer."""
    print("[3] MCP Pulling Data: Legacy ERP -> MCP Buffer")
    erp_conn = sqlite3.connect(MOCK_ERP_DB)
    rows = erp_conn.execute("SELECT id, internal_id, status, lat, lng FROM erp_nodes WHERE is_synced=0").fetchall()
    
    if not rows:
        print("    -> No new records to sync.")
        return

    buffer_conn = sqlite3.connect(MCP_BUFFER_DB)
    for row in rows:
        row_id, internal_id, status, lat, lng = row
        
        # We mold the internal legacy data into the Zero-Trust schema (UniversalFilter)
        payload = {
            "node_id": internal_id,
            "status": status,
            "location": {"lat": lat, "lng": lng}
        }
        
        # Inject artificial crisis message to test backend AI parser for one specific node
        if internal_id == "WH-CHICAGO":
            payload["crisis_message"] = "Severe blizzard hitting facility, completely locked down and offline."
            
        print(f"    -> Buffering payload for {internal_id}...")
        buffer_conn.execute('INSERT INTO sync_queue (payload, status) VALUES (?, ?)', (json.dumps(payload), 'pending'))
        
        # Mark as synced in ERP
        erp_conn.execute('UPDATE erp_nodes SET is_synced=1 WHERE id=?', (row_id,))
        
    buffer_conn.commit()
    buffer_conn.close()
    erp_conn.commit()
    erp_conn.close()
    print("    -> Pull complete.\n")

def flush_buffer():
    """Pushes buffered packets from SQLite -> Cloud Ingestion Webhook."""
    print("[4] MCP Flushing Data: MCP Buffer -> Curoot Ingestion API")
    conn = sqlite3.connect(MCP_BUFFER_DB)
    pending = conn.execute('SELECT id, payload FROM sync_queue WHERE status="pending"').fetchall()
    
    if not pending:
         print("    -> Buffer empty. Nothing to flush.")
         conn.close()
         return

    for item_id, payload_str in pending:
        payload = json.loads(payload_str)
        print(f"    -> Transmitting chunk {item_id} (Node: {payload['node_id']})...")
        try:
            # We hit the local backend we have running on port 8000
            resp = requests.post(INGESTION_WEBHOOK, json=payload)
            if resp.status_code == 200:
                print(f"       [SUCCESS] {resp.json()}")
                conn.execute('UPDATE sync_queue SET status="synced" WHERE id=?', (item_id,))
            else:
                 print(f"       [FAILED] {resp.status_code} - {resp.text}")
        except Exception as e:
            print(f"       [ERROR] Connection Error: {e}")
            
    conn.commit()
    conn.close()
    print("    -> Flush complete.\n")

if __name__ == "__main__":
    print("==================================================")
    print("    MCP INTEGRATION TEST ENV (SHOCK ABSORBER)     ")
    print("==================================================")
    
    setup_mock_erp()
    init_mcp_buffer()
    
    print("--- Starting Simulated Sync Cycle ---\n")
    pull_and_buffer()
    
    # Simulate time gap between pulls
    time.sleep(1) 
    
    flush_buffer()
    print("==================================================")
    print("    TEST COMPLETE                                 ")
    print("==================================================")

    # Cleanup artifacts
    if os.path.exists(MOCK_ERP_DB): os.remove(MOCK_ERP_DB)
    if os.path.exists(MCP_BUFFER_DB): os.remove(MCP_BUFFER_DB)
