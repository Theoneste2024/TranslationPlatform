"""
Structured logging utility for the Translation Platform backend.
Provides a centralized logger with consistent formatting and levels.
"""

import logging
import sys
from typing import Optional

# Create logger instance
logger = logging.getLogger("translation_platform")

# Set default level (can be overridden via environment)
logger.setLevel(logging.DEBUG)

# Create console handler with formatting
handler = logging.StreamHandler(sys.stdout)
handler.setLevel(logging.DEBUG)

# Create formatter
formatter = logging.Formatter(
    fmt="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

handler.setFormatter(formatter)

# Add handler to logger
if not logger.handlers:
    logger.addHandler(handler)


def get_logger(name: Optional[str] = None) -> logging.Logger:
    """Get a logger instance with optional name suffix."""
    if name:
        return logger.getChild(name)
    return logger


def log_info(message: str, **kwargs):
    """Log an info message."""
    logger.info(message, extra=kwargs)


def log_debug(message: str, **kwargs):
    """Log a debug message."""
    logger.debug(message, extra=kwargs)


def log_warning(message: str, **kwargs):
    """Log a warning message."""
    logger.warning(message, extra=kwargs)


def log_error(message: str, **kwargs):
    """Log an error message."""
    logger.error(message, extra=kwargs)


def log_exception(message: str, exc: Exception, **kwargs):
    """Log an exception with traceback."""
    logger.exception(f"{message}: {str(exc)}", extra=kwargs)
