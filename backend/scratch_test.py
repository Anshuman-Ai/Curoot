import httpx
import json

url = 'http://127.0.0.1:8000/supplier/chat/IxBWYkX5j0NcYJwwfajPXYfM8wHVYU4fxs3dfDsWOEjLN1HMO2pWuBaesgbuS7ZO'
headers = {'Content-Type': 'application/json'}
data = {'message': 'This is a test message from the scratch script.'}

r = httpx.post(url, headers=headers, json=data, timeout=30.0)
print('Status:', r.status_code)
print('Response:', r.text)
