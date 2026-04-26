import os
from app.db.supabase import get_supabase_client
import uuid

def seed():
    supabase = get_supabase_client()
    dummy_org_id = "ffffffff-ffff-ffff-ffff-ffffffffffff"
    
    row = {
        "id": dummy_org_id,
        "name": "External Unregistered Supplier",
        "slug": "external-supplier",
        "org_tier": "startup",
        "primary_contact_email": "external@example.com",
        "country_code": "US"
    }
    
    try:
        supabase.table("organizations").upsert(row).execute()
        print("External supplier org seeded.")
    except Exception as e:
        print("Error seeding:", e)

if __name__ == "__main__":
    seed()
