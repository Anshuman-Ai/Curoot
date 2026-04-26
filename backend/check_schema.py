import urllib.request
import json
import os

url = "https://cwukaaexndumfivzjctw.supabase.co/rest/v1/?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3dWthYWV4bmR1bWZpdnpqY3R3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3NjA4NTMsImV4cCI6MjA5MTMzNjg1M30.xeKLd-H6ujznV3IuDedhSNgBc3mL1xY6xOYL4wTBVj8"

try:
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode())
        
    print("Definitions found:", list(data.get("definitions", {}).keys()))
    
    if "ingestion_jobs" in data.get("definitions", {}):
        print("ingestion_jobs properties:", list(data["definitions"]["ingestion_jobs"]["properties"].keys()))
    else:
        print("ingestion_jobs table NOT FOUND in PostgREST schema")
        
except Exception as e:
    print("Error:", e)
