from supabase import create_client, Client
from app.core.config import settings

def get_supabase_client() -> Client:
    # Use service role key to bypass row-level-security (RLS) on backend if needed
    # Fallback to anon key if service role is not set
    key = settings.SUPABASE_SERVICE_ROLE_KEY or settings.SUPABASE_ANON_KEY
    supabase: Client = create_client(settings.SUPABASE_URL, key)
    return supabase

supabase_client = get_supabase_client()
