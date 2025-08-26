# app/routes/debug.py
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
import os

router = APIRouter()

DEBUG_MODE = os.getenv("DEBUG", "false").lower() == "true"

if DEBUG_MODE:
    @router.get(
        "/api/session-debug",
        summary="Dump Session Data",
        description="Returns the full contents of the current user session for debugging purposes. Enabled only when DEBUG mode is active."
    )
    async def session_debug(request: Request):
        # Dump the entire session dictionary
        session_data = dict(request.session)
        return JSONResponse(content={"session": session_data})