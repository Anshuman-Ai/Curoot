import os, json, urllib.request
from app.core.config import settings

url = f"{settings.SUPABASE_URL}/graphql/v1"
headers = {
    'apikey': settings.SUPABASE_SERVICE_ROLE_KEY,
    'Content-Type': 'application/json'
}
data = json.dumps({'query': '{ __type(name: "telemetry_events") { fields { name } } }'}).encode('utf-8')
req = urllib.request.Request(url, headers=headers, data=data)
print(urllib.request.urlopen(req).read().decode())
