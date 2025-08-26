import httpx
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse


router = APIRouter()

@router.post(
    "/api/azuremagic",
    summary="Call Azure Magic WebHook",
    description="Calls Azure Webhook to launch terraform for deployment of FGT into workshop env with Flex Token."
)
async def azuremagic(request: Request):
    """
    Calls Azuremagic with information for the current user.

    Returns: JobID Response from Azure Automation Webhook
    """
    session = request.session
    data = await request.json()
    payload = {
        "user": session.get("user.name"),
        "flexentitlementtoken": data.get("flexentitlementtoken")
    }

    webhook_url = "https://f1dcf3d2-d4e7-45f4-ac93-5394986d1fb4.webhook.eus.azure-automation.net/webhooks?token=rxkK0Qcjo5xDG4xBGkKhF1ixbqIdLaHTI3oop1XJ2BY%3d"

    async with httpx.AsyncClient() as client:
        response = await client.post(webhook_url, json=payload)

    return JSONResponse(content=response.json(), status_code=response.status_code)