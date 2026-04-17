"""
Module 2.5B — Macro-Environment Risk Service.

Aggregates geopolitical signals (GDELT), news sentiment (NewsAPI),
and social media sentiment (Reddit) for each country where an org
has active supply-chain nodes. Classifies risk and broadcasts results.
"""

from __future__ import annotations

import logging
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from uuid import UUID

import httpx

from app.core.config import settings
from app.db.supabase import get_supabase_client
from app.models.macro_env import (
    AggregatedSignals,
    GdeltEvent,
    MacroBroadcastPayload,
    NewsAlert,
    RiskClassification,
)
from app.services.risk_classifier import risk_classifier
from app.services.webhooks import AlertBroadcaster
from app.utils.rate_limiter import rate_limiter

logger = logging.getLogger(__name__)

_DEFAULT_NEWS_KEYWORDS = [
    "strike",
    "protest",
    "sanctions",
    "port closure",
    "supply chain",
    "tariff",
]


class MacroEnvService:
    """
    Macro-environment risk aggregator and classifier.

    Data flow per org:
      fetch_gdelt_signals + fetch_news_alerts + fetch_reddit_sentiment
        → AggregatedSignals
        → classify_risk (RiskClassifier)
        → write_macro_signal
        → broadcast to org:{org_id}:macro-panel
    """

    def __init__(self) -> None:
        self._broadcaster = AlertBroadcaster()

    # ------------------------------------------------------------------
    # Top-level scan
    # ------------------------------------------------------------------

    async def run_macro_scan_for_org(self, org_id: UUID) -> List[RiskClassification]:
        """
        1. Fetch all distinct country_codes from supply_chain_nodes for org.
        2. For each country: aggregate signals, classify, write, broadcast.
        3. Return list of RiskClassification results.
        """
        scan_start = time.monotonic()
        logger.info(
            "Starting macro scan",
            extra={"org_id": str(org_id), "action": "run_macro_scan_for_org"},
        )

        supabase = get_supabase_client()
        # RLS: always filter by organization_id
        resp = (
            supabase.table("supply_chain_nodes")
            .select("id, country_code")
            .eq("organization_id", str(org_id))
            .is_("deleted_at", "null")
            .execute()
        )
        nodes = resp.data or []

        # Group node IDs by country_code
        country_nodes: Dict[str, List[UUID]] = {}
        for node in nodes:
            cc = node.get("country_code") or "XX"
            country_nodes.setdefault(cc, []).append(UUID(node["id"]))

        results: List[RiskClassification] = []
        for country_code, node_ids in country_nodes.items():
            try:
                classification = await self._scan_country(
                    country_code, node_ids, org_id
                )
                results.append(classification)
            except Exception as exc:  # noqa: BLE001
                logger.error(
                    "Macro scan failed for country %s: %s", country_code, exc,
                    extra={"org_id": str(org_id), "action": "scan_country"},
                )

        duration_ms = int((time.monotonic() - scan_start) * 1000)
        logger.info(
            "Macro scan complete",
            extra={
                "org_id": str(org_id),
                "action": "run_macro_scan_for_org",
                "countries_scanned": len(country_nodes),
                "duration_ms": duration_ms,
            },
        )
        return results

    async def _scan_country(
        self,
        country_code: str,
        node_ids: List[UUID],
        org_id: UUID,
    ) -> RiskClassification:
        """Aggregate all signals for one country and produce a classification."""
        gdelt_events = await self.fetch_gdelt_signals(country_code)
        news_alerts = await self.fetch_news_alerts(country_code, _DEFAULT_NEWS_KEYWORDS)
        reddit_sentiment = await self.fetch_reddit_sentiment(
            "supplychain", _DEFAULT_NEWS_KEYWORDS
        )

        signals = AggregatedSignals(
            country_code=country_code,
            gdelt_events=gdelt_events,
            news_alerts=news_alerts,
            reddit_sentiment=reddit_sentiment,
            collected_at=datetime.now(timezone.utc),
        )

        classification = risk_classifier.classify(signals, affected_node_ids=node_ids)
        await self.write_macro_signal(classification, org_id)
        return classification

    # ------------------------------------------------------------------
    # GDELT 2.0
    # ------------------------------------------------------------------

    async def fetch_gdelt_signals(
        self, country_code: str, days_back: int = 3
    ) -> List[GdeltEvent]:
        """
        GDELT API: /api/v2/doc/doc?query=sourceCountry:{cc}&mode=artlist&format=json
        Filters: goldstein_scale < -5 OR tone < -10
        """
        await rate_limiter.acquire("gdelt")
        url = f"{settings.GDELT_BASE_URL}/doc/doc"
        params = {
            "query": f"sourceCountry:{country_code}",
            "mode": "artlist",
            "format": "json",
            "maxrecords": 50,
        }

        t0 = time.monotonic()
        async with httpx.AsyncClient(timeout=15.0) as client:
            try:
                resp = await client.get(url, params=params)
                resp.raise_for_status()
                duration_ms = int((time.monotonic() - t0) * 1000)
                logger.info(
                    "GDELT response",
                    extra={
                        "action": "fetch_gdelt_signals",
                        "url": url,
                        "status": resp.status_code,
                        "duration_ms": duration_ms,
                        "country_code": country_code,
                    },
                )
                data = resp.json()
            except httpx.HTTPError as exc:
                logger.warning("GDELT request failed for %s: %s", country_code, exc)
                return []

        articles = data.get("articles") or []
        events: List[GdeltEvent] = []
        for article in articles:
            try:
                goldstein = float(article.get("goldstein", 0.0))
                tone = float(article.get("tone", 0.0))
                # Only keep high-conflict signals per spec
                if goldstein >= _HIGH_GOLDSTEIN_THRESHOLD and tone >= _HIGH_TONE_THRESHOLD:
                    continue
                events.append(
                    GdeltEvent(
                        url=article.get("url", ""),
                        title=article.get("title", ""),
                        goldstein_scale=goldstein,
                        tone=tone,
                        country_code=country_code,
                        event_date=_parse_gdelt_date(article.get("seendate", "")),
                    )
                )
            except Exception:  # noqa: BLE001
                continue

        return events

    # ------------------------------------------------------------------
    # NewsAPI
    # ------------------------------------------------------------------

    async def fetch_news_alerts(
        self, country_code: str, keywords: List[str]
    ) -> List[NewsAlert]:
        """
        NewsAPI: /v2/everything?q={keywords}&language=en&sortBy=publishedAt
        Rate limit: 2 req/min enforced via shared rate_limiter.
        """
        if not settings.NEWSAPI_KEY:
            logger.warning("NEWSAPI_KEY not set — skipping news fetch")
            return []

        await rate_limiter.acquire("newsapi")
        query = " OR ".join(f'"{kw}"' for kw in keywords)
        url = "https://newsapi.org/v2/everything"
        params = {
            "q": query,
            "language": "en",
            "sortBy": "publishedAt",
            "pageSize": 20,
            "apiKey": settings.NEWSAPI_KEY,
        }

        t0 = time.monotonic()
        async with httpx.AsyncClient(timeout=15.0) as client:
            try:
                resp = await client.get(url, params=params)
                resp.raise_for_status()
                duration_ms = int((time.monotonic() - t0) * 1000)
                logger.info(
                    "NewsAPI response",
                    extra={
                        "action": "fetch_news_alerts",
                        "status": resp.status_code,
                        "duration_ms": duration_ms,
                        "country_code": country_code,
                    },
                )
                data = resp.json()
            except httpx.HTTPError as exc:
                logger.warning("NewsAPI request failed for %s: %s", country_code, exc)
                return []

        alerts: List[NewsAlert] = []
        for article in data.get("articles", []):
            title = article.get("title") or ""
            description = article.get("description") or ""
            sentiment = _simple_sentiment(title + " " + description, keywords)
            alerts.append(
                NewsAlert(
                    title=title,
                    description=description,
                    published_at=datetime.fromisoformat(
                        article.get("publishedAt", datetime.now(timezone.utc).isoformat())
                        .replace("Z", "+00:00")
                    ),
                    source_name=(article.get("source") or {}).get("name", ""),
                    url=article.get("url", ""),
                    sentiment_score=sentiment,
                )
            )
        return alerts

    # ------------------------------------------------------------------
    # Reddit OAuth2 sentiment
    # ------------------------------------------------------------------

    async def fetch_reddit_sentiment(
        self, subreddit: str, keywords: List[str]
    ) -> float:
        """
        Reddit OAuth2: GET /r/{subreddit}/search.json?q={keyword}&sort=new&limit=25
        Sentiment = weighted average of upvote_ratio by num_comments.
        Returns score in range -1.0 → 1.0.
        """
        if not (settings.REDDIT_CLIENT_ID and settings.REDDIT_CLIENT_SECRET):
            logger.warning("Reddit credentials not set — skipping sentiment fetch")
            return 0.0

        await rate_limiter.acquire("reddit")
        token = await self._get_reddit_token()
        if not token:
            return 0.0

        query = " ".join(keywords[:3])  # keep URL size reasonable
        url = f"https://oauth.reddit.com/r/{subreddit}/search.json"
        params = {"q": query, "sort": "new", "limit": 25, "restrict_sr": "false"}
        headers = {
            "Authorization": f"Bearer {token}",
            "User-Agent": "Curoot-MacroEnv/1.0 (by /u/curoot_bot)",
        }

        t0 = time.monotonic()
        async with httpx.AsyncClient(timeout=15.0) as client:
            try:
                resp = await client.get(url, params=params, headers=headers)
                resp.raise_for_status()
                duration_ms = int((time.monotonic() - t0) * 1000)
                logger.info(
                    "Reddit response",
                    extra={
                        "action": "fetch_reddit_sentiment",
                        "status": resp.status_code,
                        "duration_ms": duration_ms,
                    },
                )
                data = resp.json()
            except httpx.HTTPError as exc:
                logger.warning("Reddit request failed: %s", exc)
                return 0.0

        posts = (data.get("data") or {}).get("children") or []
        total_weight = 0.0
        weighted_score = 0.0
        for post in posts:
            pdata = post.get("data", {})
            upvote_ratio: float = float(pdata.get("upvote_ratio", 0.5))
            num_comments: int = int(pdata.get("num_comments", 0))
            weight = max(num_comments, 1)
            # Map upvote_ratio [0,1] → sentiment [-1,1]
            sentiment = (upvote_ratio * 2) - 1
            weighted_score += sentiment * weight
            total_weight += weight

        if total_weight == 0:
            return 0.0
        return max(-1.0, min(1.0, weighted_score / total_weight))

    # ------------------------------------------------------------------
    # Write & Broadcast
    # ------------------------------------------------------------------

    async def write_macro_signal(
        self, classification: RiskClassification, org_id: UUID
    ) -> None:
        """
        Writes a row to macro_environment_signals and broadcasts
        to org:{org_id}:macro-panel via Supabase Realtime.
        """
        t0 = time.monotonic()
        supabase = get_supabase_client()
        row = {
            "country_code": classification.country_code,
            "signal_type": "macro_env",
            "risk_level": classification.risk_level.value,
            "payload": {
                "confidence": classification.confidence,
                "primary_driver": classification.primary_driver,
                "affected_node_ids": [str(n) for n in classification.affected_node_ids],
                "signals_summary": classification.signals_summary,
                "org_id": str(org_id),
            },
            "created_at": classification.classified_at.isoformat(),
        }
        supabase.table("macro_environment_signals").insert(row).execute()
        duration_ms = int((time.monotonic() - t0) * 1000)
        logger.info(
            "Wrote macro signal",
            extra={
                "action": "write_macro_signal",
                "org_id": str(org_id),
                "country_code": classification.country_code,
                "risk_level": classification.risk_level.value,
                "duration_ms": duration_ms,
            },
        )

        payload = MacroBroadcastPayload(
            country_code=classification.country_code,
            risk_level=classification.risk_level,
            confidence=classification.confidence,
            primary_driver=classification.primary_driver,
            signals_summary=classification.signals_summary,
        )
        await self._broadcaster.broadcast_macro_update(org_id, payload)

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    async def _get_reddit_token(self) -> Optional[str]:
        """Obtain a Reddit OAuth2 application-only bearer token."""
        auth = httpx.BasicAuth(
            settings.REDDIT_CLIENT_ID, settings.REDDIT_CLIENT_SECRET
        )
        data = {"grant_type": "client_credentials"}
        headers = {"User-Agent": "Curoot-MacroEnv/1.0 (by /u/curoot_bot)"}
        async with httpx.AsyncClient(timeout=10.0) as client:
            try:
                resp = await client.post(
                    "https://www.reddit.com/api/v1/access_token",
                    auth=auth,
                    data=data,
                    headers=headers,
                )
                resp.raise_for_status()
                return resp.json().get("access_token")
            except httpx.HTTPError as exc:
                logger.warning("Reddit auth failed: %s", exc)
                return None


# ------------------------------------------------------------------
# Module-level constants & helpers
# ------------------------------------------------------------------

_HIGH_GOLDSTEIN_THRESHOLD = -5.0  # keep events below this
_HIGH_TONE_THRESHOLD = -10.0      # keep events below this

_NEGATIVE_KEYWORDS = [
    "strike", "protest", "closure", "sanction", "tariff", "disruption",
    "delay", "shortage", "crisis", "conflict", "war", "ban",
]


def _simple_sentiment(text: str, keywords: List[str]) -> float:
    """
    Keyword-based sentiment heuristic.
    Returns a score in [-1, 1] based on presence of negative supply-chain terms.
    """
    text_lower = text.lower()
    hits = sum(1 for kw in _NEGATIVE_KEYWORDS if kw in text_lower)
    # Normalise to [-1, 0] since we only have negative signals
    return max(-1.0, -(hits / max(len(_NEGATIVE_KEYWORDS), 1)))


def _parse_gdelt_date(date_str: str) -> datetime:
    """Parse GDELT seendate format YYYYMMDDTHHMMSSZ."""
    try:
        # GDELT returns format like '20240115T123456Z'
        return datetime.strptime(date_str, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)
    except (ValueError, TypeError):
        return datetime.now(timezone.utc)
