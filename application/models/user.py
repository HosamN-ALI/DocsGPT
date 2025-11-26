"""
Enhanced user model with authentication and subscription data.
"""

from datetime import datetime
from typing import Optional

from bson import ObjectId
from pydantic import BaseModel, EmailStr, Field


class UserModel(BaseModel):
    """Enhanced user model with authentication and subscription data"""

    user_id: str  # Unique identifier (existing field)
    email: EmailStr
    password_hash: str  # bcrypt hashed password
    name: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    # Subscription information
    subscription_plan: str = "free"  # free, pro, enterprise
    stripe_customer_id: Optional[str] = None
    stripe_subscription_id: Optional[str] = None
    subscription_status: str = "active"  # active, canceled, past_due, incomplete
    subscription_start_date: Optional[datetime] = None
    subscription_end_date: Optional[datetime] = None

    # Usage tracking
    current_period_requests: int = 0
    current_period_start: datetime = Field(default_factory=datetime.utcnow)
    current_period_end: datetime = Field(default_factory=datetime.utcnow)

    # Existing fields
    agent_preferences: dict = {"pinned": [], "shared_with_me": []}

    # Account status
    is_active: bool = True
    is_verified: bool = False
    email_verification_token: Optional[str] = None
    password_reset_token: Optional[str] = None
    password_reset_expires: Optional[datetime] = None

    class Config:
        json_encoders = {ObjectId: str, datetime: lambda v: v.isoformat()}
