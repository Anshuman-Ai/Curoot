from fastapi import Header, HTTPException, status
from uuid import UUID

async def get_current_org_id(x_org_id: str = Header(default="00000000-0000-0000-0000-000000000000")) -> UUID:
    """
    Extracts the current organization ID from the request headers.
    In a fully productionized setup, this should extract the org_id from a validated JWT.
    """
    try:
        return UUID(x_org_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid Organization ID format in header"
        )
