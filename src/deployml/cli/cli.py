import sys
import yaml
import typer
import shutil
import subprocess
from deployml.utils.banner import display_banner
from deployml.utils.menu import prompt, show_menu
from deployml.utils.constants import TEMPLATE_DIR, TERRAFORM_DIR, TOOL_VARIABLES, ANIMAL_NAMES, FALLBACK_WORDS
from deployml.enum.cloud_provider import CloudProvider
from jinja2 import Environment, FileSystemLoader
from pathlib import Path
from typing import Optional
import random
import string
from google.cloud import storage



cli = typer.Typer()


def check_command(name: str) -> bool:
    return shutil.which(name) is not None


def check(command: str) -> bool:
    return shutil.which(command) is not None


def check_gcp_auth() -> bool:
    try:
        result = subprocess.run(
            ["gcloud", "auth", "list"], capture_output=True, text=True
        )
        return "ACTIVE" in result.stdout
    except Exception:
        return False


@cli.command()
def doctor():
    typer.echo("\n📋 DeployML Doctor Summary:\n")

    docker_installed = check("docker")
    terraform_installed = check("terraform")
    gcp_installed = check("gcloud")
    gcp_authed = check_gcp_auth() if gcp_installed else False
    aws_installed = check("aws")

    # Docker
    if docker_installed:
        typer.secho("\n✅ Docker 🐳 is installed", fg=typer.colors.GREEN)
    else:
        typer.secho("\n❌ Docker is not installed", fg=typer.colors.RED)

    # Terraform
    if terraform_installed:
        typer.secho("\n✅ Terraform 🔧 is installed", fg=typer.colors.GREEN)
    else:
        typer.secho("\n❌ Terraform is not installed", fg=typer.colors.RED)

    # GCP CLI
    if gcp_installed and gcp_authed:
        typer.secho(
            "\n✅ GCP CLI ☁️  installed and authenticated", fg=typer.colors.GREEN
        )
    elif gcp_installed:
        typer.secho(
            "\n⚠️ GCP CLI ⛈️  installed but not authenticated", fg=typer.colors.YELLOW
        )
    else:
        typer.secho("\n❌ GCP CLI ⛈️  not installed", fg=typer.colors.RED)

    # AWS CLI
    if aws_installed:
        typer.secho(f"\n✅ AWS CLI ☁️  installed", fg=typer.colors.GREEN)
    else:
        typer.secho("\n❌ AWS CLI ⛈️  not installed", fg=typer.colors.RED)
    typer.echo()


@cli.command()
def vm():
    """Create a new VM"""


@cli.command()
def generate():
    """Generate deployment configuration yaml"""

    display_banner("Welcome to DeployML Stack Generator!")
    typer.echo("\n")

    name = prompt("MLOps Stack name", "stack")

    provider = show_menu("☁️  Select Provider", CloudProvider, CloudProvider.LOCAL)


@cli.command()
def terraform(
    action: str,
    stack_config_path: str = typer.Option(
        ..., "--stack-config-path", help="Path to stack configuration YAML"
    ),
    output_dir: Optional[str] = typer.Option(
        None, "--output-dir", help="Output directory for Terraform files"
    ),
):
    """
    TODO
    """
    print(action)
    if action not in ["plan", "apply", "destroy"]:
        typer.secho(
            f"❌ Invalid action: {action}. Use: plan, apply, destroy",
            fg=typer.colors.RED,
        )

    config_path = Path(stack_config_path)

    print(config_path)
    try:
        with open(config_path, "r") as f:
            config = yaml.safe_load(f)

    except Exception as e:
        typer.secho(f"❌ Failed to load configuration: {e}", fg=typer.colors.RED)

    if not output_dir:
        output_dir = Path.cwd() / ".deployml" / "terraform" / config["name"]
    else:
        output_dir = Path(output_dir)


def copy_modules_to_workspace(modules_dir: Path):
    """Copy module templates to the workspace"""
    MODULE_TEMPLATES_DIR = TERRAFORM_DIR / "modules"
    if not MODULE_TEMPLATES_DIR.exists():
        typer.echo(f"❌ Module templates not found at: {MODULE_TEMPLATES_DIR}")
        typer.echo("Make sure your package includes the modules/ directory")
        raise typer.Exit(code=1)
    
    # Copy all modules
    for module_path in MODULE_TEMPLATES_DIR.iterdir():
        if module_path.is_dir():
            dest_path = modules_dir / module_path.name
            if dest_path.exists():
                shutil.rmtree(dest_path)
            shutil.copytree(module_path, dest_path)
            typer.echo(f"  ✅ Copied {module_path.name}")

def bucket_exists(bucket_name, project_id):
    client = storage.Client(project=project_id)
    try:
        client.get_bucket(bucket_name)
        return True
    except Exception:
        return False
    
