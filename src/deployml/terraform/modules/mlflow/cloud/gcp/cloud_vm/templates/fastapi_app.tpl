from fastapi import FastAPI, HTTPException, Request
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
MLFLOW_EXTERNAL_URL = os.getenv("MLFLOW_EXTERNAL_URL", MLFLOW_BASE_URL)  # External URL for UI links
FASTAPI_PORT = int(os.getenv("FASTAPI_PORT", "8000"))

# Create FastAPI app
app = FastAPI(
    title="MLflow FastAPI Proxy",
    description="FastAPI proxy for MLflow with model serving capabilities",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "fastapi-proxy", "timestamp": datetime.now().isoformat()}

# Root endpoint - redirect to MLflow
@app.get("/")
async def root():
    """Redirect to MLflow UI"""
    return RedirectResponse(url=f"{MLFLOW_EXTERNAL_URL}")

# MLflow proxy endpoint
@app.get("/mlflow")
async def mlflow_proxy():
    """Redirect to MLflow UI"""
    return RedirectResponse(url=f"{MLFLOW_EXTERNAL_URL}")

# Container info endpoint
@app.get("/container-info")
async def container_info():
    """Get container information"""
    return {
        "service": "fastapi-proxy",
        "mlflow_url": MLFLOW_BASE_URL,
        "external_mlflow_url": MLFLOW_EXTERNAL_URL,
        "fastapi_port": FASTAPI_PORT,
        "timestamp": datetime.now().isoformat()
    }

# Model prediction endpoint
@app.post("/predict")
async def predict(request: Request):
    """Model prediction endpoint"""
    try:
        # Get request data
        data = await request.json()
        
        # For now, return a simple response
        # In a real implementation, you would load and run the model
        return {
            "prediction": "sample_prediction",
            "input_data": data,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        logger.error(f"Prediction error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=FASTAPI_PORT)
