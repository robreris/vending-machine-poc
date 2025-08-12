from fastapi import FastAPI, Query
from pydantic import BaseModel

app = FastAPI(
    title="Math Backend",
    description="Simple service that adds two numbers.",
    version="1.0.0",
)

class SumResponse(BaseModel):
    a: float
    b: float
    result: float

@app.get("/sum", response_model=SumResponse, summary="Add two numbers")
def sum_numbers(
    a: float = Query(..., description="First number", example=1.5),
    b: float = Query(..., description="Second number", example=2.75),
):
    return {"a": a, "b": b, "result": a + b}

# (nice to have for probes)
@app.get("/healthz")
def healthz():
    return {"status": "ok"}
