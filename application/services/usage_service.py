"""
Usage tracking service for token usage and request counting.
"""

from datetime import datetime, timedelta
from typing import Optional, Tuple

from application.core.mongo_db import MongoDB
from application.core.settings import settings

# Database
mongo = MongoDB.get_client()
db = mongo[settings.MONGO_DB_NAME]
users_collection = db["users"]
token_usage_collection = db["token_usage"]
request_quotas_collection = db["request_quotas"]


class UsageService:
    """Service for usage tracking and enforcement"""

    @staticmethod
    def calculate_token_cost(
        model_name: str, prompt_tokens: int, completion_tokens: int
    ) -> Tuple[float, float]:
        """
        Calculate token cost with markup.

        Returns:
            Tuple of (base_cost, final_cost)
        """
        # Get model pricing
        model_pricing = settings.MODEL_PRICING.get(model_name)
        if not model_pricing:
            # Default pricing if model not found
            model_pricing = {"prompt": 0.001, "completion": 0.002}

        # Calculate base cost (per 1K tokens)
        prompt_cost = (prompt_tokens / 1000) * model_pricing["prompt"]
        completion_cost = (completion_tokens / 1000) * model_pricing["completion"]
        base_cost = prompt_cost + completion_cost

        # Apply markup
        markup_multiplier = 1 + (settings.TOKEN_COST_MARKUP_PERCENTAGE / 100)
        final_cost = base_cost * markup_multiplier

        return base_cost, final_cost

    @staticmethod
    def record_token_usage(
        user_id: str,
        model_name: str,
        model_provider: str,
        prompt_tokens: int,
        generated_tokens: int,
        conversation_id: Optional[str] = None,
        agent_id: Optional[str] = None,
        api_key: Optional[str] = None,
    ) -> Tuple[bool, Optional[str]]:
        """
        Record token usage for a user.

        Returns:
            Tuple of (success, error_message)
        """
        try:
            # Calculate costs
            base_cost, final_cost = UsageService.calculate_token_cost(
                model_name, prompt_tokens, generated_tokens
            )

            # Get user for billing period
            user = users_collection.find_one({"user_id": user_id})
            if not user:
                return False, "User not found"

            now = datetime.utcnow()
            period_start = user.get("current_period_start", now)
            period_end = user.get("current_period_end", now + timedelta(days=30))

            # Create usage record
            usage_doc = {
                "user_id": user_id,
                "api_key": api_key,
                "prompt_tokens": prompt_tokens,
                "generated_tokens": generated_tokens,
                "timestamp": now,
                # Model information
                "model_name": model_name,
                "model_provider": model_provider,
                # Cost calculation
                "model_base_cost": base_cost,
                "markup_percentage": settings.TOKEN_COST_MARKUP_PERCENTAGE,
                "final_cost": final_cost,
                # Request context
                "conversation_id": conversation_id,
                "agent_id": agent_id,
                # Billing period
                "billing_period_start": period_start,
                "billing_period_end": period_end,
                "request_type": "answer",
            }

            token_usage_collection.insert_one(usage_doc)

            return True, None
        except Exception as e:
            return False, str(e)

    @staticmethod
    def check_request_limit(
        user_id: str,
    ) -> Tuple[bool, Optional[str], Optional[dict]]:
        """
        Check if user has available requests in current period.

        Returns:
            Tuple of (has_quota, error_message, quota_info)
        """
        # Get user
        user = users_collection.find_one({"user_id": user_id})
        if not user:
            return False, "User not found", None

        # Get subscription plan
        plan_name = user.get("subscription_plan", "free")
        plan_config = settings.SUBSCRIPTION_PLANS.get(plan_name)
        if not plan_config:
            return False, "Invalid subscription plan", None

        # Get current usage
        current_requests = user.get("current_period_requests", 0)
        request_limit = plan_config["request_limit"]

        quota_info = {
            "plan": plan_name,
            "requests_used": current_requests,
            "request_limit": request_limit,
            "requests_remaining": max(0, request_limit - current_requests),
            "period_start": user.get("current_period_start"),
            "period_end": user.get("current_period_end"),
        }

        # Check if limit exceeded
        if current_requests >= request_limit:
            return (
                False,
                f"Request limit exceeded. Upgrade your plan to continue.",
                quota_info,
            )

        return True, None, quota_info

    @staticmethod
    def increment_request_count(user_id: str) -> Tuple[bool, Optional[str]]:
        """
        Increment user's request count for current period.

        Returns:
            Tuple of (success, error_message)
        """
        try:
            # Update user request count
            result = users_collection.update_one(
                {"user_id": user_id},
                {
                    "$inc": {"current_period_requests": 1},
                    "$set": {"updated_at": datetime.utcnow()},
                },
            )

            if result.modified_count == 0:
                return False, "Failed to update request count"

            # Also update quota collection
            user = users_collection.find_one({"user_id": user_id})
            if user:
                plan_name = user.get("subscription_plan", "free")
                plan_config = settings.SUBSCRIPTION_PLANS.get(plan_name)
                current_requests = user.get("current_period_requests", 0)

                if plan_config:
                    request_quotas_collection.update_one(
                        {"user_id": user_id},
                        {
                            "$set": {
                                "requests_used": current_requests,
                                "requests_remaining": max(
                                    0, plan_config["request_limit"] - current_requests
                                ),
                                "last_updated": datetime.utcnow(),
                            }
                        },
                        upsert=True,
                    )

            return True, None
        except Exception as e:
            return False, str(e)

    @staticmethod
    def get_usage_analytics(
        user_id: str,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
    ) -> dict:
        """Get usage analytics for a user"""
        if not end_date:
            end_date = datetime.utcnow()
        if not start_date:
            start_date = end_date - timedelta(days=30)

        # Build query
        query = {"user_id": user_id, "timestamp": {"$gte": start_date, "$lte": end_date}}

        # Get all usage records
        usage_records = list(token_usage_collection.find(query))

        # Calculate totals
        total_requests = len(usage_records)
        total_prompt_tokens = sum(r.get("prompt_tokens", 0) for r in usage_records)
        total_generated_tokens = sum(
            r.get("generated_tokens", 0) for r in usage_records
        )
        total_cost = sum(r.get("final_cost", 0) for r in usage_records)

        # Group by model
        model_usage = {}
        for record in usage_records:
            model = record.get("model_name", "unknown")
            if model not in model_usage:
                model_usage[model] = {
                    "requests": 0,
                    "prompt_tokens": 0,
                    "generated_tokens": 0,
                    "cost": 0,
                }
            model_usage[model]["requests"] += 1
            model_usage[model]["prompt_tokens"] += record.get("prompt_tokens", 0)
            model_usage[model]["generated_tokens"] += record.get("generated_tokens", 0)
            model_usage[model]["cost"] += record.get("final_cost", 0)

        return {
            "period": {"start": start_date, "end": end_date},
            "totals": {
                "requests": total_requests,
                "prompt_tokens": total_prompt_tokens,
                "generated_tokens": total_generated_tokens,
                "total_tokens": total_prompt_tokens + total_generated_tokens,
                "total_cost": round(total_cost, 4),
            },
            "by_model": model_usage,
        }
