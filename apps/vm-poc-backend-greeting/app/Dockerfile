FROM python:3.11-slim@sha256:d1e9ca7c4e78d1e8ecadb5d44bfc8e956e7a65b659a9950f569f243d72b326d0

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy the backend app
COPY greeting_backend_app.py .

RUN useradd --create-home --uid 1000 --shell /usr/sbin/nologin appuser \
    && chown -R appuser:appuser /app
USER appuser

# Expose the FastAPI port
EXPOSE 5000

# Run the FastAPI backend with Uvicorn
CMD ["uvicorn", "greeting_backend_app:app", "--host", "0.0.0.0", "--port", "5000"]
