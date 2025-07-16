from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import RedirectResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
import httpx
import os
from contextlib import asynccontextmanager
import logging
import asyncio

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# MLflow configuration - use container name for inter-container communication
MLFLOW_BASE_URL = os.getenv("MLFLOW_BASE_URL", "http://mlflow:5000")
FASTAPI_PORT = int(os.getenv("FASTAPI_PORT", "8000"))


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events"""
    logger.info("FastAPI MLflow Proxy starting...")
    logger.info(f"Proxying requests to MLflow at: {MLFLOW_BASE_URL}")

    # Wait for MLflow to be ready
    logger.info("Waiting for MLflow to be ready...")
    max_retries = 30
    for i in range(max_retries):
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{MLFLOW_BASE_URL}/health", timeout=5.0
                )
                if response.status_code == 200:
                    logger.info("✅ MLflow is ready!")
                    break
        except Exception as e:
            logger.info(f"Waiting for MLflow... (attempt {i+1}/{max_retries})")
            if i == max_retries - 1:
                logger.error(
                    f"❌ MLflow not ready after {max_retries} attempts: {e}"
                )
            await asyncio.sleep(2)

    yield
    logger.info("FastAPI MLflow Proxy shutting down...")


# Create FastAPI application
app = FastAPI(
    title="MLflow Proxy API",
    description="Containerized FastAPI proxy for MLflow server",
    version="1.0.0",
    lifespan=lifespan,
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/", response_class=HTMLResponse)
async def root():
    """Root endpoint with links to available services"""
    html_content = (
        """
    <!DOCTYPE html>
    <html>
    <head>
        <title>MLflow Proxy API</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            h1 { color: #333; }
            .links { margin: 20px 0; }
            .link { display: block; padding: 10px; margin: 5px 0; background: #f0f0f0; text-decoration: none; border-radius: 5px; }
            .link:hover { background: #e0e0e0; }
            .container-info { background: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0; }
        </style>
    </head>
    <body>
        <h1>🚀 MLflow Proxy API</h1>
        <div class="container-info">
            <h3>🐳 Containerized Deployment</h3>
            <p>This FastAPI proxy is running in a Docker container and communicating with MLflow via Docker networking.</p>
            <p><strong>MLflow URL:</strong> """
        + MLFLOW_BASE_URL
        + """</p>
        </div>
        <div class="links">
            <a class="link" href="/mlflow">📊 MLflow UI</a>
            <a class="link" href="/health">🏥 Health Check</a>
            <a class="link" href="/docs">📚 API Documentation</a>
            <a class="link" href="/container-info">🐳 Container Info</a>
        </div>
    </body>
    </html>
    """
    )
    return HTMLResponse(content=html_content)


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{MLFLOW_BASE_URL}/health", timeout=5.0
            )
            if response.status_code == 200:
                return {
                    "status": "healthy",
                    "mlflow": "connected",
                    "mlflow_url": MLFLOW_BASE_URL,
                    "proxy_port": FASTAPI_PORT,
                    "deployment": "containerized",
                }
            else:
                return {
                    "status": "unhealthy",
                    "mlflow": "disconnected",
                    "mlflow_status_code": response.status_code,
                    "deployment": "containerized",
                }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {
            "status": "unhealthy",
            "error": str(e),
            "mlflow_url": MLFLOW_BASE_URL,
            "deployment": "containerized",
        }


@app.get("/container-info")
async def container_info():
    """Container information endpoint"""
    return {
        "container_name": "fastapi-proxy",
        "mlflow_container": "mlflow-server",
        "mlflow_url": MLFLOW_BASE_URL,
        "network": "mlflow-network",
        "ports": {"fastapi": FASTAPI_PORT, "mlflow": 5000},
    }


@app.get("/mlflow")
async def mlflow_ui_redirect():
    """Redirect to MLflow UI"""
    return RedirectResponse(url=f"{MLFLOW_BASE_URL}/")


@app.get("/mlflow/{path:path}")
async def proxy_mlflow_ui(path: str, request: Request):
    """Proxy MLflow UI requests"""
    try:
        # Get query parameters
        query_params = str(request.url.query)
        url = f"{MLFLOW_BASE_URL}/{path}"
        if query_params:
            url += f"?{query_params}"

        async with httpx.AsyncClient() as client:
            response = await client.get(url, headers=dict(request.headers))
            return response.content
    except Exception as e:
        logger.error(f"MLflow UI proxy error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.api_route(
    "/api/2.0/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"]
)
async def proxy_mlflow_api(path: str, request: Request):
    """Proxy MLflow API requests"""
    try:
        # Get query parameters
        query_params = str(request.url.query)
        url = f"{MLFLOW_BASE_URL}/api/2.0/{path}"
        if query_params:
            url += f"?{query_params}"

        async with httpx.AsyncClient() as client:
            response = await client.request(
                method=request.method,
                url=url,
                headers=dict(request.headers),
                content=await request.body(),
            )
            return response.content
    except Exception as e:
        logger.error(f"MLflow API proxy error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=FASTAPI_PORT)
