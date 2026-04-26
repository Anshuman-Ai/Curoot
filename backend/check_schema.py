import urllib.request
import json
import os

url = "https://cwukaaexndumfivzjctw.supabase.co/rest/v1/?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3dWthYWV4bmR1bWZpdnpqY3R3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NjA4NTMsImV4cCI6MjA5MTMzNjg1M30.xeKLd-H6ujznV3IuDedhSNgBc3mL1xY6xOYL4wTBVj8"

try:
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        
    print("Definitions found:", list(data.get("definitions", {}).keys()))
    
    if "messages" in data.get("definitions", {}):
        print("messages properties:", list(data["definitions"]["messages"]["properties"].keys()))
    if "node_edges" in data.get("definitions", {}):
        print("node_edges properties:", list(data["definitions"]["node_edges"]["properties"].keys()))
        print("node_edges connection_type format:", data["definitions"]["node_edges"]["properties"].get("connection_type"))
        
except Exception as e:
    print("Error:", e)
