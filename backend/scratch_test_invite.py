import urllib.request, json

req = urllib.request.Request(
    'http://127.0.0.1:8000/api/v1/invitations/create',
    data=json.dumps({
        'organization_id': '00000000-0000-0000-0000-000000000000',
        'name': 'Acme',
        'email': 'test@example.com',
        'connection_type': 'upstream',
        'phone': '1234567890',
        'channel': 'whatsapp'
    }).encode('utf-8'),
    headers={'Content-Type': 'application/json'}
)

try:
    res = urllib.request.urlopen(req)
    print(res.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    print(e.read().decode('utf-8'))