def generate_unique_bucket_name(base_name, project_id):
    while True:
        suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=6))
        new_name = f"{base_name}-{suffix}"
        if not bucket_exists(new_name, project_id):
            return new_name

def generate_bucket_name(project_id):
    # Use a random animal or fallback word
    if random.random() < 0.7:
        word = random.choice(ANIMAL_NAMES)
    else:
        word = random.choice(FALLBACK_WORDS)
    suffix = ''.join(random.choices(string.ascii_lowercase + string.digits, k=4))
    return f"{word}-bucket-{project_id}-{suffix}".replace('_', '-')

@cli.command()
def deploy(
    config_path: Path = typer.Option(
        ..., "--config-path", "-c", help="Path to YAML config file"
    )
):
    """Deploy infrastructure based on a YAML config file."""

    if not config_path.exists():
        typer.echo(f"❌ Config file not found: {config_path}")
        raise typer.Exit(code=1)

    config = yaml.safe_load(config_path.read_text())

    # --- GCS bucket existence and unique name logic ---
    cloud = config["provider"]["name"]
    if cloud == "gcp":
        project_id = config["provider"]["project_id"]
        print(project_id)
        # Only run if google-cloud-storage is available
        # Find artifact_bucket in stack config
        for stage in config.get("stack", []):
            for stage_name, tool in stage.items():
                print(stage_name, tool)
                if stage_name == "artifact_tracking" and tool.get("name") == "mlflow":
                    
                    if "params" not in tool:
                        tool["params"] = {}
                    if not tool["params"].get("artifact_bucket"):
                        new_bucket = generate_bucket_name(project_id)
                        typer.echo(f"ℹ️  No bucket specified for artifact_tracking, using generated bucket name: {new_bucket}")
                        tool["params"]["artifact_bucket"] = new_bucket
                        tool["params"]["create_artifact_bucket"] = True
                    else:
                        base_bucket = tool["params"]["artifact_bucket"]
                        if bucket_exists(base_bucket, project_id):
                            typer.echo(f"ℹ️  Using specified bucket name (already exists): {base_bucket}")
                            tool["params"]["create_artifact_bucket"] = False
                        else:
                            typer.echo(f"ℹ️  Using specified bucket name: {base_bucket}")
                            tool["params"]["create_artifact_bucket"] = True

    workspace_name = (
        config.get("name") or 
        "development"
    )

    DEPLOYML_DIR = Path.cwd() / ".deployml" / workspace_name
    DEPLOYML_TERRAFORM_DIR = DEPLOYML_DIR / "terraform"
    DEPLOYML_MODULES_DIR = DEPLOYML_DIR / "terraform" / "modules"

    typer.echo(f"📁 Using workspace: {workspace_name}")
    typer.echo(f"📍 Workspace path: {DEPLOYML_DIR}")


    DEPLOYML_TERRAFORM_DIR.mkdir(parents=True, exist_ok=True)
    DEPLOYML_MODULES_DIR.mkdir(parents=True, exist_ok=True)

    typer.echo("📦 Copying module templates...")
    copy_modules_to_workspace(DEPLOYML_MODULES_DIR)

    
    region = config["provider"]["region"]
    deployment_type = config["deployment"]["type"]
    stack = config["stack"]

    print(stack)

    env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))
    main_template = env.get_template(f"{cloud}/{deployment_type}/main.tf.j2")
    var_template = env.get_template(f"{cloud}/{deployment_type}/variables.tf.j2")
    tfvars_template = env.get_template(f"{cloud}/{deployment_type}/terraform.tfvars.j2")

    # Find if any tool in the stack has create_artifact_bucket set
    create_artifact_bucket = False
    for stage in stack:
        for stage_name, tool in stage.items():
            if tool.get("params", {}).get("create_artifact_bucket", False):
                create_artifact_bucket = True

    # Render templates
    main_tf = main_template.render(
        cloud=cloud, 
        stack=stack, 
        deployment_type=deployment_type,
        create_artifact_bucket=create_artifact_bucket,
        project_id=project_id
    )
    variables_tf = var_template.render(stack=stack, cloud=cloud, project_id=project_id)
    tfvars_content = tfvars_template.render(
        project_id=project_id,
        region=region,
        zone=config["provider"].get("zone", f"{region}-a"),  # Add zone for VM
        stack=stack,
        cloud=cloud,
        create_artifact_bucket=create_artifact_bucket
    )

    # Write files
    (DEPLOYML_TERRAFORM_DIR / "main.tf").write_text(main_tf)
    (DEPLOYML_TERRAFORM_DIR / "variables.tf").write_text(variables_tf)
    (DEPLOYML_TERRAFORM_DIR / "terraform.tfvars").write_text(tfvars_content)

    # Deploy
    typer.echo(f"🚀 Deploying {config['name']} to {cloud}...")

    if not check_gcp_auth():
        typer.echo("🔐 Authenticating with GCP...")
        subprocess.run(["gcloud", "auth", "application-default", "login"], cwd=DEPLOYML_TERRAFORM_DIR)
    
    subprocess.run(["gcloud", "config", "set", "project", project_id], cwd=DEPLOYML_TERRAFORM_DIR)
    
    typer.echo("📋 Initializing Terraform...")
    subprocess.run(["terraform", "init"], cwd=DEPLOYML_TERRAFORM_DIR)
    
    typer.echo("📊 Planning deployment...")
    result = subprocess.run(["terraform", "plan"], cwd=DEPLOYML_TERRAFORM_DIR, capture_output=True, text=True)
    
    if result.returncode != 0:
        typer.echo(f"❌ Terraform plan failed: {result.stderr}")
        raise typer.Exit(code=1)
    
    print(result.stdout)
    
    if typer.confirm("Do you want to apply these changes?"):
        typer.echo("🏗️ Applying changes...")
        subprocess.run(["terraform", "init"], cwd=DEPLOYML_TERRAFORM_DIR)
        subprocess.run(["terraform", "apply", "-auto-approve"], cwd=DEPLOYML_TERRAFORM_DIR)
        typer.echo("✅ Deployment complete!")
    else:
        typer.echo("❌ Deployment cancelled")

