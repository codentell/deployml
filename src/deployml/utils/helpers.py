import shutil
import subprocess
from pathlib import Path
from typing import Optional
from google.cloud import storage
import random
import string
from deployml.utils.constants import ANIMAL_NAMES, FALLBACK_WORDS, TERRAFORM_DIR
import subprocess
import time
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TimeElapsedColumn

def check_command(name: str) -> bool:
    """
    Check if a command is available in the system PATH.

    Args:
        name (str): The name of the command to check.

    Returns:
        bool: True if the command is found, False otherwise.
    """
    return shutil.which(name) is not None


def check(command: str) -> bool:
    """
    Alias for check_command for backward compatibility.
    """
    return check_command(command)


def check_gcp_auth() -> bool:
    """
    Check if the user is authenticated with GCP CLI.

    Returns:
        bool: True if authenticated, False otherwise.
    """
    try:
        result = subprocess.run(
            ["gcloud", "auth", "list"], capture_output=True, text=True
        )
        return "ACTIVE" in result.stdout
    except Exception:
        return False


def copy_modules_to_workspace(modules_dir: Path) -> None:
    """
    Copy Terraform module templates to the workspace directory.

    Args:
        modules_dir (Path): The destination directory for module templates.
    """
    MODULE_TEMPLATES_DIR = TERRAFORM_DIR / "modules"
    if not MODULE_TEMPLATES_DIR.exists():
        raise FileNotFoundError(f"Module templates not found at: {MODULE_TEMPLATES_DIR}")
    for module_path in MODULE_TEMPLATES_DIR.iterdir():
        if module_path.is_dir():
            dest_path = modules_dir / module_path.name
            if dest_path.exists():
                shutil.rmtree(dest_path)
            shutil.copytree(module_path, dest_path)


def bucket_exists(bucket_name: str, project_id: str) -> bool:
    """
    Check if a Google Cloud Storage bucket exists in the given project.

    Args:
        bucket_name (str): The name of the bucket to check.
        project_id (str): The GCP project ID.

    Returns:
        bool: True if the bucket exists, False otherwise.
    """
    client = storage.Client(project=project_id)
    try:
        client.get_bucket(bucket_name)
        return True
    except Exception:
        return False


def generate_unique_bucket_name(base_name: str, project_id: str) -> str:
    """
    Generate a unique GCS bucket name by appending a random suffix.

    Args:
        base_name (str): The base name for the bucket.
        project_id (str): The GCP project ID.

    Returns:
        str: A unique bucket name.
    """
    while True:
        suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=6))
        new_name = f"{base_name}-{suffix}"
        if not bucket_exists(new_name, project_id):
            return new_name


def generate_bucket_name(project_id: str) -> str:
    """
    Generate a random, human-readable GCS bucket name for the given project.

    Args:
        project_id (str): The GCP project ID.

    Returns:
        str: A generated bucket name.
    """
    if random.random() < 0.7:
        word = random.choice(ANIMAL_NAMES)
    else:
        word = random.choice(FALLBACK_WORDS)
    suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=4))
    return f"{word}-bucket-{project_id}-{suffix}".replace('_', '-')


def estimate_terraform_time(plan_output: str, operation: str = "apply") -> str:
    """
    Estimate time for Terraform operations based on resource count and types.
    If PostgreSQL/Cloud SQL is present, estimate 20 minutes per instance.
    """
    import re
    # Match google_sql_database_instance resources even inside modules
    postgres_resource_pattern = r'#.*google_sql_database_instance\.[^ ]+ will be created'
    postgres_resources = set(re.findall(postgres_resource_pattern, plan_output))
    postgres_count = len(postgres_resources)
    if postgres_count > 0:
        total_minutes = 20 * postgres_count
        return f"~{total_minutes} minutes (Cloud SQL/PostgreSQL detected)"
    # Otherwise, estimate by resource count
    resource_patterns = [
        r"# (\w+\.\w+) will be created",
        r"# (\w+\.\w+) will be destroyed", 
        r"# (\w+\.\w+) will be updated",
        r"# (\w+\.\w+) will be replaced"
    ]
    resource_count = 0
    for pattern in resource_patterns:
        resource_count += len(re.findall(pattern, plan_output))
    if resource_count == 0:
        return "~1 minute"
    elif resource_count <= 3:
        avg_time = 0.5
    elif resource_count <= 8:
        avg_time = 2
    else:
        avg_time = 5
    estimated_minutes = max(1, int(resource_count * avg_time))
    return f"~{estimated_minutes} minutes"


