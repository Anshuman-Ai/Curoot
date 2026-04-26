import os
import uuid
import json
from supabase import create_client

os.environ['SUPABASE_URL'] = 'https://cwukaaexndumfivzjctw.supabase.co'
os.environ['SUPABASE_SERVICE_ROLE_KEY'] = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3dWthYWV4bmR1bWZpdnpqY3R3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTc2MDg1MywiZXhwIjoyMDkxMzM2ODUzfQ.-ZWk__IICb0MaA6ddW9IjuOGXIkcdp6yyBs7LJxAeJA'

supabase = create_client(os.environ['SUPABASE_URL'], os.environ['SUPABASE_SERVICE_ROLE_KEY'])

org_id = '00000000-0000-0000-0000-000000000000' # From the old terminal log
node_id = '9249f7f9-7019-4f0d-8649-4f526ccaa60a'
msg_id = str(uuid.uuid4())

try:
    supabase.table("messages").insert({
        "id": msg_id,
        "sender_org_id": "ffffffff-ffff-ffff-ffff-ffffffffffff",
        "recipient_org_id": org_id,
        "node_id": node_id,
        "body": "test",
        "subject": "supplier_chat",
        "parsed_data": {"status": "operational", "latency_hours": None, "reason": None},
        "parse_confidence": 0.9,
    }).execute()
    print('Messages inserted.')
except Exception as e:
    pass

try:
    print('Testing communication_logs insert...')
    supabase.table("communication_logs").insert({
        "organization_id": org_id,
        "target_node_id": node_id,
        "initiated_by": org_id,
        "message_id": msg_id,
        "channel": "internal_message",
        "external_ref": json.dumps({"parsed_status": "operational", "confidence": 0.9}),
    }).execute()
    print('Logs inserted successfully.')
except Exception as e:
    print('Logs error:', e)
