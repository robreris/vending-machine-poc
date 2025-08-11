FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy the backend app
COPY greeting_backend_app.py .

# Expose the FastAPI port
EXPOSE 5000

# Run the FastAPI backend with Uvicorn
CMD ["uvicorn", "greeting_backend_app:app", "--host", "0.0.0.0", "--port", "5000"]
