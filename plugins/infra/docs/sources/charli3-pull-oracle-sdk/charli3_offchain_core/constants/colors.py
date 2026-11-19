from enum import Enum


class CliColor(str, Enum):
    """CLI color scheme"""

    SUCCESS = "green"
    ERROR = "red"
    WARNING = "yellow"
    INFO = "blue"
    HEADER = "cyan"
    ADDRESS = "bright_blue"
    HASH = "bright_black"
    PROGRESS = "yellow"
    TITLE = "bright_cyan"
    NEUTRAL = "white"

    DETAIL = "bright_white"
    PROCESSING = "magenta"
    HIGHLIGHT = "bright_yellow"
    VALUE = "bright_magenta"
    SECONDARY = "white"
    EMPHASIS = "bright_red"
