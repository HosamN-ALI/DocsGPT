"""
Middleware for request handling and quota enforcement.
"""

from .quota_middleware import require_quota

__all__ = ["require_quota"]
