#!/usr/bin/env python3
"""
FEAST Connection Test Script
This script helps test connectivity to the FEAST server and demonstrates basic usage.
"""

import requests
import json
import sys
from typing import Optional


def test_feast_health(host: str, port: int = 6566) -> bool:
    """Test FEAST health endpoint."""
    try:
        url = f"http://{host}:{port}/health"
        print(f"🔍 Testing FEAST health endpoint: {url}")

        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            print("✅ FEAST health check passed!")
            print(f"Response: {response.text}")
            return True
        else:
            print(
                f"❌ FEAST health check failed with status code: {response.status_code}"
            )
            print(f"Response: {response.text}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ Failed to connect to FEAST health endpoint: {e}")
        return False


def test_feast_base_url(host: str, port: int = 6566) -> bool:
    """Test FEAST base URL."""
    try:
        url = f"http://{host}:{port}/"
        print(f"🔍 Testing FEAST base URL: {url}")

        response = requests.get(url, timeout=10)
        print(f"Status Code: {response.status_code}")
        print(f"Response Headers: {dict(response.headers)}")
        print(f"Response Body: {response.text[:500]}...")
        return True
    except requests.exceptions.RequestException as e:
        print(f"❌ Failed to connect to FEAST base URL: {e}")
        return False


def get_vm_external_ip() -> Optional[str]:
    """Get the VM's external IP address."""
    try:
        # Try to get IP from metadata server (if running on the VM)
        response = requests.get(
            "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip",
            headers={"Metadata-Flavor": "Google"},
            timeout=5,
        )
        if response.status_code == 200:
            return response.text.strip()
    except:
        pass

    # If not on VM or metadata not available, ask user
    return None


def main():
    print("🍽️ FEAST Connection Test Script")
    print("=" * 50)

    # Get the VM's external IP
    vm_ip = get_vm_external_ip()

    if vm_ip:
        print(f"📍 Detected VM external IP: {vm_ip}")
        host = vm_ip
    else:
        print("📍 Please enter the VM's external IP address:")
        host = input("VM IP: ").strip()

    if not host:
        print("❌ No IP address provided. Exiting.")
        sys.exit(1)

    print(f"\n🚀 Testing FEAST server at {host}:6566")
    print("-" * 50)

    # Test health endpoint
    health_ok = test_feast_health(host, 6566)

    print("\n" + "-" * 50)

    # Test base URL
    base_ok = test_feast_base_url(host, 6566)

    print("\n" + "=" * 50)
    print("📊 Test Results Summary:")
    print(f"Health Endpoint: {'✅ PASS' if health_ok else '❌ FAIL'}")
    print(f"Base URL: {'✅ PASS' if base_ok else '❌ FAIL'}")

    if health_ok and base_ok:
        print("\n🎉 FEAST server is accessible and working!")
        print("\n📚 Next Steps:")
        print("1. Use FEAST Python SDK to connect:")
        print(f"   from feast import FeatureStore")
        print(f"   store = FeatureStore(repo_path='path/to/feature/repo')")
        print("2. Or use gRPC clients to connect to:")
        print(f"   {host}:6566")
        print("3. Check FEAST documentation for API usage examples")
    else:
        print("\n⚠️ FEAST server has connectivity issues.")
        print("Troubleshooting steps:")
        print("1. Check if the VM is running: gcloud compute instances list")
        print("2. Check firewall rules: gcloud compute firewall-rules list")
        print("3. SSH into VM and check container status: docker ps")
        print("4. Check FEAST logs: docker logs feast-server")


if __name__ == "__main__":
    main()
