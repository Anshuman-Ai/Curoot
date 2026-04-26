import asyncio
from app.db.supabase import get_supabase_client

supabase = get_supabase_client()
try:
    res = supabase.rpc('reload_schema', {}).execute()
    print("Schema reload successful:", res)
except Exception as e:
    print("Failed to reload schema via RPC:", e)

# Try fetching a table to see if it exists
try:
    res = supabase.table('supply_chain_nodes').select('*').limit(1).execute()
    print("Table select successful:", res)
except Exception as e:
    print("Table select failed:", e)
