from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import httpx
#import os
from datetime import datetime, timedelta
import logging

logging.basicConfig(
    level=logging.INFO,  # Use DEBUG to see all logs
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)

logger = logging.getLogger(__name__)


FORTICLOUD_AUTH_BASE = "https://customerapiauth.fortinet.com/api/v1"
FORTIFLEX_API_BASE = "https://support.fortinet.com/ES/api/fortiflex/v2"

router = APIRouter()

class FortiFlexCredentials(BaseModel):
    username: str
    apiKey: str
    serialNumber: str
    accountId: str

async def get_valid_access_token(request: Request):
    username = request.session.get("fortiflex_username")
    api_key = request.session.get("fortiflex_api_key")

    if not username or not api_key:
        logger.error("FortiFlex credentials not found in session")
        return {"error": "FortiFlex credentials not found in session"}, 401
    

    access_token = request.session.get("fortiflex_access_token")
    token_expiry_str = request.session.get("fortiflex_token_expiry")

    if access_token and token_expiry_str:
        token_expiry = datetime.fromisoformat(token_expiry_str)
        if datetime.utcnow() < token_expiry:
            # Token is still valid
            logger.info("Using existing FortiFlex access token")
            return {"access_token": access_token}

    # Token missing or expired, fetch a new one
    logger.info("Fetching new FortiFlex access token")
    return await get_new_fortiflex_token(username, api_key, request)

async def get_new_fortiflex_token(username, api_key, request):

    if not username or not api_key:
        logger.error("Missing API credentials for FortiFlex")
        return {"error": "Missing API credentials"}, 401

    token_url = f"{FORTICLOUD_AUTH_BASE}/oauth/token/"
    data = {
        "grant_type": "password",
        "client_id": "flexvm",
        "username": username,
        "password": api_key
    }

    async with httpx.AsyncClient() as client:
        token_resp = await client.post(token_url, data=data)
        if token_resp.status_code != 200:
            logger.error(f"Failed to retrieve token: {token_resp.text}")
            return {"error": "Failed to retrieve token", "details": token_resp.text}, 401

        token_data = token_resp.json()
        access_token = token_data.get("access_token")
        expires_in = token_data.get("expires_in", 3600)

        request.session["fortiflex_access_token"] = access_token
        request.session["fortiflex_token_expiry"] = (datetime.utcnow() + timedelta(seconds=expires_in)).isoformat()

        logger.info("New FortiFlex access token retrieved successfully")
        return {"access_token": access_token}
# Helper proxy function
async def proxy_fortiflex_call(request: Request, method: str, path: str, body: dict = None):
    if body is None:
        try:
            body = await request.json()
            if not isinstance(body, dict):
                raise ValueError("Parsed JSON body is not a dictionary")
        except Exception as e:
            logger.error(f"Error parsing JSON body: {e}")
            return {"error": "Invalid or missing JSON in request body", "details": str(e)}, 400
    token_response = await get_valid_access_token(request)
    if "error" in token_response:
        return token_response
    access_token = token_response["access_token"]

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    url = f"{FORTIFLEX_API_BASE}{path}"

    logger.debug(f"Proxying FortiFlex call: {method} {url} with headers {headers} and body {body}")
    
    async with httpx.AsyncClient() as client:
        response = await client.request(method, url, headers=headers, json=body)
        if response.status_code != 200:
            logger.error(f"FortiFlex {path} failed: {response.text}")
            return {"error": f"FortiFlex {path} failed", "details": response.text}, 400
        logger.info(f"FortiFlex {path} succeeded")
        return response.json()
    
@router.post(
    "/api/fortiflex/credentials",
    summary="Store FortiFlex API credentials in session",
    description="Stores the provided FortiFlex API credentials in the user's session for subsequent authenticated requests.",
    tags=["Credentials"]
)
async def store_fortiflex_credentials(data: FortiFlexCredentials, request: Request):
    request.session["fortiflex_username"] = data.username
    request.session["fortiflex_api_key"] = data.apiKey
    request.session["fortiflex_serial_number"] = data.serialNumber
    request.session["forticloud_account_number"] = data.accountId
    
    
    return {"message": "Credentials stored successfully"}

