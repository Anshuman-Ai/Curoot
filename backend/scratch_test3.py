import os
import uuid
import json
from supabase import create_client

os.environ['SUPABASE_URL'] = 'https://cwukaaexndumfivzjctw.supabase.co'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3dWthYWV4bmR1bWZpdnpqY3R3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTc2MDg1MywiZXhwIjoyMDkxMzM2ODUzfQ.-ZWk__IICb0MaA6ddW9IjuOGXIkcdp6yyBs7LJxAeJA'
supabase = create_client(os.environ['SUPABASE_URL'], key)

org_id = '00000000-0000-0000-0000-000000000000'
node_id = '9249f7f9-7019-4f0d-8649-4f526ccaa60a'

try:
    print('Testing event_type=heartbeat...')
    supabase.table("telemetry_events").insert({
        "id": str(uuid.uuid4()),
        "node_id": node_id,
        "organization_id": org_id,
        "event_type": "heartbeat",
        "source": "supplier_chat",
        "payload": {"status": "operational"},
    }).execute()
    print('Heartbeat inserted.')
except Exception as e:
    print('Heartbeat error:', e)

try:
    print('Testing status=on_time...')
    supabase.table("telemetry_events").insert({
        "id": str(uuid.uuid4()),
        "node_id": node_id,
        "organization_id": org_id,
        "event_type": "status_update",
        "status": "on_time",
        "source": "supplier_chat",
        "payload": {"status": "operational"},
    }).execute()
    print('Status_update inserted.')
except Exception as e:
    print('Status_update error:', e)
