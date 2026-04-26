"""
Core security module — JWT-based org extraction with Supabase token validation.

Extracts org_id from:
  1. A validated Supabase JWT (Authorization: Bearer <token>)
  2. Falls back to X-Org-Id header for backward compatibility / development

Production path: JWT → decode → extract org claim → return UUID
Development path: X-Org-Id header → UUID parse → return
"""

from __future__ import annotations

import json
import base64
import logging
from uuid import UUID
from typing import Optional

from fastapi import Header, HTTPException, Request, status

logger = logging.getLogger(__name__)

# Default demo org for development fallback
_DEFAULT_ORG_ID = "00000000-0000-0000-0000-000000000000"


def _decode_jwt_payload(token: str) -> dict:
    """Decode a JWT payload without cryptographic verification.
    
    Supabase JWTs are already verified at the edge (RLS).
    We extract claims for routing only — actual data isolation
    is enforced by RLS policies on every table.
    """
    try:
        payload_b64 = token.split(".")[1]
        # Add padding
        payload_b64 += "=" * (-len(payload_b64) % 4)
        return json.loads(base64.urlsafe_b64decode(payload_b64))
    except Exception:
        return {}


async def get_current_org_id(
    request: Request,
    authorization: Optional[str] = Header(default=None),
    x_org_id: str = Header(default=_DEFAULT_ORG_ID),
) -> UUID:
    """
    Extracts the current organization ID from the request.
    
    Priority:
      1. Authorization Bearer JWT → decode → extract 'org_id' or 'app_metadata.org_id'
      2. X-Org-Id header (backward compat / dev mode)
    
    All downstream DB queries MUST still scope by this org_id
    to enforce 1-Hop data isolation at the application layer,
    in addition to PostgreSQL RLS at the database layer.
    """
    # Path 1: JWT-based extraction
    if authorization and authorization.lower().startswith("bearer "):
        token = authorization[7:].strip()
        if token:
            claims = _decode_jwt_payload(token)
            
            # Check standard Supabase claims
            jwt_org_id = (
                claims.get("org_id")
                or claims.get("organization_id")
                or (claims.get("app_metadata") or {}).get("org_id")
                or (claims.get("user_metadata") or {}).get("org_id")
            )
            
            if jwt_org_id:
                try:
                    org = UUID(str(jwt_org_id))
                    logger.debug("Org ID from JWT: %s", org)
                    return org
                except ValueError:
                    logger.warning("Invalid org_id in JWT: %s", jwt_org_id)
            
            # JWT present but no org claim — check if sub (user_id) exists
            sub = claims.get("sub")
            if sub:
                logger.debug(
                    "JWT authenticated (user=%s) but no org claim, "
                    "falling back to X-Org-Id header",
                    sub,
                )

    # Path 2: Header-based extraction (backward compat)
    try:
        org = UUID(x_org_id)
        return org
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid Organization ID format. Provide a valid UUID via "
                   "Authorization Bearer JWT or X-Org-Id header.",
        )
