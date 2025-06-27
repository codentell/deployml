import sys
import yaml
import typer
import shutil
import subprocess
from deployml.utils.banner import display_banner
from deployml.utils.menu import prompt, show_menu
from deployml.utils.constants import (
    TEMPLATE_DIR,
    TERRAFORM_DIR,
    TOOL_VARIABLES,
    ANIMAL_NAMES,
    FALLBACK_WORDS,
    REQUIRED_GCP_APIS,
)
from deployml.enum.cloud_provider import CloudProvider
from jinja2 import Environment, FileSystemLoader
from pathlib import Path
from typing import Optional
import random
import string
from google.cloud import storage

# Import refactored utility functions
from deployml.utils.helpers import (
    check_command,
    check,
    check_gcp_auth,
    copy_modules_to_workspace,
    bucket_exists,
    generate_unique_bucket_name,
    generate_bucket_name,
    estimate_terraform_time,
    cleanup_cloud_sql_resources,
    cleanup_terraform_files,
    run_terraform_with_loading_bar,
)

import re
import time
import json

cli = typer.Typer()

@cli.command()
def doctor():
    """
    Run system checks for required tools and authentication for DeployML.
    Also checks if all required GCP APIs are enabled if GCP CLI is installed and authenticated.
    """
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
        # Check enabled GCP APIs
        project_id = typer.prompt("Enter your GCP Project ID to check enabled APIs", default="", show_default=False)
        if project_id:
            typer.echo(f"\n🔎 Checking enabled APIs for project: {project_id} ...")
            result = subprocess.run(
                [
                    "gcloud", "services", "list", "--enabled", "--project", project_id, "--format=value(config.name)"
                ],
                capture_output=True, text=True
            )
            if result.returncode != 0:
                typer.echo("❌ Failed to list enabled APIs.")
            else:
                enabled_apis = set(result.stdout.strip().splitlines())
                missing_apis = [api for api in REQUIRED_GCP_APIS if api not in enabled_apis]
                if not missing_apis:
                    typer.secho("✅ All required GCP APIs are enabled.", fg=typer.colors.GREEN)
                else:
                    typer.secho("⚠️  The following required APIs are NOT enabled:", fg=typer.colors.YELLOW)
                    for api in missing_apis:
                        typer.echo(f"  - {api}")
                    typer.echo("You can enable them with: deployml init --provider gcp --project-id <PROJECT_ID>")
    elif gcp_installed:
        typer.secho(
            "\n⚠️ GCP CLI ⛈️  installed but not authenticated",
            fg=typer.colors.YELLOW,
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
    """
    Create a new Virtual Machine (VM) deployment.
    """
    pass


@cli.command()
def generate():
    """
    Generate a deployment configuration YAML file interactively.
    """
    display_banner("Welcome to DeployML Stack Generator!")
    typer.echo("\n")
    name = prompt("MLOps Stack name", "stack")
    provider = show_menu("☁️  Select Provider", CloudProvider, CloudProvider.GCP)

    # Import DeploymentType here to avoid circular imports
    from deployml.enum.deployment_type import DeploymentType

    deployment_type = show_menu(
        "🚀 Select Deployment Type", DeploymentType, DeploymentType.CLOUD_RUN
    )

    # Get provider-specific details
    if provider == "gcp":
        project_id = prompt("GCP Project ID", "your-project-id")
        region = prompt("GCP Region", "us-west1")
        zone = (
            prompt("GCP Zone", f"{region}-a")
            if deployment_type == "cloud_vm"
            else ""
        )

    # Generate YAML configuration
    config = {
        "name": name,
        "provider": {
            "name": provider,
            "project_id": project_id if provider == "gcp" else "",
            "region": region if provider == "gcp" else "",
        },
    }

    # Add zone for VM deployments
    if deployment_type == "cloud_vm" and provider == "gcp":
        config["provider"]["zone"] = zone

    config["deployment"] = {"type": deployment_type}

    # Add default stack configuration
    config["stack"] = [
        {
            "experiment_tracking": {
                "name": "mlflow",
                "params": {
                    "service_name": f"{name}-mlflow-server",
                    "allow_public_access": True,
                },
            }
        },
        {
            "artifact_tracking": {
                "name": "mlflow",
                "params": {
                    "artifact_bucket": (
                        f"{name}-artifacts-{project_id}"
                        if provider == "gcp"
                        else ""
                    ),
                    "create_bucket": True,
                },
            }
        },
        {
            "model_registry": {
                "name": "mlflow",
                "params": {"backend_store_uri": "sqlite:///mlflow.db"},
            }
        },
    ]

    # Add VM-specific parameters for cloud_vm deployment
    if deployment_type == "cloud_vm":
        config["stack"][0]["experiment_tracking"]["params"].update(
            {
                "vm_name": f"{name}-mlflow-vm",
                "machine_type": "e2-medium",
                "disk_size_gb": 20,
                "mlflow_port": 5000,
            }
        )

    # Write configuration to file
    config_filename = f"{name}.yaml"
    import yaml

    with open(config_filename, "w") as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)

    typer.secho(
        f"\n✅ Configuration saved to: {config_filename}", fg=typer.colors.GREEN
    )
    typer.echo(f"\nTo deploy this configuration, run:")
    typer.secho(
        f"  deployml deploy --config-path {config_filename}",
        fg=typer.colors.BRIGHT_BLUE,
    )


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
    Run Terraform actions (plan, apply, destroy) for the specified stack configuration.
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
        typer.secho(
            f"❌ Failed to load configuration: {e}", fg=typer.colors.RED
        )

    if not output_dir:
        output_dir = Path.cwd() / ".deployml" / "terraform" / config["name"]
    else:
        output_dir = Path(output_dir)


