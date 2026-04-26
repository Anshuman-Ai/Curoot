"""
Quick fix: ensure tradeoff_metrics has the metric_type column.
Uses the Supabase service_role key to call the PostgREST schema-cache reload
and verifies the table is writable with all required columns.
"""
import os, sys, httpx
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

SUPABASE_URL = os.getenv("SUPABASE_URL")
SERVICE_KEY  = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation",
}

def check_columns():
    """Try to read tradeoff_metrics and see what columns come back."""
    url = f"{SUPABASE_URL}/rest/v1/tradeoff_metrics?select=*&limit=0"
    resp = httpx.get(url, headers=HEADERS)
    print(f"GET tradeoff_metrics: {resp.status_code}")
    if resp.status_code == 200:
        print("  Table is accessible via REST. Schema cache is valid.")
    else:
        print(f"  Response: {resp.text}")

def try_insert_and_delete():
    """Insert a dummy metric row to confirm all columns work, then delete it."""
    # First we need a valid analysis_id. Let's check if any exist.
    url = f"{SUPABASE_URL}/rest/v1/tradeoff_analyses?select=id&limit=1"
    resp = httpx.get(url, headers=HEADERS)
    analyses = resp.json() if resp.status_code == 200 else []
    
    if not analyses:
        print("No tradeoff_analyses rows exist. Inserting a test analysis first...")
        # Insert a minimal analysis row
        test_analysis = {
            "organization_id": "00000000-0000-0000-0000-000000000000",
            "initiated_by": "00000000-0000-0000-0000-000000000000",
            "overall_recommendation": "investigate",
            "recommendation_confidence": 0.5,
        }
        r = httpx.post(
            f"{SUPABASE_URL}/rest/v1/tradeoff_analyses",
            headers=HEADERS, json=test_analysis
        )
        if r.status_code in (200, 201):
            analysis_id = r.json()[0]["id"]
            print(f"  Created test analysis: {analysis_id}")
        else:
            print(f"  Failed to create test analysis: {r.status_code} {r.text}")
            return
    else:
        analysis_id = analyses[0]["id"]
        print(f"Using existing analysis: {analysis_id}")

    # Try inserting a metric row with all required columns
    test_metric = {
        "analysis_id": analysis_id,
        "metric_type": "__test__",
        "current_value": 0.0,
        "alternative_value": 0.0,
        "delta": 0.0,
        "unit": "test",
    }
    url = f"{SUPABASE_URL}/rest/v1/tradeoff_metrics"
    r = httpx.post(url, headers=HEADERS, json=test_metric)
    if r.status_code in (200, 201):
        metric_id = r.json()[0]["id"]
        print(f"  [OK] INSERT succeeded -- metric_type column EXISTS. id={metric_id}")
        # Clean up
        httpx.delete(
            f"{SUPABASE_URL}/rest/v1/tradeoff_metrics?id=eq.{metric_id}",
            headers=HEADERS
        )
        print(f"  Cleaned up test row.")
    else:
        print(f"  [FAIL] INSERT FAILED: {r.status_code}")
        print(f"  Response: {r.text}")
        print()
        print("  [!] You must run the following SQL in the Supabase SQL Editor:")
        print("     Dashboard → SQL Editor → New Query → Paste & Run:")
        print()
        print("  ALTER TABLE tradeoff_metrics ADD COLUMN IF NOT EXISTS metric_type TEXT;")
        print("  ALTER TABLE tradeoff_metrics ADD COLUMN IF NOT EXISTS current_value DOUBLE PRECISION;")
        print("  ALTER TABLE tradeoff_metrics ADD COLUMN IF NOT EXISTS alternative_value DOUBLE PRECISION;")
        print("  ALTER TABLE tradeoff_metrics ADD COLUMN IF NOT EXISTS delta DOUBLE PRECISION;")
        print("  ALTER TABLE tradeoff_metrics ADD COLUMN IF NOT EXISTS unit TEXT;")
        print("  NOTIFY pgrst, 'reload schema';")

if __name__ == "__main__":
    print("=== Checking tradeoff_metrics schema ===")
    check_columns()
    print()
    print("=== Testing INSERT with all required columns ===")
    try_insert_and_delete()
