"""
Enhanced token usage model with billing calculation.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class TokenUsageModel(BaseModel):
    """Enhanced token usage tracking with billing calculation"""

    # Existing fields
    user_id: str
    api_key: Optional[str] = None
    prompt_tokens: int
    generated_tokens: int
    timestamp: datetime = Field(default_factory=datetime.utcnow)

    # NEW fields for billing
    model_name: str  # e.g., "gpt-4", "gpt-3.5-turbo"
    model_provider: str  # e.g., "openai", "anthropic"

    # Cost calculation (in USD)
    model_base_cost: float  # Base cost from provider
    markup_percentage: float = 5.0  # Default 5%
    final_cost: float  # model_base_cost * (1 + markup_percentage/100)

    # Request context
    conversation_id: Optional[str] = None
    agent_id: Optional[str] = None

    # Billing period
    billing_period_start: datetime
    billing_period_end: datetime

    # Request type
    request_type: str = "answer"  # answer, search, etc.

    class Config:
        json_encoders = {datetime: lambda v: v.isoformat()}
