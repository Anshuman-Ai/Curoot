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
    res = supabase.table('magic_link_tokens').select('*, supply_chain_nodes(id, name, organization_id, organizations!fk_nodes_org(name))').limit(1).execute()
    print("Table select successful:", res.data)
except Exception as e:
    import traceback
    traceback.print_exc()
    print("Table select failed:", e)