def cleanup_cloud_sql_resources(terraform_dir: Path, project_id: str):
    """
    Clean up Cloud SQL database and user before destroying the instance.
    """
    import subprocess
    try:
        # Get the instance name from terraform state
        result = subprocess.run(
            ["terraform", "output", "-raw", "instance_connection_name"], 
            cwd=terraform_dir, 
            capture_output=True, 
            text=True
        )
        if result.returncode == 0:
            instance_name = result.stdout.strip()
            # Extract instance name from connection name (format: project:region:instance)
            instance_parts = instance_name.split(':')
            if len(instance_parts) == 3:
                instance_name = instance_parts[2]
                
                print("🗄️  Cleaning up Cloud SQL database and user...")
                
                # Drop the database first
                drop_db_cmd = [
                    "gcloud", "sql", "databases", "delete", "mlflow",
                    "--instance", instance_name,
                    "--project", project_id,
                    "--quiet"
                ]
                subprocess.run(drop_db_cmd, capture_output=True, text=True)
                
                # Drop the user
                drop_user_cmd = [
                    "gcloud", "sql", "users", "delete", "mlflow",
                    "--instance", instance_name,
                    "--project", project_id,
                    "--quiet"
                ]
                subprocess.run(drop_user_cmd, capture_output=True, text=True)
                
                print("✅ Cloud SQL cleanup completed")
    except Exception as e:
        print(f"⚠️  Cloud SQL cleanup failed (continuing with destroy): {e}")


def cleanup_terraform_files(terraform_dir: Path):
    """
    Clean up Terraform state and lock files from the specified directory.
    """
    import shutil
    cleanup_files = [
        ".terraform",
        "terraform.tfstate", 
        "terraform.tfstate.backup",
        ".terraform.lock.hcl"
    ]
    
    for file in cleanup_files:
        file_path = terraform_dir / file
        if file_path.exists():
            if file_path.is_dir():
                shutil.rmtree(file_path)
            else:
                file_path.unlink()
            print(f"🗑️  Removed: {file}")
    
    print("✅ Cleanup completed")


def run_terraform_with_loading_bar(cmd, cwd, estimated_minutes, stack=None):
    """
    Run a subprocess command with a loading bar using rich.progress.
    Progress messages are based on the stack/resources from the YAML config if provided.
    Args:
        cmd (list): Command to run as a list.
        cwd (Path): Working directory.
        estimated_minutes (int): Estimated time in minutes for the operation.
        stack (list, optional): List of stages from the YAML config to generate contextual messages.
    Returns:
        int: The return code of the process.
    """
    # Default messages if stack is not provided
    default_msgs = [
        "DeployML: Preparing your cloud environment...",
        "DeployML: Creating resources, please hold on...",
        "DeployML: Almost there! Just a few more steps...",
        "DeployML: Wrapping up the deployment for you...",
        "DeployML: All done! Reviewing the results..."
    ]

    # If stack is provided, build contextual messages
    if stack:
        resource_msgs = ["DeployML: Preparing your cloud environment..."]
        for stage in stack:
            for stage_name, tool in stage.items():
                tool_name = tool.get("name", stage_name)
                msg = f"DeployML: Deploying {tool_name.replace('_', ' ').title()} ({stage_name.replace('_', ' ').title()})..."
                resource_msgs.append(msg)
        resource_msgs.append("DeployML: Wrapping up the deployment for you...")
        resource_msgs.append("DeployML: All done! Reviewing the results...")
    else:
        resource_msgs = default_msgs

    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
        TimeElapsedColumn()
    ) as progress:
        task = progress.add_task(resource_msgs[0], total=100)
        process = subprocess.Popen(cmd, cwd=cwd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        start_time = time.time()
        estimated_seconds = estimated_minutes * 60
        n_msgs = len(resource_msgs)
        while process.poll() is None:
            elapsed = time.time() - start_time
            progress_percent = min(95, int((elapsed / estimated_seconds) * 100))
            # Choose message based on progress
            msg_idx = min(int(progress_percent / (100 / (n_msgs - 1))), n_msgs - 2)
            message = resource_msgs[msg_idx]
            progress.update(task, completed=progress_percent, description=message)
            time.sleep(1)
        progress.update(task, completed=100, description=resource_msgs[-1])
        return process.returncode 