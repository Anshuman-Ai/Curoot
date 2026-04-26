import sys, os
sys.path.append(os.path.join(os.getcwd(), 'backend'))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.getcwd(), '.env'))
from app.db.supabase import get_supabase_client

supabase = get_supabase_client()
res = supabase.auth.admin.list_users()
users = getattr(res, 'users', getattr(res, 'data', []))

if not users:
    print("Creating demo user...")
    new_user = supabase.auth.admin.create_user({
        "email": "demo@curoot.com",
        "password": "Password123!",
        "email_confirm": True
    })
    print("Created user:", new_user.user.id)
else:
    print("Existing user:", users[0].id)