@cli.command()
def deploy(
    config_path: Path = typer.Option(
        ..., "--config-path", "-c", help="Path to YAML config file"
    )
):
    """
    Deploy infrastructure based on a YAML configuration file.
    """
    if not config_path.exists():
        typer.echo(f"❌ Config file not found: {config_path}")
        raise typer.Exit(code=1)

    config = yaml.safe_load(config_path.read_text())

    # --- GCS bucket existence and unique name logic ---
    cloud = config["provider"]["name"]
    if cloud == "gcp":
        project_id = config["provider"]["project_id"]
        # Only run if google-cloud-storage is available
        # Find artifact_bucket in stack config
        for stage in config.get("stack", []):
            for stage_name, tool in stage.items():
                if (
                    stage_name == "artifact_tracking"
                    and tool.get("name") == "mlflow"
                ):
                    if "params" not in tool:
                        tool["params"] = {}
                    if not tool["params"].get("artifact_bucket"):
                        new_bucket = generate_bucket_name(project_id)
                        typer.echo(
                            f" No bucket specified for artifact_tracking, using generated bucket name: {new_bucket}"
                        )
                        tool["params"]["artifact_bucket"] = new_bucket
                        # Only set create_artifact_bucket if neither is present
                        if (
                            "create_bucket" not in tool["params"]
                            and "create_artifact_bucket" not in tool["params"]
                        ):
                            tool["params"]["create_artifact_bucket"] = True
                    else:
                        base_bucket = tool["params"]["artifact_bucket"]
                        if bucket_exists(base_bucket, project_id):
                            typer.echo(
                                f"Using specified bucket name (already exists): {base_bucket}"
                            )
                            # Only set create_artifact_bucket if neither is present
                            if (
                                "create_bucket" not in tool["params"]
                                and "create_artifact_bucket"
                                not in tool["params"]
                            ):
                                tool["params"]["create_artifact_bucket"] = False
                        else:
                            typer.echo(
                                f"Using specified bucket name: {base_bucket}"
                            )
                            if (
                                "create_bucket" not in tool["params"]
                                and "create_artifact_bucket"
                                not in tool["params"]
                            ):
                                tool["params"]["create_artifact_bucket"] = True
                    # Set use_postgres param based on backend_store_uri
                    backend_uri = tool["params"].get("backend_store_uri", "")
                    tool["params"]["use_postgres"] = backend_uri.startswith(
                        "postgresql"
                    )

    workspace_name = config.get("name") or "development"

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

    # Ensure all stages use Cloud SQL if any stage needs it
    needs_postgres = any(
        tool.get("params", {}).get("backend_store_uri", "") == "postgresql"
        for stage in stack
        for tool in stage.values()
    )
    if needs_postgres:
        for stage in stack:
            for tool in stage.values():
                tool.setdefault("params", {})
                tool["params"]["backend_store_uri"] = "postgresql"

    env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))
    main_template = env.get_template(f"{cloud}/{deployment_type}/main.tf.j2")
    var_template = env.get_template(
        f"{cloud}/{deployment_type}/variables.tf.j2"
    )
    tfvars_template = env.get_template(
        f"{cloud}/{deployment_type}/terraform.tfvars.j2"
    )

    # Find if any tool in the stack has create_artifact_bucket set
    create_artifact_bucket = False
    for stage in stack:
        for stage_name, tool in stage.items():
            if tool.get("params", {}).get("create_artifact_bucket", False):
                create_artifact_bucket = True

    # Render templates
    if deployment_type == "cloud_vm":
        main_tf = main_template.render(
            cloud=cloud,
            stack=stack,
            deployment_type=deployment_type,
            create_artifact_bucket=create_artifact_bucket,
            project_id=project_id,
            region=region,
            zone=config["provider"].get("zone", f"{region}-a"),
        )
    else:
        main_tf = main_template.render(
            cloud=cloud,
            stack=stack,
            deployment_type=deployment_type,
            create_artifact_bucket=create_artifact_bucket,
            project_id=project_id,
        )
    variables_tf = var_template.render(
        stack=stack, cloud=cloud, project_id=project_id
    )
    tfvars_content = tfvars_template.render(
        project_id=project_id,
        region=region,
        zone=config["provider"].get("zone", f"{region}-a"),  # Add zone for VM
        stack=stack,
        cloud=cloud,
        create_artifact_bucket=create_artifact_bucket,
    )

    # Write files
    (DEPLOYML_TERRAFORM_DIR / "main.tf").write_text(main_tf)
    (DEPLOYML_TERRAFORM_DIR / "variables.tf").write_text(variables_tf)
    (DEPLOYML_TERRAFORM_DIR / "terraform.tfvars").write_text(tfvars_content)

    # Deploy
    typer.echo(f"🚀 Deploying {config['name']} to {cloud}...")

    if not check_gcp_auth():
        typer.echo("🔐 Authenticating with GCP...")
        subprocess.run(
            ["gcloud", "auth", "application-default", "login"],
            cwd=DEPLOYML_TERRAFORM_DIR,
        )

    subprocess.run(
        ["gcloud", "config", "set", "project", project_id],
        cwd=DEPLOYML_TERRAFORM_DIR,
    )

    typer.echo("📋 Initializing Terraform...")
    # Suppress output of terraform init
    subprocess.run(
        ["terraform", "init"],
        cwd=DEPLOYML_TERRAFORM_DIR,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    typer.echo("📊 Planning deployment...")
    result = subprocess.run(
        ["terraform", "plan"],
        cwd=DEPLOYML_TERRAFORM_DIR,
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        typer.echo(f"❌ Terraform plan failed: {result.stderr}")
        raise typer.Exit(code=1)

    if typer.confirm("Do you want to deploy the stack?"):
        estimated_time = estimate_terraform_time(result.stdout, "apply")
        typer.echo(f"🏗️ Applying changes... (Estimated time: {estimated_time})")
        # Suppress output of terraform init
        subprocess.run(
            ["terraform", "init"],
            cwd=DEPLOYML_TERRAFORM_DIR,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        # Parse estimated minutes from string (e.g., '~20 minutes ...')
        import re as _re

        match = _re.search(r"~(\d+)", estimated_time)
        minutes = int(match.group(1)) if match else 5
        result_code = run_terraform_with_loading_bar(
            ["terraform", "apply", "-auto-approve"],
            DEPLOYML_TERRAFORM_DIR,
            minutes,
        )
        if result_code == 0 or result_code == 1:
            typer.echo("✅ Deployment complete!")
            # Show all Terraform outputs in a user-friendly way
            output_proc = subprocess.run(
                ["terraform", "output", "-json"],
                cwd=DEPLOYML_TERRAFORM_DIR,
                capture_output=True,
                text=True,
            )
            if output_proc.returncode == 0:
                try:
                    outputs = json.loads(output_proc.stdout)
                    if outputs:
                        typer.echo("\n📦 DeployML Outputs:")
                        for key, value in outputs.items():
                            is_sensitive = value.get("sensitive", False)
                            output_type = value.get("type")
                            output_val = value.get("value")
                            if is_sensitive:
                                typer.secho(
                                    f"  {key}: [SENSITIVE] (value hidden)",
                                    fg=typer.colors.YELLOW,
                                )
                            elif isinstance(output_val, dict):
                                typer.echo(f"  {key}:")
                                for subkey, subval in output_val.items():
                                    if isinstance(subval, str) and (
                                        subval.startswith("http://")
                                        or subval.startswith("https://")
                                    ):
                                        typer.secho(
                                            f"    {subkey}: {subval}",
                                            fg=typer.colors.BRIGHT_BLUE,
                                            bold=True,
                                        )
                                    elif (
                                        isinstance(subval, str) and subval == ""
                                    ):
                                        typer.secho(
                                            f"    {subkey}: [No value] (likely using SQLite or not applicable)",
                                            fg=typer.colors.YELLOW,
                                        )
                                    else:
                                        typer.echo(f"    {subkey}: {subval}")
                            elif isinstance(output_val, list):
                                typer.echo(f"  {key}: {output_val}")
                            elif isinstance(output_val, str):
                                if output_val.startswith(
                                    "http://"
                                ) or output_val.startswith("https://"):
                                    typer.secho(
                                        f"  {key}: {output_val}",
                                        fg=typer.colors.BRIGHT_BLUE,
                                        bold=True,
                                    )
                                elif output_val == "":
                                    typer.secho(
                                        f"  {key}: [No value] (likely using SQLite or not applicable)",
                                        fg=typer.colors.YELLOW,
                                    )
                                else:
                                    typer.echo(f"  {key}: {output_val}")
                            else:
                                typer.echo(f"  {key}: {output_val}")
                    else:
                        typer.echo("No outputs found in Terraform state.")
                except Exception as e:
                    typer.echo(f"⚠️ Failed to parse Terraform outputs: {e}")
            else:
                typer.echo("⚠️ Could not retrieve Terraform outputs.")
        else:
            typer.echo("❌ Terraform apply failed")
            raise typer.Exit(code=1)
    else:
        typer.echo("❌ Deployment cancelled")


@cli.command()
def destroy(
    config_path: Path = typer.Option(
        ..., "--config-path", "-c", help="Path to YAML config file"
    ),
    workspace: Optional[str] = typer.Option(
        None, "--workspace", help="Override workspace name from config"
    ),
    clean_workspace: bool = typer.Option(
        False, "--clean-workspace", help="Remove entire workspace after destroy"
    ),
):
    """
    Destroy infrastructure and optionally clean up workspace and Terraform state files.
    """
    if not config_path.exists():
        typer.echo(f"❌ Config file not found: {config_path}")
        raise typer.Exit(code=1)

    config = yaml.safe_load(config_path.read_text())

    # Determine workspace name (same logic as deploy)
    workspace_name = config.get("name") or "default"

    # Find the workspace
    DEPLOYML_DIR = Path.cwd() / ".deployml" / workspace_name
    DEPLOYML_TERRAFORM_DIR = DEPLOYML_DIR / "terraform"
    DEPLOYML_MODULES_DIR = DEPLOYML_DIR / "terraform" / "modules"

    if not DEPLOYML_TERRAFORM_DIR.exists():
        typer.echo(f"⚠️ No workspace found for {workspace_name}")
        typer.echo(
            "Nothing to destroy - infrastructure may already be cleaned up."
        )
        return

    # Extract project info
    cloud = config["provider"]["name"]
    if cloud == "gcp":
        project_id = config["provider"]["project_id"]

    # Confirmation unless auto-approve

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
        subprocess.run(
            ["gcloud", "config", "set", "project", project_id],
            cwd=DEPLOYML_TERRAFORM_DIR,
        )

        # Check if we have Cloud SQL resources and clean them up first
        plan_result = subprocess.run(
            ["terraform", "plan", "-destroy"],
            cwd=DEPLOYML_TERRAFORM_DIR,
            capture_output=True,
            text=True,
        )

        if "google_sql_database_instance" in plan_result.stdout:
            cleanup_cloud_sql_resources(DEPLOYML_TERRAFORM_DIR, project_id)

        # Build destroy command
        cmd = ["terraform", "destroy", "--auto-approve"]

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
            typer.echo(f"❌ Destroy failed: {result.stderr}")
            raise typer.Exit(code=1)

    except Exception as e:
        typer.echo(f"❌ Error during destroy: {e}")
        raise typer.Exit(code=1)


@cli.command()
def status():
    """
    Check the deployment status of the current workspace.
    """
    typer.echo("Checking deployment status...")


@cli.command()
def init(
    provider: str = typer.Option(..., "--provider", "-p", help="Cloud provider: gcp, aws, or azure"),
    project_id: str = typer.Option("", "--project-id", "-j", help="Project ID (for GCP)"),
):
    """
    Initialize cloud project by enabling required APIs/services before deployment.
    """
    if provider == "gcp":
        if not project_id:
            typer.echo("❌ --project-id is required for GCP.")
            raise typer.Exit(code=1)
        typer.echo(f"🔑 Enabling required GCP APIs for project: {project_id} ...")
        result = subprocess.run([
            "gcloud", "services", "enable", *REQUIRED_GCP_APIS, "--project", project_id
        ])
        if result.returncode == 0:
            typer.echo("✅ All required GCP APIs are enabled.")
        else:
            typer.echo("❌ Failed to enable one or more GCP APIs.")
            raise typer.Exit(code=1)
    elif provider == "aws":
        typer.echo("No API enablement required for AWS. Ensure IAM permissions are set.")
    elif provider == "azure":
        typer.echo("No API enablement required for most Azure services. Register providers if needed.")
    else:
        typer.echo(f"❌ Unknown provider: {provider}")
        raise typer.Exit(code=1)


def main():
    """
    Entry point for the DeployML CLI.
    """
    cli()


if __name__ == "__main__":
    main()
