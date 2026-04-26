import os
from supabase import create_client

os.environ['SUPABASE_URL'] = 'https://cwukaaexndumfivzjctw.supabase.co'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN3dWthYWV4bmR1bWZpdnpqY3R3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTc2MDg1MywiZXhwIjoyMDkxMzM2ODUzfQ.-ZWk__IICb0MaA6ddW9IjuOGXIkcdp6yyBs7LJxAeJA'
supabase = create_client(os.environ['SUPABASE_URL'], key)

res = supabase.table("users").select("id").limit(1).execute()
print('user:', res.data)
