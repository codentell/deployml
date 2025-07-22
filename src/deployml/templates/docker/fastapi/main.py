from fastapi import FastAPI, HTTPException, Request, BackgroundTasks
from fastapi.responses import RedirectResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
import os
from contextlib import asynccontextmanager
import logging
import asyncio
import mlflow
import pandas as pd
from datetime import datetime
from typing import Optional

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# MLflow configuration - use container name for inter-container communication
MLFLOW_BASE_URL = os.getenv("MLFLOW_BASE_URL", "http://mlflow:5000")
FASTAPI_PORT = int(os.getenv("FASTAPI_PORT", "8000"))

# Global variables for model
model = None
feature_names = None
model_info = {
    "name": None,
    "version": None,
    "loaded_at": None,
    "last_checked": None,
    "status": "not_loaded",
}

# Configuration for model refresh
MODEL_CHECK_INTERVAL = int(
    os.getenv("MODEL_CHECK_INTERVAL", "300")
)  # 5 minutes default
AUTO_REFRESH_ENABLED = (
    os.getenv("AUTO_REFRESH_ENABLED", "true").lower() == "true"
)


# Pydantic model for prediction request
class PredictionRequest(BaseModel):
    sepal_length: float
    sepal_width: float
    petal_length: float
    petal_width: float


async def load_mlflow_model() -> bool:
    """Load or reload the MLflow model. Returns True if successful."""
    global model, feature_names, model_info

    try:
        logger.info("Loading/refreshing MLflow model...")
        model_name = os.getenv("MODEL_NAME", "best_iris_model")
        mlflow_tracking_uri = os.getenv(
            "MLFLOW_TRACKING_URI", "sqlite:///mlflow.db"
        )
        experiment_name = os.getenv("EXPERIMENT_NAME", "iris_experiment")

        mlflow.set_tracking_uri(mlflow_tracking_uri)
        mlflow.set_experiment(experiment_name)

        # Get model info first
        client = mlflow.tracking.MlflowClient()
        try:
            latest_version = client.get_latest_versions(
                model_name, stages=["None", "Staging", "Production"]
            )
            if latest_version:
                # Get the latest version (highest version number)
                latest_model = max(latest_version, key=lambda x: int(x.version))
                model_version = latest_model.version

                # Check if this is a new version
                if model_info["version"] == model_version and model is not None:
                    logger.info(
                        f"Model version {model_version} already loaded, skipping refresh"
                    )
                    model_info["last_checked"] = datetime.now().isoformat()
                    return True

                logger.info(f"Loading model version: {model_version}")
            else:
                logger.warning("No model versions found, trying latest anyway")
                model_version = "latest"
        except Exception as e:
            logger.warning(
                f"Could not get model version info: {e}, using 'latest'"
            )
            model_version = "latest"

        model_uri = f"models:/{model_name}/latest"
        new_model = mlflow.pyfunc.load_model(model_uri)

        feature_names = [
            "sepal length",
            "sepal width",
            "petal length",
            "petal width",
        ]

        # Update model and info atomically
        model = new_model
        model_info.update(
            {
                "name": model_name,
                "version": model_version,
                "loaded_at": datetime.now().isoformat(),
                "last_checked": datetime.now().isoformat(),
                "status": "loaded",
            }
        )

        logger.info(
            f"✅ Successfully loaded model: {model_name} (version: {model_version})"
        )
        return True

    except Exception as e:
        logger.error(f"❌ Failed to load MLflow model: {e}")
        model_info.update(
            {
                "last_checked": datetime.now().isoformat(),
                "status": "error",
                "error": str(e),
            }
        )
        return False


