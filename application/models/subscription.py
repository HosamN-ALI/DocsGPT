"""
Subscription history model for tracking subscription changes and billing.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class SubscriptionHistoryModel(BaseModel):
    """Track subscription changes and billing history"""

    user_id: str
    subscription_plan: str  # free, pro, enterprise
    action: str  # created, upgraded, downgraded, canceled, renewed

    # Stripe information
    stripe_subscription_id: Optional[str] = None
    stripe_invoice_id: Optional[str] = None
    stripe_payment_intent_id: Optional[str] = None

    # Pricing
    amount: float = 0.0
    currency: str = "usd"

    # Metadata
    created_at: datetime = Field(default_factory=datetime.utcnow)
    metadata: dict = {}

    class Config:
        json_encoders = {datetime: lambda v: v.isoformat()}
