import os
import requests
from typing import Optional
from fastapi import FastAPI, Request, Form, Query
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
import uvicorn

app = FastAPI(
    title="Microservice Documentation Hub",
    description="Frontend that aggregates API documentation for multiple microservices.",
    version="1.0.0",
)

# -------------------------------
# Backend URLs
# -------------------------------
GREETING_BACKEND_URL = os.environ.get("GREETING_BACKEND_URL", "http://greeting-backend:5000/greet")
MATH_BACKEND_URL = os.environ.get("MATH_BACKEND_URL", "http://math-backend:5000/sum")
ANALYTICS_BACKEND_URL = os.environ.get("ANALYTICS_BACKEND_URL", "http://analytics-backend:5000/events")

# -------------------------------
# Template setup for frontend UI
# -------------------------------
templates = Jinja2Templates(directory="templates")

# -------------------------------
# Frontend HTML endpoints
# -------------------------------
@app.get("/", response_class=HTMLResponse)
async def get_index(request: Request):
    return templates.TemplateResponse("index.html", {"request": request, "message": None})

@app.post("/", response_class=HTMLResponse)
async def post_index(request: Request, name: str = Form(...)):
    response = requests.get(GREETING_BACKEND_URL, params={"name": name})
    message = response.json().get("message")
    return templates.TemplateResponse("index.html", {"request": request, "message": message})

# -------------------------------
# Shared Response Models
# -------------------------------
class GreetingResponse(BaseModel):
    message: str

# -------------------------------
# Microservice: Greeting Backend
# -------------------------------
@app.get(
    "/greet",
    tags=["Greeting Backend"],
    summary="Greet a user",
    description="Proxies the request to the Greeting Backend `/greet` endpoint and returns its response.",
    response_model=GreetingResponse,
    response_description="A JSON object containing the greeting message from the Greeting Backend."
)
async def greet_proxy(
    name: str = Query(..., title="Name", description="Name of the user to greet", example="Alice")
):
    response = requests.get(GREETING_BACKEND_URL, params={"name": name})
    return response.json()

# -------------------------------
# Microservice: Math Backend
# -------------------------------
@app.get(
    "/sum",
    tags=["Math Backend"],
    summary="Add two numbers",
    description="Proxies the request to the Math Backend `/sum` endpoint and returns its response.",
    response_model=SumResponse,
    response_description="A JSON object containing 'a', 'b', and 'result'."
)
async def sum_proxy(
    a: float = Query(..., title="a", description="First number", example=1.5),
    b: float = Query(..., title="b", description="Second number", example=2.75),
):
    response = requests.get(MATH_BACKEND_URL, params={"a": a, "b": b})
    response.raise_for_status()
    return response.json()

# -------------------------------
# Example: Future Analytics Service
# -------------------------------
class EventResponse(BaseModel):
    status: str
    details: Optional[str] = None

@app.get(
    "/events",
    tags=["Analytics Backend"],
    summary="List recent events",
    description="Retrieves recent events from the Analytics Backend.",
    response_model=EventResponse,
    response_description="A JSON object containing event info from the Analytics Backend."
)
async def list_events():
    # Example proxy; could be a real backend call
    # response = requests.get(ANALYTICS_BACKEND_URL)
    # return response.json()
    return {"status": "success", "details": "Example event log"}

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=5000, reload=True)