async def check_for_model_updates():
    """Background task to periodically check for model updates."""
    while True:
        try:
            if AUTO_REFRESH_ENABLED and model_info["status"] == "loaded":
                logger.info("Checking for model updates...")
                await load_mlflow_model()
            await asyncio.sleep(MODEL_CHECK_INTERVAL)
        except Exception as e:
            logger.error(f"Error in background model check: {e}")
            await asyncio.sleep(MODEL_CHECK_INTERVAL)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events"""
    logger.info("FastAPI MLflow Proxy starting...")
    logger.info(f"Proxying requests to MLflow at: {MLFLOW_BASE_URL}")
    logger.info(
        f"Auto-refresh enabled: {AUTO_REFRESH_ENABLED}, Check interval: {MODEL_CHECK_INTERVAL}s"
    )

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

    # Load MLflow model on startup
    await load_mlflow_model()

    # Start background task for model checking
    if AUTO_REFRESH_ENABLED:
        asyncio.create_task(check_for_model_updates())

    yield
    logger.info("FastAPI MLflow Proxy shutting down...")


# Create FastAPI application
app = FastAPI(
    title="MLflow Model API",
    description="Containerized FastAPI server with MLflow model integration for predictions and MLflow proxy",
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
    model_status = "✅ Ready" if model is not None else "❌ Not Loaded"
    model_version = model_info.get("version", "Unknown")
    loaded_at = model_info.get("loaded_at", "Never")
    last_checked = model_info.get("last_checked", "Never")

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>MLflow Model API</title>
        <style>
            body {{ font-family: Arial, sans-serif; margin: 40px; }}
            h1 {{ color: #333; }}
            .links {{ margin: 20px 0; }}
            .link {{ display: block; padding: 10px; margin: 5px 0; background: #f0f0f0; text-decoration: none; border-radius: 5px; }}
            .link:hover {{ background: #e0e0e0; }}
            .container-info {{ background: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            .model-status {{ background: #f0f8e7; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            .refresh-section {{ background: #fff3cd; padding: 15px; border-radius: 5px; margin: 20px 0; }}
            .refresh-button {{ background: #28a745; color: white; padding: 8px 16px; border: none; border-radius: 4px; cursor: pointer; text-decoration: none; display: inline-block; }}
            .refresh-button:hover {{ background: #218838; }}
            .config-info {{ background: #e2e3e5; padding: 15px; border-radius: 5px; margin: 20px 0; font-size: 0.9em; }}
        </style>
        <script>
            async function refreshModel() {{
                const button = document.getElementById('refresh-btn');
                button.disabled = true;
                button.textContent = 'Refreshing...';
                
                try {{
                    const response = await fetch('/refresh-model', {{ method: 'POST' }});
                    const result = await response.json();
                    
                    if (response.ok) {{
                        alert('Model refreshed successfully!');
                        location.reload();
                    }} else {{
                        alert('Failed to refresh model: ' + result.detail);
                    }}
                }} catch (error) {{
                    alert('Error refreshing model: ' + error.message);
                }} finally {{
                    button.disabled = false;
                    button.textContent = '🔄 Refresh Model';
                }}
            }}
        </script>
    </head>
    <body>
        <h1>🚀 MLflow Model API</h1>
        <div class="container-info">
            <h3>🐳 Containerized Deployment</h3>
            <p>This FastAPI server is running in a Docker container with MLflow model integration.</p>
            <p><strong>MLflow URL:</strong> {MLFLOW_BASE_URL}</p>
        </div>
        <div class="model-status">
            <h3>🤖 Model Status</h3>
            <p><strong>Status:</strong> {model_status}</p>
            <p><strong>Model:</strong> {model_info.get('name', 'None')}</p>
            <p><strong>Version:</strong> {model_version}</p>
            <p><strong>Loaded At:</strong> {loaded_at}</p>
            <p><strong>Last Checked:</strong> {last_checked}</p>
        </div>
        <div class="refresh-section">
            <h3>🔄 Model Management</h3>
            <p>Click to manually refresh the model from MLflow:</p>
            <button id="refresh-btn" class="refresh-button" onclick="refreshModel()">🔄 Refresh Model</button>
        </div>
        <div class="config-info">
            <h3>⚙️ Configuration</h3>
            <p><strong>Auto-refresh:</strong> {'Enabled' if AUTO_REFRESH_ENABLED else 'Disabled'}</p>
            <p><strong>Check Interval:</strong> {MODEL_CHECK_INTERVAL} seconds</p>
            <p><strong>MLflow URL:</strong> {MLFLOW_BASE_URL}</p>
            <p><strong>Deployment:</strong> Containerized</p>
        </div>
        <div class="links">
            <a class="link" href="/predict">🔮 Model Prediction (POST)</a>
            <a class="link" href="/model-info">📋 Model Information</a>
            <a class="link" href="/mlflow">📊 MLflow UI</a>
            <a class="link" href="/health">🏥 Health Check</a>
            <a class="link" href="/docs">📚 API Documentation</a>
            <a class="link" href="/container-info">🐳 Container Info</a>
        </div>
    </body>
    </html>
    """
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


@app.post("/predict")
async def predict(data: PredictionRequest):
    """Predict using the loaded MLflow model"""
    if model is None:
        raise HTTPException(
            status_code=503,
            detail="Model not loaded. Please check MLflow configuration and ensure model exists.",
        )

    try:
        # Convert request to DataFrame
        input_data = pd.DataFrame([data.dict()])
        input_data = input_data[
            ["sepal_length", "sepal_width", "petal_length", "petal_width"]
        ]

        # Rename columns to match training data
        input_data.columns = feature_names

        # Make prediction
        predictions = model.predict(input_data)

        return {
            "predictions": predictions.tolist(),
            "model_info": "MLflow loaded model",
            "input_features": data.dict(),
            "deployment": "containerized",
        }

    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(
            status_code=500, detail=f"Prediction failed: {str(e)}"
        )


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


@app.post("/refresh-model")
async def refresh_model():
    """Manually refresh the MLflow model"""
    logger.info("Manual model refresh requested")
    success = await load_mlflow_model()

    if success:
        return {
            "status": "success",
            "message": "Model refreshed successfully",
            "model_info": model_info,
        }
    else:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to refresh model: {model_info.get('error', 'Unknown error')}",
        )


@app.get("/model-info")
async def get_model_info():
    """Get current model information"""
    return {
        "model_loaded": model is not None,
        "model_info": model_info,
        "config": {
            "auto_refresh_enabled": AUTO_REFRESH_ENABLED,
            "check_interval_seconds": MODEL_CHECK_INTERVAL,
            "model_name": os.getenv("MODEL_NAME", "best_iris_model"),
            "mlflow_tracking_uri": os.getenv(
                "MLFLOW_TRACKING_URI", "sqlite:///mlflow.db"
            ),
            "experiment_name": os.getenv("EXPERIMENT_NAME", "iris_experiment"),
        },
        "deployment": "containerized",
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=FASTAPI_PORT)
