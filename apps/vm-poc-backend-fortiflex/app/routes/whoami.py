from fastapi import APIRouter
from fastapi import Request

router = APIRouter()

@router.get(
    "/api/whoami",
    summary="Return user session data",
    description="Returns the authenticated user's session information, including SAML user attributes and any stored FortiFlex config type mappings."
)
async def whoami(request: Request):
    """
    Retrieves session information for the current user.

    Returns:
        JSON object containing:
        - `user`: User's SAML attributes and identifiers.
        - `fortiflex_config_types`: A list of config type mappings stored in session.
    """
    user = request.session.get("user")
    fortiflex_config_types = request.session.get("fortiflex_config_types", [])
    return {"user": user, "fortiflex_config_types": fortiflex_config_types}