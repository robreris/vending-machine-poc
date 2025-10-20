FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app app

ENV PORT=5000
ENV SERVICE_NAME=vm-poc-backend-echo

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "5000"]
