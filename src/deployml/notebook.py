"""
DeployML Notebook Interface

A modular notebook interface for MLOps stack deployment and management.
This module provides backward compatibility while delegating to the new modular structure.
"""

# Import everything from the new modular structure
from .notebook.deployment import deploy, load
from .notebook.stack import DeploymentStack
from .notebook.urls import ServiceURLs

# Maintain backward compatibility by re-exporting at module level
__all__ = [
    'deploy',
    'load', 
    'DeploymentStack',
    'ServiceURLs'
]