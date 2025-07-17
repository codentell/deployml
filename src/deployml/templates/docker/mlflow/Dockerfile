FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --upgrade pip setuptools wheel

# Install MLflow and dependencies
RUN pip install \
    mlflow[extras] \
    sqlalchemy \
    psycopg2-binary \
    google-cloud-storage \
    boto3

# Create mlflow user
RUN useradd -m -s /bin/bash mlflow

# Create directories
RUN mkdir -p /app/mlflow-data /app/mlflow-config
RUN chown -R mlflow:mlflow /app

# Switch to mlflow user
USER mlflow

# Expose MLflow port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Default command
CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000"] 