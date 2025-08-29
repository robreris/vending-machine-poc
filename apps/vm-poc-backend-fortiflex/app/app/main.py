from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import products
from app.routes.saml import saml_router as saml_router
from starlette.middleware.sessions import SessionMiddleware
from app.routes.fortiflex import router as fortiflex_router
from app.routes.debug import router as debug_router
from app.routes.whoami import router as whoami_router
from app.routes.azuremagic import router as azure_router
import os


SESSION_SECRET = os.getenv("SESSION_SECRET", "fallback-insecure-dev-key")

app = FastAPI()

# Add this here — with the actual secret key
#app.add_middleware(SessionMiddleware, secret_key="your-very-secret-key")
app.add_middleware(SessionMiddleware, secret_key=SESSION_SECRET)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://fortiflex.fortinetcloudcse.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(products.router)
app.include_router(saml_router)
app.include_router(fortiflex_router)
app.include_router(debug_router)
app.include_router(whoami_router)
app.include_router(azure_router)
