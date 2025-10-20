import os
from fastapi import FastAPI, Request


app = FastAPI(title="VM POC Echo Service")


@app.get("/healthz")
def health_check() -> dict:
    """Lightweight readiness probe used by compose and Kubernetes."""
    return {"status": "ok"}


@app.post("/echo")
async def echo_payload(request: Request) -> dict:
    """Return the request JSON body along with contextual metadata."""
    payload = await request.json()
    return {
        "service": os.getenv("SERVICE_NAME", "vm-poc-backend-echo"),
        "received": payload,
    }


@app.get("/")
def root() -> dict:
    return {"message": "Send a POST /echo with JSON payload to see it mirrored back."}
