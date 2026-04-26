import urllib.request, json, os

url = 'https://cwukaaexndumfivzjctw.supabase.co/rest/v1/?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3dWthYWV4bmR1bWZpdnpqY3R3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NjA4NTMsImV4cCI6MjA5MTMzNjg1M30.xeKLd-H6ujznV3IuDedhSNgBc3mL1xY6xOYL4wTBVj8'
req = urllib.request.Request(url)
req.add_header('Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3dWthYWV4bmR1bWZpdnpqY3R3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NjA4NTMsImV4cCI6MjA5MTMzNjg1M30.xeKLd-H6ujznV3IuDedhSNgBc3mL1xY6xOYL4wTBVj8')

try:
    data = json.loads(urllib.request.urlopen(req).read().decode())
    props = data['definitions'].get('node_invitations', {}).get('properties', {})
    print("node_invitations properties:", list(props.keys()))
except Exception as e:
    print(e)
