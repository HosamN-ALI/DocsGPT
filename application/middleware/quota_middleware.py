"""
Middleware to enforce request quotas based on subscription plans.
"""

from functools import wraps

from flask import jsonify, make_response, request

from application.auth import handle_auth
from application.services.subscription_service import SubscriptionService
from application.services.usage_service import UsageService


def require_quota(func):
    """
    Decorator to enforce request quota limits.
    Apply this to endpoints that should count against the user's quota.
    """

    @wraps(func)
    def wrapper(*args, **kwargs):
        # Get authenticated user
        decoded_token = handle_auth(request)

        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}), 401
            )

        user_id = decoded_token.get("sub")

        # Check and reset quota if needed
        SubscriptionService.check_and_reset_quota(user_id)

        # Check if user has available requests
        has_quota, error_msg, quota_info = UsageService.check_request_limit(user_id)

        if not has_quota:
            return make_response(
                jsonify({"success": False, "message": error_msg, "quota": quota_info}),
                429,  # Too Many Requests
            )

        # Increment request count
        success, increment_error = UsageService.increment_request_count(user_id)
        if not success:
            return make_response(
                jsonify({"success": False, "message": increment_error}), 500
            )

        # Execute the original function
        return func(*args, **kwargs)

    return wrapper