# Programs
@router.post(
    "/api/fortiflex/programs/list",
    summary="List FortiFlex programs",
    description="Retrieves a list of available FortiFlex programs.",
    tags=["Programs"]
)
async def post_fortiflex_programs_list(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/programs/list")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

@router.post(
    "/api/fortiflex/programs/points",
    summary="Retrieve points for FortiFlex programs",
    description="Fetches points information related to FortiFlex programs.",
    tags=["Programs"]
)
async def post_fortiflex_programs_points(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/programs/points")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

#Configurations
@router.post(
    "/api/fortiflex/configs/list",
    summary="List FortiFlex configurations",
    description="Fetches a list of FortiFlex configurations associated with the user's FortiFlex Program Serial Number.",
    tags=["Configs"]
)
async def post_fortiflex_configs_list(request: Request):
    serial_number = request.session.get("fortiflex_serial_number")
    if not serial_number:
        logger.error("FortiFlex serial number not found in session")
        return {"error": "FortiFlex serial number not found in session"}, 401
    body = { "programSerialNumber": serial_number }
    result = await proxy_fortiflex_call(request, "POST", "/configs/list", body)

    # Check if result is a tuple (error, status_code)
    if isinstance(result, tuple):
        return result

    configs = result.get("configs", [])
    config_map = [
        {"id": cfg.get("id"), "type": cfg.get("productType", {}).get("name")}
        for cfg in configs if cfg.get("id") and cfg.get("productType")
    ]
    request.session["fortiflex_config_types"] = config_map

    return result
@router.post(
    "/api/fortiflex/configs/create",
    summary="Create a new FortiFlex configuration",
    description="Creates a new FortiFlex configuration with provided details.",
    tags=["Configs"]
)
async def post_fortiflex_configs_create(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/configs/create")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

@router.post(
    "/api/fortiflex/configs/update",
    summary="Update an existing FortiFlex configuration",
    description="Updates an existing FortiFlex configuration with new information.",
    tags=["Configs"]
)
async def post_fortiflex_configs_update(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/configs/update")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

@router.put(
    "/api/fortiflex/configs/disable",
    summary="Disable a FortiFlex configuration",
    description="Disables a specified FortiFlex configuration.",
    tags=["Configs"]
)
async def put_fortiflex_configs_disable(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/configs/disable")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

@router.put(
    "/api/fortiflex/configs/enable",
    summary="Enable a FortiFlex configuration",
    description="Enables a specified FortiFlex configuration.",
    tags=["Configs"]
)
async def put_fortiflex_configs_enable(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/configs/enable")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

# Entitlements
@router.post(
    "/api/fortiflex/entitlements/list-all",
    summary="List all FortiFlex entitlements",
    description="Retrieves a comprehensive list of all FortiFlex entitlements.",
    tags=["Entitlements"]
)
async def post_fortiflex_entitlements_list_all(request: Request):
    serial_number = request.session.get("fortiflex_serial_number")
    account_id = request.session.get("forticloud_account_number")

    if not serial_number or not account_id:
        logger.error("Missing required session values for FortiFlex entitlements")
        return {"error": "Missing required session values"}, 401

    body = {
        "programSerialNumber": serial_number,
        "accountId": account_id
    }

    return await proxy_fortiflex_call(request, "POST", "/entitlements/list", body)

@router.post(
    "/api/fortiflex/entitlements/vm/create",
    summary="Create a FortiFlex VM entitlement",
    description="Creates a new virtual machine entitlement within FortiFlex.",
    tags=["Entitlements"]
)
async def post_fortiflex_entitlements_vm_create(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/entitlements/vm/create")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

@router.post(
    "/api/fortiflex/entitlements/hardware/create",
    summary="Create a FortiFlex hardware entitlement",
    description="Creates a new hardware entitlement within FortiFlex.",
    tags=["Entitlements"]
)
async def post_fortiflex_entitlements_hardware_create(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/entitlements/hardware/create")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

@router.post(
    "/api/fortiflex/entitlements/cloud/create",
    summary="Create a FortiFlex cloud entitlement",
    description="Creates a new cloud entitlement within FortiFlex.",
    tags=["Entitlements"]
)
async def post_fortiflex_entitlements_cloud_create(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/entitlements/cloud/create")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

@router.post(
    "/api/fortiflex/entitlements/update",
    summary="Update a FortiFlex entitlement",
    description="Updates details of an existing FortiFlex entitlement.",
    tags=["Entitlements"]
)
async def post_fortiflex_entitlements_update(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/entitlements/update")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

@router.put(
    "/api/fortiflex/entitlements/stop",
    summary="Stop a FortiFlex entitlement",
    description="Stops or disables a specified FortiFlex entitlement.",
    tags=["Entitlements"]
)
async def put_fortiflex_entitlements_stop(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/entitlements/stop")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

@router.put(
    "/api/fortiflex/entitlements/reactivate",
    summary="Reactivate a FortiFlex entitlement",
    description="Reactivates a previously stopped FortiFlex entitlement.",
    tags=["Entitlements"]
)
async def put_fortiflex_entitlements_reactivate(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/entitlements/reactivate")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

@router.post(
    "/api/fortiflex/entitlements/vm/token",
    summary="Get token for FortiFlex VM entitlement",
    description="Retrieves an access token for a FortiFlex virtual machine entitlement.",
    tags=["Entitlements"]
)
async def post_fortiflex_entitlements_vm_token(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/entitlements/vm/token")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

@router.post(
    "/api/fortiflex/entitlements/points",
    summary="Retrieve points for FortiFlex entitlements",
    description="Fetches points information related to FortiFlex entitlements.",
    tags=["Entitlements"]
)
async def post_fortiflex_entitlements_points(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/entitlements/points")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

@router.post(
    "/api/fortiflex/entitlements/transfer",
    summary="Transfer FortiFlex entitlements",
    description="Transfers FortiFlex entitlements between accounts or users.",
    tags=["Entitlements"]
)
async def post_fortiflex_entitlements_transfer(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/entitlements/transfer")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

# Groups
@router.post(
    "/api/fortiflex/groups/list",
    summary="List FortiFlex groups",
    description="Retrieves a list of FortiFlex groups.",
    tags=["Groups"]
)
async def post_fortiflex_groups_list(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/groups/list")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

@router.post(
    "/api/fortiflex/groups/nexttoken",
    summary="Get next token for FortiFlex groups pagination",
    description="Retrieves the next pagination token for FortiFlex groups listing.",
    tags=["Groups"]
)
async def post_fortiflex_groups_nexttoken(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/groups/nexttoken")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

# Tools
@router.post(
    "/api/fortiflex/tools/calc",
    summary="Calculate FortiFlex licenses",
    description="Calculates license requirements or usage for FortiFlex.",
    tags=["Tools"]
)
async def post_fortiflex_tools_licenses(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/tools/licenses")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result

@router.post(
    "/api/fortiflex/tools/check-token",
    summary="Check validity of FortiFlex token",
    description="Checks whether a provided FortiFlex token is valid and active.",
    tags=["Tools"]
)
async def post_fortiflex_tools_check_token(request: Request):
    result = await proxy_fortiflex_call(request, "POST", "/tools/check-token")
    if isinstance(result, tuple):
        return JSONResponse(content=result[0], status_code=result[1])
    return result