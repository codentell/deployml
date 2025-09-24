# DeployML

[![Tests](https://github.com/codentell/deployml/actions/workflows/test.yml/badge.svg)](https://github.com/codentell/deployml/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/codentell/deployml/branch/main/graph/badge.svg)](https://codecov.io/gh/codentell/deployml)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![PyPI version](https://badge.fury.io/py/deployml-core.svg)](https://badge.fury.io/py/deployml-core)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Infrastructure for academia with cost analysis** - A comprehensive MLOps deployment tool that simplifies cloud infrastructure management for academic research and machine learning projects.

## Statement of Need

DeployML addresses the critical need for accessible, cost-effective MLOps infrastructure in academic environments. Researchers and students often struggle with:

- **Complex cloud infrastructure setup** that requires deep DevOps knowledge
- **Unpredictable costs** that can exceed academic budgets
- **Lack of integrated tools** for experiment tracking, model registry, and deployment
- **Security concerns** around cloud resource management

DeployML provides a one-click solution for deploying production-ready MLOps stacks with built-in cost analysis, making advanced machine learning infrastructure accessible to academic users regardless of their cloud expertise.

**Target Audience**: Academic researchers, data science students, university IT departments, and research institutions working with machine learning and requiring scalable, cost-effective infrastructure.

## Features

- 🏗️ **Infrastructure as Code**: Deploy ML infrastructure using Terraform
- 💰 **Cost Analysis**: Integrated infracost analysis before deployment  
- ☁️ **Multi-Cloud Support**: GCP, AWS, and more
- 🔬 **ML-Focused**: Pre-configured for MLflow, experiment tracking, and model registry
- 🛡️ **Production Ready**: Security best practices and service account management
- 📊 **Academic-Friendly**: Budget controls and cost monitoring
- 🐍 **Python Integration**: Notebook-friendly API for researchers

## Installation

### For Users

Install from PyPI:
```bash
pip install deployml-core
```

### For Development

Clone the repository and install with development dependencies:
```bash
git clone https://github.com/codentell/deployml.git
cd deployml
poetry install --with dev,test
```

### System Requirements

- Python 3.11 or higher
- [Terraform](https://www.terraform.io/) (for infrastructure deployment)
- [Google Cloud SDK](https://cloud.google.com/sdk) (for GCP deployments)
- [Poetry](https://python-poetry.org/) (for development)

## Quick Start

### 1. System Check
```bash
deployml doctor
```

### 2. Initialize Configuration
```bash
deployml init
```

### 3. Deploy Infrastructure
```bash
deployml deploy --config-path deployml.yaml
```

### 4. Using in Notebooks
```python
import deployml

# Deploy a stack
stack = deployml.deploy("deployml.yaml")

# Access service URLs
print(f"MLflow UI: {stack.urls.mlflow}")
print(f"Jupyter: {stack.urls.jupyter}")

# Show all services
stack.show_services()
```

## Configuration

Create a `deployml.yaml` configuration file:

```yaml
name: "my-research-stack"
provider:
  name: "gcp"
  project_id: "my-research-project"
  region: "us-central1"

services:
  jupyter:
    enabled: true
    machine_type: "n1-standard-2"
  mlflow:
    enabled: true
    service_account: "mlflow@my-project.iam.gserviceaccount.com"
  minio:
    enabled: true

cost_analysis:
  enabled: true
  warning_threshold: 100.0
  currency: "USD"
```

## Cost Analysis Integration

DeployML integrates with [infracost](https://www.infracost.io/) to provide cost estimates before deployment:

### Setup
```bash
# Install infracost
brew install infracost

# Login and configure
infracost auth login
```

### Configuration
```yaml
cost_analysis:
  enabled: true              # Enable/disable cost analysis (default: true)
  warning_threshold: 100.0   # Warn if monthly cost exceeds this amount
  currency: "USD"            # Currency for cost display
```

## Testing

Run the complete test suite:
```bash
# Install test dependencies
poetry install --with test

# Run all tests
poetry run pytest

# Run with coverage
poetry run pytest --cov=deployml

# Run specific test types
poetry run pytest -m unit
poetry run pytest -m integration
```

### Test Requirements
- All tests use mocking for external services (GCP, subprocess calls)
- Tests are designed to run in CI/CD environments
- No actual cloud resources are created during testing

## Documentation

- [API Documentation](https://deployml.readthedocs.io/) (Coming Soon)
- [User Guide](docs/user-guide.md)
- [Examples](examples/)
- [Contributing Guidelines](CONTRIBUTING.md)

## Comparison to Other Tools

| Tool | Target | Focus | Cost Analysis | Academic-Friendly |
|------|--------|-------|---------------|-------------------|
| DeployML | Academic/Research | ML Infrastructure | ✅ Built-in | ✅ Budget controls |
| Kubeflow | Enterprise | Kubernetes ML | ❌ Manual | ❌ Complex setup |
| SageMaker | Enterprise/AWS | Managed ML | ❌ Post-facto | ❌ Expensive |
| MLflow | General | Experiment tracking | ❌ None | ⚠️ Setup required |

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup
1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/deployml.git`
3. Install dependencies: `poetry install --with dev,test`
4. Install pre-commit: `pre-commit install`
5. Run tests: `poetry run pytest`

## Citation

If you use DeployML in your research, please cite:

```bibtex
@software{deployml2024,
  title={DeployML: Infrastructure for Academic Machine Learning},
  author={Hoang, Drew and Bayona, Jarvin and Nitta, Grant and Clements, Robert},
  year={2024},
  url={https://github.com/codentell/deployml},
  version={0.0.1}
}
```

## License

DeployML is licensed under the [MIT License](LICENSE).

## Authors

- **Drew Hoang** - *Lead Developer* - [codentell@gmail.com](mailto:codentell@gmail.com)
- **Jarvin Bayona** - *Core Developer* - [jarvin.bayona@gmail.com](mailto:jarvin.bayona@gmail.com)  
- **Grant Nitta** - *Core Developer* - [gtnitta@gmail.com](mailto:gtnitta@gmail.com)
- **Robert Clements** - *Academic Advisor* - [rclements@usfca.edu](mailto:rclements@usfca.edu)

## Support

- 📖 [Documentation](https://deployml.readthedocs.io/) (Coming Soon)
- 💬 [GitHub Discussions](https://github.com/codentell/deployml/discussions)
- 🐛 [Bug Reports](https://github.com/codentell/deployml/issues)
- 📧 Email: [codentell@gmail.com](mailto:codentell@gmail.com)