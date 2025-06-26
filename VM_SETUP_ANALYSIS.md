# VM Setup Analysis & Fixes

## Issues Identified and Fixed

### 1. **Critical Issue: Wrong OS Image**
**Problem:** Using Container-Optimized OS (COS) which is designed for containers, not package installation
**Fix:** Changed to `debian-cloud/debian-12` (Debian 12 Bookworm)
- COS doesn't have `apt-get` or standard package management
- Debian 12 is stable and well-supported for Python applications

### 2. **Missing Dependencies**
**Problem:** Incomplete package installation
**Fix:** Added comprehensive package list:
```bash
sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common \
  python3 \
  python3-pip \
  python3-venv \
  python3-dev \
  build-essential \
  git \
  wget \
  unzip
```

### 3. **Python Environment Issues**
**Problem:** Missing essential Python tools
**Fix:** Added proper pip upgrade and tools:
```bash
pip install --upgrade pip setuptools wheel
pip install mlflow[extras] sqlalchemy psycopg2-binary
```

### 4. **Permission Issues**
**Problem:** Files owned by root, causing service failures
**Fix:** Added proper ownership:
```bash
sudo chown -R debian:debian /home/debian/mlflow-env
sudo chown -R debian:debian /home/debian/mlflow-config
sudo chown -R debian:debian /home/debian/mlflow-data
```

### 5. **Service Configuration Issues**
**Problem:** Missing proper logging and error handling
**Fix:** Enhanced systemd service:
```ini
StandardOutput=journal
StandardError=journal
```

### 6. **Startup Script Robustness**
**Problem:** No error handling or logging
**Fix:** Added comprehensive logging and retry logic:
```bash
# Log all output
exec > >(tee /var/log/mlflow-startup.log) 2>&1

# Retry logic for service startup
for i in {1..5}; do
  if curl -s http://localhost:5000 > /dev/null; then
    echo "✅ MLflow server is running successfully!"
    break
  else
    echo "Attempt $i: MLflow server not responding yet..."
    sleep 10
  fi
done
```

## Key Improvements Made

### 1. **OS Selection**
- ✅ Debian 12 (stable, well-supported)
- ✅ Full package management support
- ✅ Python 3.11+ included
- ✅ Standard systemd support

### 2. **Dependencies**
- ✅ All required system packages
- ✅ Python development tools
- ✅ Build essentials for compiled packages
- ✅ Git for potential future use

### 3. **Python Environment**
- ✅ Virtual environment isolation
- ✅ Latest pip, setuptools, wheel
- ✅ MLflow with all extras
- ✅ Database drivers (SQLAlchemy, psycopg2)

### 4. **Service Management**
- ✅ Proper systemd service configuration
- ✅ Automatic restart on failure
- ✅ Comprehensive logging
- ✅ Proper user permissions

### 5. **Error Handling**
- ✅ Startup script logging
- ✅ Service status verification
- ✅ Retry logic for service startup
- ✅ Detailed error reporting

### 6. **File Structure**
```
/home/debian/
├── mlflow-env/          # Python virtual environment
├── mlflow-config/       # Configuration files
└── mlflow-data/         # Data storage
```

## Startup Sequence

1. **System Setup** (2-3 minutes)
   - Update packages
   - Install dependencies
   - Verify Python/pip

2. **Docker Setup** (1-2 minutes)
   - Install Docker
   - Configure permissions
   - Test installation

3. **MLflow Setup** (3-5 minutes)
   - Create virtual environment
   - Install MLflow and dependencies
   - Verify installation

4. **Service Setup** (1-2 minutes)
   - Create systemd service
   - Set permissions
   - Start service

5. **Verification** (1-2 minutes)
   - Test service status
   - Verify web interface
   - Log completion

**Total Expected Time:** 8-14 minutes

## Monitoring and Debugging

### Log Files
- `/var/log/mlflow-startup.log` - Complete startup script output
- `/var/log/mlflow-startup-complete.log` - Completion marker
- `sudo journalctl -u mlflow -f` - MLflow service logs

### Verification Commands
```bash
# Check service status
sudo systemctl status mlflow

# Check if port is listening
sudo netstat -tulnp | grep 5000

# Test local access
curl http://localhost:5000

# Check MLflow version
/home/debian/mlflow-env/bin/mlflow --version
```

## Expected Outcome

After these fixes, the VM should:
1. ✅ Start up automatically with all dependencies
2. ✅ Install and configure MLflow properly
3. ✅ Start MLflow service automatically
4. ✅ Be accessible via web interface
5. ✅ Have proper logging and error handling
6. ✅ Restart automatically on failures

The startup script is now robust and should handle edge cases while providing clear feedback on progress and any issues. 