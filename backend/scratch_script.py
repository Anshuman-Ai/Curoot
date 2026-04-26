import os
import httpx

url = 'https://cwukaaexndumfivzjctw.supabase.co/rest/v1/communication_logs'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3dWthYWV4bmR1bWZpdnpqY3R3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTc2MDg1MywiZXhwIjoyMDkxMzM2ODUzfQ.-ZWk__IICb0MaA6ddW9IjuOGXIkcdp6yyBs7LJxAeJA'
headers = {
    'apikey': key,
    'Authorization': f'Bearer {key}'
}
r = httpx.options(url, headers=headers)
print(r.text)

url2 = 'https://cwukaaexndumfivzjctw.supabase.co/rest/v1/telemetry_events'
r2 = httpx.options(url2, headers=headers)
print(r2.text)
