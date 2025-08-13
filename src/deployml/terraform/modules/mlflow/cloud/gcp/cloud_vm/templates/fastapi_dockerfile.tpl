FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --upgrade pip setuptools wheel

# Install FastAPI and dependencies
RUN pip install \
    fastapi \
    uvicorn \
    httpx \
    mlflow \
    pandas \
    joblib \
    scikit-learn \
    numpy \
    google-cloud-storage \
    google-cloud-core

# Create fastapi user
RUN useradd -m -s /bin/bash fastapi

# Create app directory
RUN mkdir -p /app/fastapi-app
RUN chown -R fastapi:fastapi /app

# Copy FastAPI application
COPY main.py /app/fastapi-app/main.py

# Switch to fastapi user
USER fastapi

# Expose FastAPI port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Default command
CMD ["uvicorn", "fastapi-app.main:app", "--host", "0.0.0.0", "--port", "8000"]
