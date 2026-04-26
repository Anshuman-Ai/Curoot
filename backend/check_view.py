import sys
import os
from dotenv import load_dotenv

# Load .env from root
load_dotenv(os.path.join(os.getcwd(), ".env"))

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), "backend"))

from app.db.supabase import get_supabase_client

def get_view_def():
    supabase = get_supabase_client()
    try:
        # We can run arbitrary SQL via RPC if 'exec_sql' or similar exists,
        # but Supabase client doesn't have a direct 'sql' method.
        # We can try to query pg_views
        # However, PostgREST doesn't expose pg_catalog by default.
        
        # Let's try to query the view directly to see if we can at least see it
        res = supabase.table("vw_supply_chain_nodes_safe").select("*").limit(1).execute()
        print("View exists and is accessible.")
        print(res.data)
    except Exception as e:
        print(f"Failed to access view: {e}")

if __name__ == "__main__":
    get_view_def()
