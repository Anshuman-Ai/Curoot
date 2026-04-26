import sys
import os
from dotenv import load_dotenv

# Load .env from root
load_dotenv(os.path.join(os.getcwd(), ".env"))

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), "backend"))

from app.db.supabase import get_supabase_client

DEMO_ORG_ID = "00000000-0000-0000-0000-000000000000"

def seed():
    supabase = get_supabase_client()
    
    # Check if org exists
    res = supabase.table('organizations').select('id').eq('id', DEMO_ORG_ID).execute()
    if not res.data:
        print(f"Seeding demo organization: {DEMO_ORG_ID}")
        try:
            # Use 'upsert' just in case, but insert is fine too since we checked
            supabase.table('organizations').insert({
                "id": DEMO_ORG_ID,
                "name": "Demo Organization",
                "slug": "demo-ingestion"
            }).execute()
            print("Demo organization seeded successfully.")
        except Exception as e:
            print(f"Failed to seed demo organization: {e}")
    else:
        print(f"Demo organization already exists: {res.data[0]['id']}")

if __name__ == "__main__":
    seed()
