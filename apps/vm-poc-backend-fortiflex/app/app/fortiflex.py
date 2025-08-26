# backend/app/fortiflex.py
import os, requests
from requests.auth import HTTPBasicAuth

FLEX_BASE = os.getenv("FORTIFLEX_BASE_URL")  # e.g. https://fortiflex.example/api
FLEX_USER = os.getenv("FORTIFLEX_USERNAME")
FLEX_PASS = os.getenv("FORTIFLEX_PASSWORD")
FLEX_ORG  = os.getenv("FORTIFLEX_ORG_ID")

def flex_session():
    s = requests.Session()
    s.auth = HTTPBasicAuth(FLEX_USER, FLEX_PASS)
    s.headers.update({"Accept":"application/json","Content-Type":"application/json"})
    return s

def check_points(sku: str, qty: int = 1):
    s = flex_session()
    # Map to your collection’s endpoint (adjust path names to match your API)
    r = s.get(f"{FLEX_BASE}/orgs/{FLEX_ORG}/points/available")
    r.raise_for_status()
    return r.json()

def entitle(sku: str, cloud: str, version: str, qty: int = 1):
    s = flex_session()
    payload = {
        "sku": sku, "cloud": cloud, "version": version, "quantity": qty
        # add contract, term, asset group, etc. per your collection
    }
    r = s.post(f"{FLEX_BASE}/orgs/{FLEX_ORG}/entitlements", json=payload, timeout=60)
    r.raise_for_status()
    return r.json()