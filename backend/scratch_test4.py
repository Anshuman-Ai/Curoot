import os
import uuid
from supabase import create_client

os.environ['SUPABASE_URL'] = 'https://cwukaaexndumfivzjctw.supabase.co'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3dWthYWV4bmR1bWZpdnpqY3R3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTc2MDg1MywiZXhwIjoyMDkxMzM2ODUzfQ.-ZWk__IICb0MaA6ddW9IjuOGXIkcdp6yyBs7LJxAeJA'
supabase = create_client(os.environ['SUPABASE_URL'], key)

org_id = '00000000-0000-0000-0000-000000000000'
node_id = '9249f7f9-7019-4f0d-8649-4f526ccaa60a'

try:
    print('Testing status=active...')
    supabase.table("telemetry_events").insert({
        "id": str(uuid.uuid4()),
        "node_id": node_id,
        "organization_id": org_id,
        "event_type": "status_update",
        "status": "active",
        "source": "supplier_chat",
        "payload": {"status": "operational"},
    }).execute()
    print('Success!')
except Exception as e:
    print('Error:', e)

try:
    print('Testing event_type=heartbeat, status=active...')
    supabase.table("telemetry_events").insert({
        "id": str(uuid.uuid4()),
        "node_id": node_id,
        "organization_id": org_id,
        "event_type": "heartbeat",
        "status": "active",
        "source": "supplier_chat",
        "payload": {"status": "operational"},
    }).execute()
    print('Success!')
except Exception as e:
    print('Error:', e)
