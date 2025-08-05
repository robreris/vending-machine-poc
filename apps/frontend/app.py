from typing import Optional
from fastapi import FastAPI, Request, Form, Query
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import requests, os, uvicorn

app = FastAPI(
    title="Greeting App",
    description="A simple FastAPI app that serves an HTML form and a JSON greeting API.",
    version="1.0.0",
)

backend_url = os.environ.get("BACKEND_URL", "http://backend:5000/greet")

templates = Jinja2Templates(directory="templates")
#app.mount("/static", StaticFiles(directory="static"), name="static")

# --------------------------
# Response model definition
# --------------------------
class GreetingResponse(BaseModel):
    message: str

@app.get("/", response_class=HTMLResponse)
async def get_index(request: Request):
    return templates.TemplateResponse("index.html", {"request": request, "message": None})

@app.post("/", response_class=HTMLResponse)
async def post_index(request: Request, name: str = Form(...)):
    response = requests.get(backend_url, params={"name": name})
    message = response.json().get("message")
    return templates.TemplateResponse("index.html", {"request": request, "message": message})

# -----------------------------------------
# Enhanced JSON API endpoint with Pydantic
# -----------------------------------------
@app.get(
    "/greet",
    summary="Get a greeting message",
    description="Returns a personalized greeting message as JSON.",
    response_model=GreetingResponse,
    response_description="A JSON object containing the greeting message."
)
async def greet(
    name: str = Query(
        ...,
        title="Name",
        description="The name of the person you want to greet.",
        min_length=1,
        max_length=50,
        example="Alice"
    ),
    excited: Optional[bool] = Query(
        False,
        title="Excited",
        description="If true, returns a more enthusiastic greeting.",
        example=True
    )
):
    """Return a greeting message as JSON with a defined schema."""
    message = f"Hello, {name}!"
    if excited:
        message += " 🎉"
    return GreetingResponse(message=message)

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=5000, reload=True)
