from fastapi import FastAPI, Request, APIRouter, Form
from fastapi.responses import RedirectResponse, JSONResponse
from fastapi.responses import Response
from starlette.middleware.sessions import SessionMiddleware
from onelogin.saml2.auth import OneLogin_Saml2_Auth
from onelogin.saml2.settings import OneLogin_Saml2_Settings
from pathlib import Path
import os


saml_router = APIRouter()

BASE_DIR = Path(__file__).resolve().parent
SAML_FOLDER = BASE_DIR / "saml"

def prepare_saml_request(request: Request):
    url_data = {
        "https": "on" if request.url.scheme == "https" else "off",
        #"http_host": request.client.host,
        "http_host": "ec2-52-43-126-239.us-west-2.compute.amazonaws.com",
        "server_port": str(request.url.port or (443 if request.url.scheme == "https" else 80)),
        "script_name": request.url.path,
        "get_data": request.query_params,
        "post_data": {},
    }
    return OneLogin_Saml2_Auth(url_data, custom_base_path=str(SAML_FOLDER))

@saml_router.get("/login")
async def saml_login(request: Request):
    auth = prepare_saml_request(request)
    return RedirectResponse(auth.login(return_to="https://ec2-52-43-126-239.us-west-2.compute.amazonaws.com:8000/saml/acs"))

@saml_router.post("/saml/acs")
async def saml_acs(request: Request):
    form = await request.form()
    url_data = {
        "https": "on" if request.url.scheme == "https" else "off",
        "http_host": "ec2-52-43-126-239.us-west-2.compute.amazonaws.com",
        "server_port": str(request.url.port or 443),
        "script_name": request.url.path,
        "get_data": {},
        "post_data": form,
    }
    auth = OneLogin_Saml2_Auth(url_data, custom_base_path=str(SAML_FOLDER))
    auth.process_response()
    errors = auth.get_errors()
    if errors:
        return JSONResponse(status_code=400, content={"errors": errors})

    if not auth.is_authenticated():
        return JSONResponse(status_code=401, content={"error": "Not authenticated"})
    
    attributes = auth.get_attributes()
    
    user = {
        "nameid": auth.get_nameid(),
        "session_index": auth.get_session_index(),
        "attributes": attributes,
        "name": attributes.get("http://schemas.microsoft.com/identity/claims/displayname", [""])[0] if attributes else "",
        "email": attributes.get("email", [""])[0] if attributes else "",
    }
    request.session["user"] = user
    return RedirectResponse("https://ec2-52-43-126-239.us-west-2.compute.amazonaws.com:5173")

@saml_router.get("/logout")
async def saml_logout(request: Request):
    auth = prepare_saml_request(request)
    name_id = request.session.get("user", {}).get("nameid")
    session_index = request.session.get("user", {}).get("session_index")
    saml_logout_url = auth.logout(
        name_id=name_id,
        session_index=session_index,
        return_to="https://ec2-52-43-126-239.us-west-2.compute.amazonaws.com:5173"
    )
    response = RedirectResponse(saml_logout_url)
    request.session.clear()
    response.delete_cookie("session")
    return response
