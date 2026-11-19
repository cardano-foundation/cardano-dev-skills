"""Progress indicators and loading displays."""

from rich.progress import Progress, SpinnerColumn, TextColumn
from rich.console import Console

console = Console()


def create_progress() -> Progress:
    """Create a progress indicator."""
    return Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        console=console,
    )
