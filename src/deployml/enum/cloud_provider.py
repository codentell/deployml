
from enum import Enum

class CloudProvider(Enum):
    AWS = 'aws'
    GCP = 'gcp'
    AZURE = 'azure'
    LOCAL = 'local'