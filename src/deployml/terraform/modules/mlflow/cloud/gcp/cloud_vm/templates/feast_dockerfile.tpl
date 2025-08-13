FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl
${use_postgres ? "RUN apt-get install -y postgresql-client" : ""}
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir \
    feast[postgres] \
    google-cloud-bigquery \
    google-cloud-storage
${use_postgres ? "RUN pip install --no-cache-dir psycopg2-binary" : ""}

# Copy Feast configuration
COPY feast_env.tpl /app/feast_env.tpl
COPY feast_config.py /app/feast_config.py

# Create Feast configuration
RUN python /app/feast_config.py

# Expose port
EXPOSE ${feast_port}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:${feast_port}/health || exit 1

# Start Feast server
CMD ["feast", "serve", "--host", "0.0.0.0", "--port", "${feast_port}"]
