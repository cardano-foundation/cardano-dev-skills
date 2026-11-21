"""CLI utility functions and decorators."""

import asyncio
import logging
import os
from dataclasses import dataclass
from functools import wraps
from pathlib import Path
from typing import Any, TypeVar

import yaml


def setup_logging(verbose: bool) -> None:
    """Configure logging based on verbosity."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )


def async_command(f) -> callable:
    """Decorator to run async click commands."""

    @wraps(f)
    def wrapper(*args, **kwargs) -> None:

        return asyncio.run(f(*args, **kwargs))

    return wrapper


T = TypeVar("T", bound="ConfigFromDict")


@dataclass
class ConfigFromDict:
    """Base class for configurations that can be created from dictionaries."""

    @classmethod
    def from_dict(cls: type[T], data: dict[str, Any]) -> T:
        """Create configuration from dictionary."""
        field_types = {f.name: f.type for f in cls.__dataclass_fields__.values()}
        processed_data = {}

        for key, value in data.items():
            if key in field_types:
                field_type = field_types[key]
                if hasattr(field_type, "from_dict") and isinstance(value, dict):
                    processed_data[key] = field_type.from_dict(value)
                else:
                    processed_data[key] = value

        return cls(**processed_data)


def resolve_env_vars(data: dict[str, Any]) -> dict[str, Any]:
    """Recursively resolve environment variables in configuration."""
    resolved = {}
    for key, value in data.items():
        if isinstance(value, dict):
            resolved[key] = resolve_env_vars(value)
        elif isinstance(value, str) and value.startswith("$"):
            env_var = value[1:]  # Remove $ prefix
            resolved[key] = os.environ.get(env_var, value)
        else:
            resolved[key] = value
    return resolved


def load_yaml_config(path: Path | str) -> dict[str, Any]:
    """Load and process YAML configuration file."""
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"Config file not found: {path}")

    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    return resolve_env_vars(data)
