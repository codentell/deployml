version: '3.8'

services:
  mlflow:
    build: 
      context: ./mlflow
      dockerfile: Dockerfile
    container_name: mlflow-server
    ports:
      - "${mlflow_port}:5000"
    environment:
      - MLFLOW_BACKEND_STORE_URI=${backend_store_uri}
      - MLFLOW_DEFAULT_ARTIFACT_ROOT=${artifact_bucket != "" ? "gs://${artifact_bucket}" : "./mlflow-artifacts"}
      - MLFLOW_SERVER_HOST=0.0.0.0
      - MLFLOW_SERVER_PORT=5000
    volumes:
      - mlflow-data:/app/mlflow-data
      - mlflow-config:/app/mlflow-config
    networks:
      - mlflow-network
    restart: unless-stopped
    command: >
      mlflow server 
      --host 0.0.0.0 
      --port 5000
      --backend-store-uri ${backend_store_uri}
      --default-artifact-root ${artifact_bucket != "" ? "gs://${artifact_bucket}" : "./mlflow-artifacts"}
    
  fastapi:
    build:
      context: ./fastapi
      dockerfile: Dockerfile
    container_name: fastapi-proxy
    ports:
      - "${fastapi_port}:8000"
    environment:
      - MLFLOW_BASE_URL=http://mlflow:5000
      - MLFLOW_EXTERNAL_URL=$${EXTERNAL_MLFLOW_URL}
      - FASTAPI_PORT=8000
    depends_on:
      - mlflow
    networks:
      - mlflow-network
    restart: unless-stopped

  feast:
    build:
      context: ./feast
      dockerfile: Dockerfile
    container_name: feast-server
    ports:
      - "${feast_port}:${feast_port}"
    environment:
      - FEAST_PORT=${feast_port}
      - REGISTRY_TYPE=${registry_type}
      - ONLINE_STORE_TYPE=${online_store_type}
      - OFFLINE_STORE_TYPE=${offline_store_type}
      - BIGQUERY_DATASET=${bigquery_dataset}
${use_postgres ? "      - POSTGRES_HOST=${postgres_host}" : ""}
${use_postgres ? "      - POSTGRES_PORT=${postgres_port}" : ""}
${use_postgres ? "      - POSTGRES_DATABASE=${postgres_database}" : ""}
${use_postgres ? "      - POSTGRES_USER=${postgres_user}" : ""}
${use_postgres ? "      - POSTGRES_PASSWORD=${postgres_password}" : ""}
    volumes:
      - ./feast:/app
    networks:
      - mlflow-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${feast_port}/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  mlflow-data:
  mlflow-config:

networks:
  mlflow-network:
    driver: bridge
