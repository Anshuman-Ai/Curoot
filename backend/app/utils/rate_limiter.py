"""
Shared async rate limiter for all external API integrations.

Uses a token-bucket algorithm per service. Call `await rate_limiter.acquire(service)`
before any external HTTP request.
"""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Dict, Tuple

logger = logging.getLogger(__name__)

# (max_requests, period_seconds)
_DEFAULT_LIMITS: Dict[str, Tuple[int, float]] = {
    "newsapi": (2, 60),           # 2 req/min
    "nominatim": (1, 1),          # 1 req/sec
    "openmeteo": (60, 60),        # 60 req/min
    "gdelt": (30, 60),            # 30 req/min (conservative)
    "reddit": (60, 60),           # 60 req/min
    "openrouteservice": (40, 60), # 40 req/min (free tier)
}


class _ServiceBucket:
    """Token bucket rate limiter for a single service."""

    def __init__(self, max_requests: int, period_seconds: float) -> None:
        self.max_requests = max_requests
        self.period_seconds = period_seconds
        self._tokens = float(max_requests)
        self._last_refill = time.monotonic()
        self._lock = asyncio.Lock()

    async def acquire(self) -> None:
        async with self._lock:
            while True:
                now = time.monotonic()
                elapsed = now - self._last_refill
                # Refill tokens proportional to elapsed time
                refill = elapsed * (self.max_requests / self.period_seconds)
                self._tokens = min(self.max_requests, self._tokens + refill)
                self._last_refill = now

                if self._tokens >= 1:
                    self._tokens -= 1
                    return

                # Calculate wait time until next token is available
                deficit = 1 - self._tokens
                wait_time = deficit / (self.max_requests / self.period_seconds)
                logger.debug(
                    "Rate limiter: waiting %.2fs for next token", wait_time
                )
                await asyncio.sleep(wait_time)


class RateLimiter:
    """
    Shared singleton rate limiter for all external services.

    Usage::

        await rate_limiter.acquire("openmeteo")
        response = await client.get(url)
    """

    limits: Dict[str, Tuple[int, float]] = _DEFAULT_LIMITS

    def __init__(self) -> None:
        self._buckets: Dict[str, _ServiceBucket] = {
            service: _ServiceBucket(max_req, period)
            for service, (max_req, period) in self.limits.items()
        }

    async def acquire(self, service: str) -> None:
        """Block until a request slot is available for *service*."""
        bucket = self._buckets.get(service)
        if bucket is None:
            logger.warning(
                "RateLimiter: unknown service '%s' — no rate limiting applied", service
            )
            return
        await bucket.acquire()
        logger.debug("RateLimiter: acquired slot for service '%s'", service)


# Module-level singleton — import and use this everywhere
rate_limiter = RateLimiter()
