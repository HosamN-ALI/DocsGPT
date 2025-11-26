"""
Subscription service for managing user subscriptions and Stripe integration.
"""

from datetime import datetime, timedelta
from typing import Dict, Optional, Tuple

import stripe

from application.core.mongo_db import MongoDB
from application.core.settings import settings

# Initialize Stripe
stripe.api_key = settings.STRIPE_SECRET_KEY

# Database
mongo = MongoDB.get_client()
db = mongo[settings.MONGO_DB_NAME]
users_collection = db["users"]
subscription_history_collection = db["subscription_history"]
request_quotas_collection = db["request_quotas"]


class SubscriptionService:
    """Service for subscription management"""

    @staticmethod
    def get_plan_config(plan_name: str) -> Optional[dict]:
        """Get configuration for a subscription plan"""
        return settings.SUBSCRIPTION_PLANS.get(plan_name)

    @staticmethod
    def get_user_subscription(user_id: str) -> Optional[dict]:
        """Get user's current subscription information"""
        user = users_collection.find_one({"user_id": user_id})
        if not user:
            return None

        plan_config = SubscriptionService.get_plan_config(
            user.get("subscription_plan", "free")
        )

        return {
            "user_id": user_id,
            "plan": user.get("subscription_plan", "free"),
            "plan_config": plan_config,
            "status": user.get("subscription_status", "active"),
            "stripe_customer_id": user.get("stripe_customer_id"),
            "stripe_subscription_id": user.get("stripe_subscription_id"),
            "current_period_start": user.get("current_period_start"),
            "current_period_end": user.get("current_period_end"),
            "requests_used": user.get("current_period_requests", 0),
            "request_limit": plan_config.get("request_limit") if plan_config else 0,
        }

    @staticmethod
    def create_stripe_customer(
        user_id: str, email: str, name: str
    ) -> Tuple[bool, Optional[str], Optional[str]]:
        """
        Create a Stripe customer for the user.

        Returns:
            Tuple of (success, customer_id, error_message)
        """
        try:
            customer = stripe.Customer.create(
                email=email, name=name, metadata={"user_id": user_id}
            )

            # Update user with Stripe customer ID
            users_collection.update_one(
                {"user_id": user_id}, {"$set": {"stripe_customer_id": customer.id}}
            )

            return True, customer.id, None
        except stripe.error.StripeError as e:
            return False, None, str(e)

    @staticmethod
    def create_checkout_session(
        user_id: str, plan_name: str, success_url: str, cancel_url: str
    ) -> Tuple[bool, Optional[str], Optional[str]]:
        """
        Create a Stripe checkout session for subscription.

        Returns:
            Tuple of (success, session_url, error_message)
        """
        # Get user
        user = users_collection.find_one({"user_id": user_id})
        if not user:
            return False, None, "User not found"

        # Get plan configuration
        plan_config = SubscriptionService.get_plan_config(plan_name)
        if not plan_config:
            return False, None, "Invalid plan"

        # Free plan doesn't require checkout
        if plan_name == "free":
            return False, None, "Free plan doesn't require payment"

        try:
            # Ensure user has Stripe customer ID
            customer_id = user.get("stripe_customer_id")
            if not customer_id:
                success, customer_id, error = SubscriptionService.create_stripe_customer(
                    user_id, user["email"], user["name"]
                )
                if not success:
                    return False, None, error

            # Create checkout session
            session = stripe.checkout.Session.create(
                customer=customer_id,
                payment_method_types=["card"],
                line_items=[
                    {
                        "price": plan_config["stripe_price_id"],
                        "quantity": 1,
                    }
                ],
                mode="subscription",
                success_url=success_url,
                cancel_url=cancel_url,
                metadata={"user_id": user_id, "plan": plan_name},
            )

            return True, session.url, None
        except stripe.error.StripeError as e:
            return False, None, str(e)

    @staticmethod
    def upgrade_subscription(
        user_id: str, new_plan: str, stripe_subscription_id: Optional[str] = None
    ) -> Tuple[bool, Optional[str]]:
        """
        Upgrade user subscription.

        Returns:
            Tuple of (success, error_message)
        """
        # Get user
        user = users_collection.find_one({"user_id": user_id})
        if not user:
            return False, "User not found"

        # Get plan configuration
        plan_config = SubscriptionService.get_plan_config(new_plan)
        if not plan_config:
            return False, "Invalid plan"

        now = datetime.utcnow()

        # Update user subscription
        update_data = {
            "subscription_plan": new_plan,
            "subscription_status": "active",
            "updated_at": now,
            "current_period_start": now,
            "current_period_end": now + timedelta(days=30),
            "current_period_requests": 0,
        }

        if stripe_subscription_id:
            update_data["stripe_subscription_id"] = stripe_subscription_id

        users_collection.update_one({"user_id": user_id}, {"$set": update_data})

        # Update or create request quota
        request_quotas_collection.update_one(
            {"user_id": user_id},
            {
                "$set": {
                    "subscription_plan": new_plan,
                    "period_start": now,
                    "period_end": now + timedelta(days=30),
                    "request_limit": plan_config["request_limit"],
                    "requests_used": 0,
                    "requests_remaining": plan_config["request_limit"],
                    "last_updated": now,
                    "next_reset_date": now + timedelta(days=30),
                }
            },
            upsert=True,
        )

        # Record in subscription history
        subscription_history_collection.insert_one(
            {
                "user_id": user_id,
                "subscription_plan": new_plan,
                "action": "upgraded",
                "stripe_subscription_id": stripe_subscription_id,
                "amount": plan_config["price"],
                "currency": "usd",
                "created_at": now,
                "metadata": {},
            }
        )

        return True, None

    @staticmethod
    def cancel_subscription(user_id: str) -> Tuple[bool, Optional[str]]:
        """
        Cancel user subscription (downgrade to free at period end).

        Returns:
            Tuple of (success, error_message)
        """
        # Get user
        user = users_collection.find_one({"user_id": user_id})
        if not user:
            return False, "User not found"

        stripe_subscription_id = user.get("stripe_subscription_id")

        # Cancel Stripe subscription if exists
        if stripe_subscription_id:
            try:
                stripe.Subscription.modify(
                    stripe_subscription_id, cancel_at_period_end=True
                )
            except stripe.error.StripeError as e:
                return False, str(e)

        # Update user status
        users_collection.update_one(
            {"user_id": user_id},
            {"$set": {"subscription_status": "canceled", "updated_at": datetime.utcnow()}},
        )

        # Record in history
        subscription_history_collection.insert_one(
            {
                "user_id": user_id,
                "subscription_plan": user.get("subscription_plan", "free"),
                "action": "canceled",
                "stripe_subscription_id": stripe_subscription_id,
                "created_at": datetime.utcnow(),
                "metadata": {},
            }
        )

        return True, None

    @staticmethod
    def check_and_reset_quota(user_id: str) -> None:
        """Check if quota needs to be reset for new billing period"""
        user = users_collection.find_one({"user_id": user_id})
        if not user:
            return

        now = datetime.utcnow()
        period_end = user.get("current_period_end")

        # Reset if period has ended
        if period_end and now > period_end:
            plan_config = SubscriptionService.get_plan_config(
                user.get("subscription_plan", "free")
            )
            if plan_config:
                new_period_end = now + timedelta(days=30)

                users_collection.update_one(
                    {"user_id": user_id},
                    {
                        "$set": {
                            "current_period_start": now,
                            "current_period_end": new_period_end,
                            "current_period_requests": 0,
                            "updated_at": now,
                        }
                    },
                )

                # Reset request quota
                request_quotas_collection.update_one(
                    {"user_id": user_id},
                    {
                        "$set": {
                            "period_start": now,
                            "period_end": new_period_end,
                            "requests_used": 0,
                            "requests_remaining": plan_config["request_limit"],
                            "last_updated": now,
                            "next_reset_date": new_period_end,
                        }
                    },
                    upsert=True,
                )

    @staticmethod
    def get_subscription_history(user_id: str, limit: int = 10) -> list:
        """Get subscription history for user"""
        history = (
            subscription_history_collection.find({"user_id": user_id})
            .sort("created_at", -1)
            .limit(limit)
        )

        return list(history)
