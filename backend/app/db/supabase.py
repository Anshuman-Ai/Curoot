import json
import base64
import logging
from supabase import create_client, Client
from app.core.config import settings

logger = logging.getLogger(__name__)


def _extract_jwt_ref(token: str) -> str | None:
    """Extract the 'ref' (project ID) from a Supabase JWT without verification."""
    try:
        payload_b64 = token.split(".")[1]
        # Add padding if needed
        payload_b64 += "=" * (-len(payload_b64) % 4)
        payload = json.loads(base64.urlsafe_b64decode(payload_b64))
        return payload.get("ref")
    except Exception:
        return None


def _pick_key() -> str:
    """
    Pick the best available Supabase key.

    Uses service_role if it matches the project in SUPABASE_URL,
    otherwise falls back to anon key.
    """
    url_ref = settings.SUPABASE_URL.replace("https://", "").split(".")[0]

    if settings.SUPABASE_SERVICE_ROLE_KEY:
        sr_ref = _extract_jwt_ref(settings.SUPABASE_SERVICE_ROLE_KEY)
        if sr_ref == url_ref:
            logger.info("Using Supabase service_role key (project: %s)", url_ref)
            return settings.SUPABASE_SERVICE_ROLE_KEY
        else:
            logger.warning(
                "SUPABASE_SERVICE_ROLE_KEY is for project '%s' but URL is for '%s'. "
                "Falling back to anon key.",
                sr_ref, url_ref,
            )

    if settings.SUPABASE_ANON_KEY:
        logger.info("Using Supabase anon key (project: %s)", url_ref)
        return settings.SUPABASE_ANON_KEY

    logger.error("No valid Supabase key found!")
    return ""


def get_supabase_client() -> Client:
    """Create and return a Supabase client with the best available key."""
    key = _pick_key()
    supabase: Client = create_client(settings.SUPABASE_URL, key)
    return supabase
