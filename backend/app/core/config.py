import os
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "Curoot Backend API"

    # ------------------------------------------------------------------
    # Supabase (already present)
    # ------------------------------------------------------------------
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_ANON_KEY: str = os.getenv("SUPABASE_ANON_KEY", "")
    SUPABASE_SERVICE_ROLE_KEY: str = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

    # ------------------------------------------------------------------
    # AI Services
    # ------------------------------------------------------------------
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")

    # ------------------------------------------------------------------
    # Module 2.5 / 2.6 — External API keys (free tier)
    # ------------------------------------------------------------------
    # NewsAPI — https://newsapi.org  (free: 100 req/day)
    NEWSAPI_KEY: str = os.getenv("NEWSAPI_KEY", "")

    # Reddit OAuth2 — https://www.reddit.com/prefs/apps
    REDDIT_CLIENT_ID: str = os.getenv("REDDIT_CLIENT_ID", "")
    REDDIT_CLIENT_SECRET: str = os.getenv("REDDIT_CLIENT_SECRET", "")

    # OpenRouteService — https://openrouteservice.org (free: 2000 req/day)
    OPENROUTE_KEY: str = os.getenv("OPENROUTE_KEY", "")

    # ------------------------------------------------------------------
    # External API base URLs (no auth required)
    # ------------------------------------------------------------------
    OPENMETEO_BASE_URL: str = "https://api.open-meteo.com/v1"
    GDELT_BASE_URL: str = "http://api.gdeltproject.org/api/v2"
    OPENROUTE_BASE_URL: str = "https://api.openrouteservice.org"
    NOMINATIM_BASE_URL: str = "https://nominatim.openstreetmap.org"

    model_config = SettingsConfigDict(env_file="../.env", extra="ignore")


settings = Settings()

