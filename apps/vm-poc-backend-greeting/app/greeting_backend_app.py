import random
from fastapi import FastAPI, Query
from pydantic import BaseModel
from typing import Optional
import uvicorn

app = FastAPI(
    title="Greeting Backend",
    description="Backend service that returns personalized greeting messages with a random ID.",
    version="1.0.0",
)

# Response model for the JSON response
class GreetingResponse(BaseModel):
    message: str

@app.get(
    "/greet",
    summary="Return a personalized greeting",
    response_model=GreetingResponse,
    response_description="A JSON object containing the greeting message."
)
async def greet(
    name: Optional[str] = Query(
        "Stranger",
        title="Name",
        description="The name of the person to greet.",
        min_length=1,
        max_length=50,
        example="Alice"
    )
):
    random_num = random.randint(10000, 99999)
    message = f"Hello there! You'll be known here as {name}{random_num}. Welcome!"
    return GreetingResponse(message=message)

if __name__ == "__main__":
    uvicorn.run("greeting_backend_app:app", host="0.0.0.0", port=5000, reload=True)
