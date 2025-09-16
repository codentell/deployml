import typer 

def prompt(prompt_text: str, default: str, default_color=typer.colors.GREEN):
    colored_default = typer.style(default, fg=default_color, bold=True)
    display_text = f"{prompt_text} [{colored_default}]"
    result = typer.prompt(display_text, default=default, show_default=False)
    return result

def show_menu(title: str, enum_class, default_value=None) -> str:
    """Display a menu for enum values and get user selection"""
    typer.echo(f"\n{title}")
    typer.echo("=" * len(title))
    
    # Convert enum to list of values
    options = [item.value for item in enum_class]
    
    # Find default index
    default_index = 0
    if default_value:
        try:
            default_index = options.index(default_value.value if hasattr(default_value, 'value') else default_value)
        except ValueError:
            default_index = 0
    
    for i, option in enumerate(options, 1):
        typer.echo(f"  {i}. {option}")
    
    while True:
        try:
            choice = prompt(f"\nSelect option (1-{len(options)})", default=options[default_index])
            choice_index = int(choice) - 1
            
            if 0 <= choice_index < len(options):
                selected = options[choice_index]
                typer.secho(f"✅ Selected: {selected}", fg=typer.colors.GREEN)
                return selected
            else:
                typer.secho(f"Please enter a number between 1 and {len(options)}", fg=typer.colors.RED)
        except ValueError:
            typer.secho("Please enter a valid number", fg=typer.colors.RED)

