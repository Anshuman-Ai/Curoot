import sys, os
sys.path.append(os.path.join(os.getcwd(), 'backend'))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.getcwd(), '.env'))
from app.db.supabase import get_supabase_client

supabase = get_supabase_client()
res = supabase.auth.admin.list_users()
users = getattr(res, 'users', getattr(res, 'data', []))
print("Users:", [u.id for u in users] if users else "No users")
