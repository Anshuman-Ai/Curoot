import os
import httpx

url = 'https://cwukaaexndumfivzjctw.supabase.co/rest/v1/?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3dWthYWV4bmR1bWZpdnpqY3R3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTc2MDg1MywiZXhwIjoyMDkxMzM2ODUzfQ.-ZWk__IICb0MaA6ddW9IjuOGXIkcdp6yyBs7LJxAeJA'
r = httpx.get(url)
import json
data = r.json()
print("communication_logs schema:")
print(json.dumps(data['definitions'].get('communication_logs', {}), indent=2))
print("telemetry_events schema:")
print(json.dumps(data['definitions'].get('telemetry_events', {}), indent=2))
