# FastAPI MLflow Proxy Template

This directory contains a sample FastAPI application that acts as a proxy for your MLflow deployment.

## Quick Start

### Option 1: Use Default Template (Recommended for beginners)
```bash
# No additional setup needed - uses built-in template
deployml deploy --config-path your-config.yaml
```

### Option 2: Use Custom FastAPI App from GCS
```bash
# 1. Upload your main.py to GCS
gsutil cp main.py gs://your-bucket/fastapi/main.py

# 2. Set the fastapi_app_source in your config YAML
# See gcp-cloud-vm-sample.yaml for example configuration

# 3. Deploy
deployml deploy --config-path your-config.yaml
```

### Option 3: Use Local FastAPI App (Development)
```bash
# 1. Set the fastapi_app_source in your config YAML
# See gcp-cloud-vm-sample.yaml for example configuration

# 2. Deploy
deployml deploy --config-path your-config.yaml
```

## FastAPI App Sources

The `fastapi_app_source` variable supports three formats:

| Value | Description | Example |
|-------|-------------|---------|
| `"template"` | Use built-in template (default) | `"template"` |
| `"gs://..."` | Download from Google Cloud Storage | `"gs://mybucket/app/main.py"` |
| `"/path/..."` | Copy from local file system | `"/home/user/my-app/main.py"` |

## Sample Application Features

The provided `main.py` template includes:

- **Health check endpoint**: `/health` - Check if MLflow is accessible
- **MLflow UI proxy**: `/mlflow/*` - Proxy requests to MLflow UI
- **MLflow API proxy**: `/api/2.0/*` - Proxy requests to MLflow API
- **Landing page**: `/` - HTML page with links to all services
- **CORS middleware**: Enabled for cross-origin requests
- **Logging**: Configured for debugging and monitoring

## Creating Your Custom FastAPI App

1. **Copy the template**: Start with the template from this directory
2. **Customize endpoints**: Add your own routes and logic
3. **Test locally**: Use the development setup below
4. **Deploy**: Use one of the deployment methods above

### Example Custom Endpoint

```python
@app.get("/custom/models")
async def get_models():
    """Get list of MLflow models"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{MLFLOW_BASE_URL}/api/2.0/mlflow/registered-models/list")
            return response.json()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

## Configuration

### Environment Variables

The application uses these environment variables (automatically set during deployment):

- `MLFLOW_BASE_URL`: URL of the MLflow server (default: `http://localhost:5000`)
- `FASTAPI_PORT`: Port for the FastAPI server (default: `8000`)

### YAML Configuration

Set these in your deployment config YAML:

```yaml
# In your deployment config (e.g., gcp-cloud-vm-sample.yaml)
stack:
  - experiment_tracking:
      name: mlflow
      params:
        fastapi_app_source: "gs://your-bucket/fastapi/main.py"
        fastapi_port: 8000
```

## Available Endpoints

After deployment, your FastAPI proxy will be available at:

- `http://VM_IP:8000/` - Landing page
- `http://VM_IP:8000/health` - Health check
- `http://VM_IP:8000/mlflow` - MLflow UI
- `http://VM_IP:8000/docs` - FastAPI auto-generated documentation

## Local Development

To test your FastAPI application locally:

```bash
# Install dependencies
pip install fastapi uvicorn httpx

# Set environment variables
export MLFLOW_BASE_URL=http://localhost:5000
export FASTAPI_PORT=8000

# Run MLflow server locally (in another terminal)
mlflow server --host 0.0.0.0 --port 5000

# Run your FastAPI application
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## Deployment Examples

### Using GCS for Team Sharing

```bash
# 1. Create your custom FastAPI app
cp src/deployml/templates/fastapi/main.py my-fastapi-app.py

# 2. Customize the app
# Add your custom endpoints...

# 3. Upload to GCS
gsutil cp my-fastapi-app.py gs://my-team-bucket/fastapi/main.py

# 4. Update your deployment config YAML
# Add fastapi_app_source: "gs://my-team-bucket/fastapi/main.py" to your MLflow params

# 5. Deploy
deployml deploy --config-path config.yaml
```

### Using Local File for Development

```bash
# 1. Create your custom FastAPI app
cp src/deployml/templates/fastapi/main.py ./my-fastapi-app.py

# 2. Customize the app
# Add your custom endpoints...

# 3. Update your deployment config YAML
# Add fastapi_app_source: "/absolute/path/to/my-fastapi-app.py" to your MLflow params

# 4. Deploy
deployml deploy --config-path config.yaml
```

## Requirements

The FastAPI application requires these Python packages (automatically installed during deployment):

- `fastapi`
- `uvicorn`
- `httpx`

## Troubleshooting

### FastAPI Service Issues

```bash
# Check FastAPI service status
sudo systemctl status fastapi

# View FastAPI logs
sudo journalctl -u fastapi -f

# Restart FastAPI service
sudo systemctl restart fastapi
```

### Common Issues

1. **FastAPI app not found**: Check that your `fastapi_app_source` path is correct
2. **GCS download fails**: Ensure the VM has proper GCS permissions
3. **MLflow connection fails**: Verify MLflow is running on the expected port
4. **Permission errors**: Check file permissions after copying

## Security Considerations

- The template allows all origins (`allow_origins=["*"]`) for CORS
- For production, restrict CORS to your specific domains
- Consider adding authentication for custom endpoints
- Use HTTPS in production environments

## Next Steps

1. Start with the default template to ensure everything works
2. Copy the template and add your custom endpoints
3. Test locally before deploying
4. Use GCS for team sharing and version control
5. Monitor logs and add proper error handling 