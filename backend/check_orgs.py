import sys
import os
from dotenv import load_dotenv

# Load .env from root
load_dotenv(os.path.join(os.getcwd(), ".env"))

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), "backend"))

from app.db.supabase import get_supabase_client

def check_orgs():
    supabase = get_supabase_client()
    try:
        res = supabase.table("organizations").select("id, name").execute()
        print(f"Total organizations: {len(res.data)}")
        for org in res.data:
            print(f"- {org['name']} ({org['id']})")
    except Exception as e:
        print(f"Failed to fetch organizations: {e}")

if __name__ == "__main__":
    check_orgs()
