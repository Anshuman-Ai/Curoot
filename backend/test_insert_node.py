import sys
import os
import uuid
from dotenv import load_dotenv

# Load .env from root
load_dotenv(os.path.join(os.getcwd(), ".env"))

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), "backend"))

from app.db.supabase import get_supabase_client

def test_insert():
    supabase = get_supabase_client()
    org_id = "00000000-0000-0000-0000-000000000000"
    db_id = str(uuid.uuid4())
    
    row = {
        "id": db_id,
        "organization_id": org_id,
        "name": "Test Node",
        "node_type": "supplier",
        "status": "operational",
        "location": f"POINT(120.0 30.0)",
        "country_code": "CN",
        "metadata": {"source": "test"},
    }
    
    print(f"Attempting to insert node with ID: {db_id}")
    try:
        res = supabase.table("supply_chain_nodes").insert(row).execute()
        print("Insert successful!")
        print(res.data)
    except Exception as e:
        print(f"Insert failed: {e}")

if __name__ == "__main__":
    test_insert()
