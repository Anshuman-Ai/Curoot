import sys, os
sys.path.append(os.path.join(os.getcwd(), 'backend'))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.getcwd(), '.env'))
from app.db.supabase import get_supabase_client

supabase = get_supabase_client()
try:
    supabase.table('node_invitations').select('invalid_column').execute()
except Exception as e:
    print(e)
