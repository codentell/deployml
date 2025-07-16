# Containerized MLflow Deployment

This directory contains the Docker configuration for deploying MLflow and FastAPI in containers.

## Architecture

```
┌─────────────────┐  ┌─────────────────┐
│ MLflow Container│  │FastAPI Container│
│     :5000       │  │     :8000       │
└─────────────────┘  └─────────────────┘
         │                    │
         └────────────────────┘
          Docker Network (mlflow-network)
```

## Components

### MLflow Container (`mlflow/`)
- **Base Image**: `python:3.9-slim`
- **Port**: 5000
- **Features**:
  - MLflow server with tracking and model registry
  - PostgreSQL and GCS support
  - Health checks
  - Data persistence via volumes

### FastAPI Container (`fastapi/`)
- **Base Image**: `python:3.9-slim`
- **Port**: 8000
- **Features**:
  - FastAPI proxy for MLflow
  - Container-to-container communication
  - Health checks and monitoring
  - Auto-retry for MLflow readiness

## Directory Structure

```
src/deployml/templates/docker/
├── README.md                    # This file
├── docker-compose.yml           # Container orchestration
├── mlflow/
│   └── Dockerfile              # MLflow container
└── fastapi/
    ├── Dockerfile              # FastAPI container
    └── main.py                 # FastAPI application
```

## Environment Variables

### MLflow Container
- `MLFLOW_BACKEND_STORE_URI` - Database connection string
- `MLFLOW_DEFAULT_ARTIFACT_ROOT` - Artifact storage location
- `MLFLOW_SERVER_HOST` - Server host (default: 0.0.0.0)
- `MLFLOW_SERVER_PORT` - Server port (default: 5000)

### FastAPI Container
- `MLFLOW_BASE_URL` - MLflow server URL (default: http://mlflow:5000)
- `FASTAPI_PORT` - FastAPI server port (default: 8000)

## Volumes

- `mlflow-data` - MLflow data persistence
- `mlflow-config` - MLflow configuration files

## Networking

- **Network**: `mlflow-network` (bridge)
- **Inter-container communication**: FastAPI → MLflow via container name
- **External access**: Both containers expose ports to host

## Deployment Process

During VM deployment, the system will:

1. **Copy Docker files** to the VM
2. **Build containers** using Docker Compose
3. **Start services** with proper networking
4. **Configure systemd** to manage Docker Compose
5. **Set up monitoring** with health checks

## Available Endpoints

After deployment:

- **MLflow UI**: `http://VM_IP:5000`
- **FastAPI Proxy**: `http://VM_IP:8000`
- **Health Check**: `http://VM_IP:8000/health`
- **Container Info**: `http://VM_IP:8000/container-info`
- **API Docs**: `http://VM_IP:8000/docs`

## Container Management

### View running containers
```bash
docker ps
```

### View logs
```bash
docker logs mlflow-server
docker logs fastapi-proxy
```

### Restart services
```bash
docker-compose restart
```

### Stop services
```bash
docker-compose down
```

### Rebuild containers
```bash
docker-compose build --no-cache
docker-compose up -d
```

## Development

To test locally:

```bash
# Build and start containers
docker-compose up -d

# View logs
docker-compose logs -f

# Stop containers
docker-compose down
```

## Production Considerations

- **Resource Limits**: Add memory/CPU limits to containers
- **Security**: Use non-root users (already implemented)
- **Monitoring**: Health checks are configured
- **Backup**: Volume data should be backed up regularly
- **Updates**: Use specific image tags instead of latest

## Troubleshooting

### Container not starting
```bash
# Check container status
docker ps -a

# View container logs
docker logs container_name

# Check Docker daemon
systemctl status docker
```

### Network issues
```bash
# Check network
docker network ls
docker network inspect mlflow-network

# Test connectivity
docker exec fastapi-proxy ping mlflow
```

### Volume issues
```bash
# Check volumes
docker volume ls
docker volume inspect mlflow-data

# Check permissions
docker exec mlflow-server ls -la /app/
``` 