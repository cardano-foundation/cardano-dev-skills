"""CLI input validation utilities."""

from pathlib import Path

import click


def prompt_for_confirmation(message: str, default: bool = False) -> bool:
    """Prompt user for confirmation with better formatting."""
    return click.confirm(click.style(message, fg="yellow"), default=default)


def validate_and_prompt_overwrite(file_path: Path) -> bool:
    """Check if file exists and prompt for overwrite confirmation."""
    if file_path.exists():
        return prompt_for_confirmation(
            f"File {file_path} already exists. Overwrite?", default=False
        )
    return True
