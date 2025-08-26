FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

ENV DEBUG=true

RUN ls saml/certs/key.pem && ls saml/certs/cert.pem

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--ssl-keyfile", "saml/certs/key.pem", "--ssl-certfile", "saml/certs/cert.pem"]
