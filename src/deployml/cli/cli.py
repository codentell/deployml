import sys
import yaml
import typer
import shutil
import subprocess
from deployml.utils.banner import display_banner
from deployml.utils.menu import prompt, show_menu
from deployml.utils.constants import TEMPLATE_DIR, TERRAFORM_DIR, TOOL_VARIABLES
from deployml.enum.cloud_provider import CloudProvider
from jinja2 import Environment, FileSystemLoader
from pathlib import Path
from typing import Optional


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

    cloud = config["provider"]["name"]
    
    if cloud == "gcp":
        project_id = config["provider"]["project_id"]
    
    region = config["provider"]["region"]
    deployment_type = config["deployment"]["type"]
    stack = config["stack"]

    env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))
    main_template = env.get_template("main.tf.j2")
    var_template = env.get_template("variables.tf.j2")

    # Render templates
    main_tf = main_template.render(
        cloud=cloud, 
        stack=stack, 
        deployment_type=deployment_type
    )
    variables_tf = var_template.render(stack=stack, cloud=cloud)

    (TERRAFORM_DIR / "main.tf").write_text(main_tf)
    (TERRAFORM_DIR / "variables.tf").write_text(variables_tf)

    # Build terraform.tfvars with all parameters
    tfvars_dict = {
        "project_id": project_id,
        "region": region,
    }
    
    # Add parameters from YAML config
    resource_params = {"cpu_limit", "memory_limit", "cpu_request", "memory_request", "max_scale", "container_concurrency"}
    
    for stage in stack:
        for stage_name, tool in stage.items():
            # Enable this module by default
            tfvars_dict[f"enable_{stage_name}_{tool['name']}"] = "true"
            
            for key, value in tool.get("params", {}).items():
                # Skip the general 'image' parameter and resource params to avoid conflicts
                if key != "image" and key not in resource_params:
                    tfvars_dict[key] = value
                
                # Add per-module image variables
                if key == "image":
                    tfvars_dict[f"{stage_name}_{tool['name']}_image"] = value
    
    # Add defaults for optional variables
    tfvars_dict.update({
        "global_image": f"gcr.io/{project_id}/mlflow/mlflow:latest",
        "allow_public_access": "true",
        "auto_approve": "false",
        "cpu_limit": "2000m",
        "memory_limit": "2Gi", 
        "cpu_request": "1000m",
        "memory_request": "1Gi",
        "max_scale": "10",
        "container_concurrency": "80",
        "db_type": "mysql",
        "db_user": "",
        "db_password": "",
        "db_name": "",
        "db_port": "3306",
    })
    
    # Write terraform.tfvars
    tfvars_content = "\n".join(f'{k} = "{v}"' for k, v in tfvars_dict.items())
    (TERRAFORM_DIR / "terraform.tfvars").write_text(tfvars_content)

    # Deploy
    typer.echo(f"🚀 Deploying {config['name']} to {cloud}...")
    
    if not check_gcp_auth():
        typer.echo("🔐 Authenticating with GCP...")
        subprocess.run(["gcloud", "auth", "application-default", "login"], cwd=TERRAFORM_DIR)
    
    subprocess.run(["gcloud", "config", "set", "project", project_id], cwd=TERRAFORM_DIR)
    
    typer.echo("📋 Initializing Terraform...")
    subprocess.run(["terraform", "init"], cwd=TERRAFORM_DIR)
    
    typer.echo("📊 Planning deployment...")
    result = subprocess.run(["terraform", "plan"], cwd=TERRAFORM_DIR, capture_output=True, text=True)
    
    if result.returncode != 0:
        typer.echo(f"❌ Terraform plan failed: {result.stderr}")
        raise typer.Exit(code=1)
    
    print(result.stdout)
    
    if typer.confirm("Do you want to apply these changes?"):
        typer.echo("🏗️ Applying changes...")
        subprocess.run(["terraform", "apply", "-auto-approve"], cwd=TERRAFORM_DIR)
        typer.echo("✅ Deployment complete!")
    else:
        typer.echo("❌ Deployment cancelled")


@cli.command()
def destroy(
    stack_config_path: str = typer.Option(
        ..., "--config-path", help="Path to stack configuration YAML"
    ),
    auto_approve: bool = typer.Option(
        False, "--auto-approve", help="Skip confirmation prompts"
    ),
):
    """
    Destroy infrastructure based on configuration file.
    
    Example:
        deployml destroy --config-path config.yaml
        deployml destroy --config-path config.yaml --auto-approve
    """
    
    config_path = Path(stack_config_path)
    
    # Load configuration
    try:
        typer.secho(f"📖 Loading configuration from {config_path}", fg=typer.colors.BLUE)
        with open(config_path, "r") as f:
            config = yaml.safe_load(f)
    except FileNotFoundError:
        typer.secho(f"❌ Configuration file not found: {config_path}", fg=typer.colors.RED)
        raise typer.Exit(1)
    except Exception as e:
        typer.secho(f"❌ Failed to load configuration: {e}", fg=typer.colors.RED)
        raise typer.Exit(1)

    # Set terraform directory based on config
    terraform_dir = Path.cwd() / ".deployml" / "terraform" / config["name"]
    
    # Check if terraform directory exists
    if not terraform_dir.exists():
        typer.secho(f"⚠️  No infrastructure found for {config['name']}", fg=typer.colors.YELLOW)
        typer.secho("Nothing to destroy - infrastructure may already be cleaned up.", fg=typer.colors.GREEN)
        return

    # Confirmation unless auto-approve
    if not auto_approve:
        typer.secho(f"\n⚠️  About to DESTROY infrastructure for: {config['name']}", fg=typer.colors.RED, bold=True)
        typer.secho(f"📁 Terraform directory: {terraform_dir}", fg=typer.colors.BLUE)
        typer.secho("This will permanently delete all resources!", fg=typer.colors.RED)
        
        if not typer.confirm("Are you sure you want to destroy all resources?"):
            typer.secho("❌ Destroy cancelled", fg=typer.colors.YELLOW)
            return

    # Change to terraform directory and run destroy
    try:
        typer.secho(f"💥 Destroying infrastructure...", fg=typer.colors.BLUE)
        
        # Build destroy command
        cmd = ["terraform", "destroy"]
        if auto_approve:
            cmd.append("-auto-approve")
        
        # Run the command
        result = subprocess.run(
            cmd,
            cwd=terraform_dir,
            check=False
        )
        
        if result.returncode == 0:
            typer.secho("✅ Infrastructure destroyed successfully!", fg=typer.colors.GREEN)
            
            # Ask if user wants to clean up terraform files
            if typer.confirm("Clean up Terraform state files?"):
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
                            import shutil
                            shutil.rmtree(file_path)
                        else:
                            file_path.unlink()
                        typer.secho(f"🗑️  Removed: {file}", fg=typer.colors.BLUE)
                
                typer.secho("✅ Cleanup completed", fg=typer.colors.GREEN)
        else:
            typer.secho("❌ Destroy failed", fg=typer.colors.RED)
            raise typer.Exit(1)
            
    except FileNotFoundError:
        typer.secho("❌ Terraform not found. Please install Terraform.", fg=typer.colors.RED)
        raise typer.Exit(1)
    except Exception as e:
        typer.secho(f"❌ Error during destroy: {e}", fg=typer.colors.RED)
        raise typer.Exit(1)



@cli.command()
def status():
    """Check deployment status"""
    typer.echo("Checking deployment status...")


def main():
    cli()


if __name__ == "__main__":
    main()
