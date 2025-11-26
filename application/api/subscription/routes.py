"""
Subscription API routes for managing user subscriptions.
"""

from flask import jsonify, make_response, request
from flask_restx import Namespace, Resource, fields

from application.auth import handle_auth
from application.core.settings import settings
from application.services.subscription_service import SubscriptionService
from application.services.usage_service import UsageService

subscription_ns = Namespace("subscription", description="Subscription management")

# API Models
checkout_model = subscription_ns.model(
    "CreateCheckout",
    {
        "plan": fields.String(
            required=True, description="Subscription plan (pro, enterprise)"
        ),
        "success_url": fields.String(required=True, description="Success redirect URL"),
        "cancel_url": fields.String(required=True, description="Cancel redirect URL"),
    },
)


@subscription_ns.route("/plans")
class SubscriptionPlans(Resource):
    """Get available subscription plans"""

    @subscription_ns.doc("get_plans")
    def get(self):
        """Get list of available subscription plans"""
        plans = []
        for plan_key, plan_config in settings.SUBSCRIPTION_PLANS.items():
            plans.append(
                {
                    "id": plan_key,
                    "name": plan_config["name"],
                    "price": plan_config["price"],
                    "request_limit": plan_config["request_limit"],
                    "features": plan_config["features"],
                }
            )

        return jsonify({"success": True, "plans": plans})


@subscription_ns.route("/current")
class CurrentSubscription(Resource):
    """Get current user subscription"""

    @subscription_ns.doc("get_current_subscription", security="apikey")
    def get(self):
        """Get current subscription information"""
        decoded_token = handle_auth(request)

        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}), 401
            )

        user_id = decoded_token.get("sub")

        # Check and reset quota if needed
        SubscriptionService.check_and_reset_quota(user_id)

        # Get subscription info
        subscription = SubscriptionService.get_user_subscription(user_id)

        if not subscription:
            return make_response(
                jsonify({"success": False, "message": "Subscription not found"}), 404
            )

        return jsonify({"success": True, "subscription": subscription})


@subscription_ns.route("/checkout")
class CreateCheckout(Resource):
    """Create Stripe checkout session"""

    @subscription_ns.doc("create_checkout", security="apikey")
    @subscription_ns.expect(checkout_model)
    def post(self):
        """Create a Stripe checkout session for subscription"""
        decoded_token = handle_auth(request)

        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}), 401
            )

        user_id = decoded_token.get("sub")
        data = request.json

        plan = data.get("plan")
        success_url = data.get("success_url")
        cancel_url = data.get("cancel_url")

        if not plan or not success_url or not cancel_url:
            return make_response(
                jsonify({"success": False, "message": "Missing required fields"}), 400
            )

        # Create checkout session
        success, session_url, error = SubscriptionService.create_checkout_session(
            user_id, plan, success_url, cancel_url
        )

        if not success:
            return make_response(jsonify({"success": False, "message": error}), 400)

        return jsonify({"success": True, "checkout_url": session_url})


@subscription_ns.route("/cancel")
class CancelSubscription(Resource):
    """Cancel subscription"""

    @subscription_ns.doc("cancel_subscription", security="apikey")
    def post(self):
        """Cancel current subscription"""
        decoded_token = handle_auth(request)

        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}), 401
            )

        user_id = decoded_token.get("sub")

        # Cancel subscription
        success, error = SubscriptionService.cancel_subscription(user_id)

        if not success:
            return make_response(jsonify({"success": False, "message": error}), 400)

        return jsonify({"success": True, "message": "Subscription canceled successfully"})


@subscription_ns.route("/history")
class SubscriptionHistory(Resource):
    """Get subscription history"""

    @subscription_ns.doc("get_subscription_history", security="apikey")
    def get(self):
        """Get subscription change history"""
        decoded_token = handle_auth(request)

        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}), 401
            )

        user_id = decoded_token.get("sub")
        limit = request.args.get("limit", 10, type=int)

        # Get history
        history = SubscriptionService.get_subscription_history(user_id, limit)

        # Convert ObjectId to string
        for item in history:
            if "_id" in item:
                item["_id"] = str(item["_id"])
            if "created_at" in item:
                item["created_at"] = item["created_at"].isoformat()

        return jsonify({"success": True, "history": history})


@subscription_ns.route("/usage")
class UsageAnalytics(Resource):
    """Get usage analytics"""

    @subscription_ns.doc("get_usage_analytics", security="apikey")
    def get(self):
        """Get token usage analytics"""
        decoded_token = handle_auth(request)

        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}), 401
            )

        user_id = decoded_token.get("sub")

        # Get analytics
        analytics = UsageService.get_usage_analytics(user_id)

        # Convert datetime objects
        if "period" in analytics:
            analytics["period"]["start"] = analytics["period"]["start"].isoformat()
            analytics["period"]["end"] = analytics["period"]["end"].isoformat()

        return jsonify({"success": True, "analytics": analytics})
