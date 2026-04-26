"""
FastAPI application entry point.

Registers all API routers and APScheduler background jobs for
Modules 2.5 (disruption/macro scans), 2.6 (insights/tradeoffs),
and 2.7 (Heartbeat & AI-Assisted Remote Control).
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from typing import AsyncIterator

from pathlib import Path

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.v1.endpoints import (
    discovery,
    disruption,
    heartbeat,
    ingestion,
    invitations,
    macro_env,
    marketplace,
    mcp_mgr,
    supplier_chat,
    telemetry,
    tradeoffs,
)
from app.core.config import settings
from app.db.supabase import get_supabase_client


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# APScheduler background jobs
# ---------------------------------------------------------------------------

scheduler = AsyncIOScheduler()


async def run_all_disruption_scans() -> None:
    """Iterate over all active organisations and run a disruption scan for each."""
    from app.services.disruption_service import DisruptionService  # lazy import
    _disruption_svc = DisruptionService()
    logger.info("APScheduler: starting disruption scans for all orgs")
    supabase = get_supabase_client()
    try:
        resp = (
            supabase.table("supply_chain_nodes")
            .select("organization_id")
            .is_("deleted_at", "null")
            .execute()
        )
        org_ids = {row["organization_id"] for row in (resp.data or [])}
        for org_id_str in org_ids:
            from uuid import UUID
            try:
                await _disruption_svc.run_disruption_scan(UUID(org_id_str))
            except Exception as exc:  # noqa: BLE001
                logger.error("Disruption scan error for org %s: %s", org_id_str, exc)
    except Exception as exc:  # noqa: BLE001
        logger.error("run_all_disruption_scans failed: %s", exc)


async def run_all_macro_scans() -> None:
    """Iterate over all active organisations and run a macro-environment scan."""
    from app.services.macro_env_service import MacroEnvService  # lazy import
    _macro_svc = MacroEnvService()
    logger.info("APScheduler: starting macro scans for all orgs")
    supabase = get_supabase_client()
    try:
        resp = (
            supabase.table("supply_chain_nodes")
            .select("organization_id")
            .is_("deleted_at", "null")
            .execute()
        )
        org_ids = {row["organization_id"] for row in (resp.data or [])}
        for org_id_str in org_ids:
            from uuid import UUID
            try:
                await _macro_svc.run_macro_scan_for_org(UUID(org_id_str))
            except Exception as exc:  # noqa: BLE001
                logger.error("Macro scan error for org %s: %s", org_id_str, exc)
    except Exception as exc:  # noqa: BLE001
        logger.error("run_all_macro_scans failed: %s", exc)


async def run_all_dark_node_scans() -> None:
    """Iterate over all active organisations and scan for dark nodes."""
    from app.services.dark_node_engine import dark_node_engine  # lazy import
    logger.info("APScheduler: starting dark node scans for all orgs")
    supabase = get_supabase_client()
    try:
        resp = (
            supabase.table("supply_chain_nodes")
            .select("organization_id")
            .is_("deleted_at", "null")
            .execute()
        )
        org_ids = {row["organization_id"] for row in (resp.data or [])}
        for org_id_str in org_ids:
            from uuid import UUID
            try:
                await dark_node_engine.scan_for_dark_nodes(UUID(org_id_str))
            except Exception as exc:  # noqa: BLE001
                logger.error("Dark node scan error for org %s: %s", org_id_str, exc)
    except Exception as exc:  # noqa: BLE001
        logger.error("run_all_dark_node_scans failed: %s", exc)


async def run_all_auto_pings() -> None:
    """Iterate over all active organisations and auto-ping critical dark nodes."""
    from app.services.dark_node_engine import dark_node_engine  # lazy import
    logger.info("APScheduler: starting auto-ping for all orgs")
    supabase = get_supabase_client()
    try:
        resp = (
            supabase.table("supply_chain_nodes")
            .select("organization_id")
            .is_("deleted_at", "null")
            .execute()
        )
        org_ids = {row["organization_id"] for row in (resp.data or [])}
        for org_id_str in org_ids:
            from uuid import UUID
            try:
                await dark_node_engine.auto_ping_dark_nodes(UUID(org_id_str))
            except Exception as exc:  # noqa: BLE001
                logger.error("Auto-ping error for org %s: %s", org_id_str, exc)
    except Exception as exc:  # noqa: BLE001
        logger.error("run_all_auto_pings failed: %s", exc)


# ---------------------------------------------------------------------------
# Application lifespan (startup / shutdown)
# ---------------------------------------------------------------------------


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    # --- Startup ---
    logger.info("Starting %s", settings.PROJECT_NAME)

    # Register APScheduler jobs
    scheduler.add_job(
        run_all_disruption_scans,
        trigger="interval",
        minutes=15,
        id="disruption_scan",
        replace_existing=True,
    )
    scheduler.add_job(
        run_all_macro_scans,
        trigger="interval",
        minutes=30,
        id="macro_scan",
        replace_existing=True,
    )
    # Module 2.7: Dark node scans every 20 min
    scheduler.add_job(
        run_all_dark_node_scans,
        trigger="interval",
        minutes=20,
        id="dark_node_scan",
        replace_existing=True,
    )
    # Module 2.7: Auto-ping critical dark nodes every 60 min
    scheduler.add_job(
        run_all_auto_pings,
        trigger="interval",
        minutes=60,
        id="auto_ping",
        replace_existing=True,
    )
    scheduler.start()
    logger.info(
        "APScheduler started — disruption 15m, macro 30m, "
        "dark-node scan 20m, auto-ping 60m"
    )

    yield

    # --- Shutdown ---
    scheduler.shutdown(wait=False)
    logger.info("APScheduler stopped")


# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    description=(
        "Curoot Supply Chain Intelligence API — "
        "Modules 2.5 (Disruption), 2.6 (Tradeoffs), "
        "2.7 (Heartbeat & AI-Assisted Remote Control)"
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://curoot.vercel.app"
    ],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:[0-9]+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Router registration
# ---------------------------------------------------------------------------

API_V1_PREFIX = "/api/v1"

app.include_router(ingestion.router, prefix=f"{API_V1_PREFIX}/ingestion", tags=["ingestion"])
app.include_router(telemetry.router, prefix=API_V1_PREFIX)
app.include_router(discovery.router, prefix=API_V1_PREFIX)
app.include_router(invitations.router, prefix=API_V1_PREFIX)
app.include_router(marketplace.router, prefix=API_V1_PREFIX)
app.include_router(mcp_mgr.router, prefix=f"{API_V1_PREFIX}/mcp_mgr", tags=["mcp_mgr"])
app.include_router(disruption.router, prefix=API_V1_PREFIX)   # Module 2.5A
app.include_router(macro_env.router, prefix=API_V1_PREFIX)    # Module 2.5B
app.include_router(tradeoffs.router, prefix=API_V1_PREFIX)    # Module 2.6
app.include_router(heartbeat.router, prefix=API_V1_PREFIX)    # Module 2.7
app.include_router(supplier_chat.router)                      # Module 2.7 (no prefix — /supplier/chat)

# Mount static files for the Supplier PWA
_static_dir = Path(__file__).resolve().parent.parent / "static"
_static_dir.mkdir(exist_ok=True)
app.mount("/static", StaticFiles(directory=str(_static_dir)), name="static")


@app.get("/health", tags=["health"])
async def health_check() -> dict:
    return {"status": "ok", "service": settings.PROJECT_NAME}
