"""
Request quota model for tracking usage limits.
"""

from datetime import datetime

from pydantic import BaseModel, Field


class RequestQuotaModel(BaseModel):
    """Track request quotas per billing period"""

    user_id: str
    subscription_plan: str

    # Period information
    period_start: datetime
    period_end: datetime

    # Quota limits
    request_limit: int  # Based on subscription plan
    requests_used: int = 0
    requests_remaining: int

    # Last update
    last_updated: datetime = Field(default_factory=datetime.utcnow)

    # Reset information
    next_reset_date: datetime

    class Config:
        json_encoders = {datetime: lambda v: v.isoformat()}
