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
        ..., "--config_path", "-c", help="Path to YAML config file"
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

    service = config["deployment"]["type"]

    tools = []
    for item in config["stack"]:
        for _, tool in item.items():
            tools.append(tool["name"])
    
    collected_vars = {}
    for tool in tools:
        for var in TOOL_VARIABLES.get(tool, []):
            collected_vars[var["name"]] = var  # dedupe by var name
    variables = list(collected_vars.values())
    
    
    
    
    env = Environment(loader=FileSystemLoader(TEMPLATE_DIR))
    main_template = env.get_template("main.tf.j2")
    main_tf = main_template.render(cloud=cloud, tools=tools, service=service)

    (TERRAFORM_DIR / "main.tf").write_text(main_tf)

    var_template = env.get_template("variables.tf.j2")
    var_tf = var_template.render(variables=variables)
    (TERRAFORM_DIR / "variables.tf").write_text(var_tf)

    tfvars = f"""
    project_id = "{project_id}"
    region = "{region}"
    artifact_bucket = "mlflow-artifacts-{project_id}"
    backend_store_uri = "sqlite:///mlflow.db"
    image = "us-docker.pkg.dev/{project_id}/mlflow/mlflow:latest"
    """.strip()

    print(tfvars)

    (TERRAFORM_DIR / "terraform.tfvars").write_text(tfvars)




    if not check_gcp_auth():
        subprocess.run(["gcloud", "auth", "application-default", "login"], cwd=TERRAFORM_DIR)
    subprocess.run(["gcloud", "config", "set", "project", project_id], cwd=TERRAFORM_DIR)
    subprocess.run(["terraform", "init"], cwd=TERRAFORM_DIR)
    #subprocess.run(["terraform", "plan"], cwd=TERRAFORM_DIR)
    
    
    
    subprocess.run(["terraform", "apply", "-auto-approve"], cwd=TERRAFORM_DIR)

@cli.command()
def status():
    """Check deployment status"""
    typer.echo("Checking deployment status...")


def main():
    cli()


if __name__ == "__main__":
    main()