def cleanup_terraform_files(terraform_dir: Path):
    """Clean up Terraform state files"""
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
            typer.echo(f"🗑️  Removed: {file}")
    
    typer.echo("✅ Cleanup completed")

@cli.command()
def destroy(
    config_path: Path = typer.Option(
        ..., "--config-path", "-c", help="Path to YAML config file"
    ),
    workspace: Optional[str] = typer.Option(
        None, "--workspace", help="Override workspace name from config"
    ),
    auto_approve: bool = typer.Option(
        False, "--auto-approve", help="Skip confirmation prompts"
    ),
    clean_workspace: bool = typer.Option(
        False, "--clean-workspace", help="Remove entire workspace after destroy"
    ),
):
    """Destroy infrastructure from .deployml workspace."""
    
    if not config_path.exists():
        typer.echo(f"❌ Config file not found: {config_path}")
        raise typer.Exit(code=1)

    config = yaml.safe_load(config_path.read_text())
    
    # Determine workspace name (same logic as deploy)
    workspace_name = (
        config.get("name") or 
        "default"
    )
    
    # Find the workspace
    DEPLOYML_DIR = Path.cwd() / ".deployml" / workspace_name
    DEPLOYML_TERRAFORM_DIR = DEPLOYML_DIR / "terraform"
    DEPLOYML_MODULES_DIR = DEPLOYML_DIR / "terraform" / "modules"

    if not DEPLOYML_TERRAFORM_DIR.exists():
        typer.echo(f"⚠️  No workspace found for {workspace_name}")
        typer.echo("Nothing to destroy - infrastructure may already be cleaned up.")
        return

    # Extract project info
    cloud = config["provider"]["name"]
    if cloud == "gcp":
        project_id = config["provider"]["project_id"]

    # Confirmation unless auto-approve
    if not auto_approve:
        typer.echo(f"\n⚠️  About to DESTROY infrastructure for: {workspace_name}")
        typer.echo(f"📁 Workspace: {DEPLOYML_DIR}")
        typer.echo(f"🌐 Project: {project_id}")
        typer.echo("This will permanently delete all resources!")
        
        if not typer.confirm("Are you sure you want to destroy all resources?"):
            typer.echo("❌ Destroy cancelled")
            return

    try:
        typer.echo(f"💥 Destroying infrastructure...")
        
        # Set GCP project
        subprocess.run(["gcloud", "config", "set", "project", project_id], cwd=DEPLOYML_TERRAFORM_DIR)
        
        # Build destroy command
        cmd = ["terraform", "destroy"]
        if auto_approve:
            cmd.append("-auto-approve")
        
        # Run destroy
        result = subprocess.run(cmd, cwd=DEPLOYML_TERRAFORM_DIR, check=False)
        
        if result.returncode == 0:
            typer.echo("✅ Infrastructure destroyed successfully!")
            
            if clean_workspace:
                typer.echo("🧹 Cleaning workspace...")
                shutil.rmtree(DEPLOYML_DIR)
                typer.echo("✅ Workspace cleaned")
            elif typer.confirm("Clean up Terraform state files?"):
                cleanup_terraform_files(DEPLOYML_TERRAFORM_DIR)
        else:
            typer.echo("❌ Destroy failed")
            raise typer.Exit(code=1)
            
    except Exception as e:
        typer.echo(f"❌ Error during destroy: {e}")
        raise typer.Exit(code=1)



@cli.command()
def status():
    """Check deployment status"""
    typer.echo("Checking deployment status...")


def main():
    cli()


if __name__ == "__main__":
    main()
