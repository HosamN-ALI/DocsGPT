# DocsGPT Subscription System Implementation Plan

## Executive Summary

This document outlines the complete implementation plan for adding a subscription system with token tracking, billing, and user authentication to DocsGPT. The implementation will integrate with Stripe for payment processing while maintaining compatibility with the existing architecture.

---

## Current Architecture Analysis

### Technology Stack
- **Frontend**: React 19.1.0 + Vite 7.2.0 + TypeScript + Redux Toolkit
- **Backend**: Flask 3.1.1 + Python with Gunicorn
- **Database**: MongoDB 4.11.3
- **Cache/Queue**: Redis + Celery
- **Authentication**: JWT-based (python-jose)
- **Containerization**: Docker + Docker Compose

### Existing Components

#### Backend Structure
```
application/
├── api/
│   ├── user/           # User API routes (existing)
│   ├── answer/         # Answer endpoints
│   └── internal/       # Internal routes
├── core/
│   ├── settings.py     # Configuration
│   └── mongo_db.py     # MongoDB connection
├── auth.py             # JWT authentication handler
├── usage.py            # Token usage tracking (existing)
└── app.py             # Main Flask application
```

#### Database Collections (Existing)
- `users` - Basic user documents with agent preferences
- `token_usage` - Token usage tracking (prompt_tokens, generated_tokens)
- `conversations` - Conversation history
- `agents` - AI agents configuration
- `sources` - Document sources
- `prompts` - Custom prompts

#### Authentication System (Current)
- Supports three modes: `None`, `simple_jwt`, `session_jwt`
- JWT tokens stored in localStorage
- `handle_auth()` function validates JWT tokens
- No password-based authentication exists

---

## Requirements Specification

### 1. Subscription Plans

| Plan | Price | Requests/Month | Features |
|------|-------|----------------|----------|
| Free | $0 | 1,000 | Basic models only |
| Pro | $15 | 10,000 | All models |
| Enterprise | $30 | 100,000 | All models + priority processing |

**Stripe Product Configuration:**
- Free: `prod_TSeyFs4TEbju1A` (price: `price_1SVje6QZf6X1AyY5M7FaQzlS`)
- Pro: `prod_TSey5KafEFEsW9` (price: `price_1SVje7QZf6X1AyY5KoKCiHea`)
- Enterprise: `prod_TSeyNNEx9WnH11` (price: `price_1SVje8QZf6X1AyY5aQpJxo0A`)

**Stripe Keys (Configure via Environment Variables):**
- Publishable: `STRIPE_PUBLISHABLE_KEY` (from Stripe Dashboard)
- Secret: `STRIPE_SECRET_KEY` (from Stripe Dashboard)
- Webhook Secret: `STRIPE_WEBHOOK_SECRET` (from Stripe Webhooks)

### 2. Token Calculation Formula
```
Final Cost = Model Base Cost + (Model Base Cost * 5%)
```

### 3. User Registration
- Initial: Email/Password authentication
- Future: Google OAuth integration
- Required fields: Email, Password, Name, Created Date

### 4. Token Tracking
- Track per request
- Track per model usage
- Store with user_id, timestamp, model_name
- Enforce subscription limits

---

## Implementation Plan

---

## PHASE 1: Database Schema & Models

### 1.1 Enhanced Users Collection Schema

```python
# application/models/user.py (NEW FILE)

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
    agent_preferences: dict = {
        "pinned": [],
        "shared_with_me": []
    }
    
    # Account status
    is_active: bool = True
    is_verified: bool = False
    email_verification_token: Optional[str] = None
    password_reset_token: Optional[str] = None
    password_reset_expires: Optional[datetime] = None
    
    class Config:
        json_encoders = {
            ObjectId: str,
            datetime: lambda v: v.isoformat()
        }
```

### MongoDB Indexes to Create:
```python
# In application/api/user/base.py - add to initialization

users_collection.create_index("email", unique=True)
users_collection.create_index("stripe_customer_id")
users_collection.create_index("stripe_subscription_id")
users_collection.create_index([("email", 1), ("is_active", 1)])
```

### 1.2 Subscription History Collection (NEW)

```python
# application/models/subscription.py (NEW FILE)

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
```

**Collection Name:** `subscription_history`

**Indexes:**
```python
subscription_history_collection.create_index("user_id")
subscription_history_collection.create_index("stripe_subscription_id")
subscription_history_collection.create_index([("user_id", 1), ("created_at", -1)])
```

### 1.3 Enhanced Token Usage Collection

**Update existing `token_usage` collection schema:**

```python
# application/models/token_usage.py (NEW FILE)

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
```

**Enhanced Indexes:**
```python
token_usage_collection.create_index([("user_id", 1), ("timestamp", -1)])
token_usage_collection.create_index([("user_id", 1), ("billing_period_start", 1)])
token_usage_collection.create_index("conversation_id")
token_usage_collection.create_index([("model_name", 1), ("timestamp", -1)])
```

### 1.4 Request Quota Tracking Collection (NEW)

```python
# application/models/quota.py (NEW FILE)

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
```

**Collection Name:** `request_quotas`

**Indexes:**
```python
request_quotas_collection.create_index("user_id", unique=True)
request_quotas_collection.create_index([("user_id", 1), ("period_start", 1)])
request_quotas_collection.create_index("next_reset_date")
```

---

## PHASE 2: Backend Implementation

### 2.1 Configuration Updates

**Update `application/core/settings.py`:**

```python
# Add to Settings class

# Stripe Configuration (set via environment variables)
STRIPE_SECRET_KEY: Optional[str] = None
STRIPE_PUBLISHABLE_KEY: Optional[str] = None
STRIPE_WEBHOOK_SECRET: Optional[str] = None

# Subscription Plans Configuration
SUBSCRIPTION_PLANS: dict = {
    "free": {
        "name": "Free",
        "price": 0,
        "request_limit": 1000,
        "features": ["basic_models"],
        "stripe_price_id": "price_1SVje6QZf6X1AyY5M7FaQzlS",
        "stripe_product_id": "prod_TSeyFs4TEbju1A"
    },
    "pro": {
        "name": "Pro",
        "price": 15,
        "request_limit": 10000,
        "features": ["all_models"],
        "stripe_price_id": "price_1SVje7QZf6X1AyY5KoKCiHea",
        "stripe_product_id": "prod_TSey5KafEFEsW9"
    },
    "enterprise": {
        "name": "Enterprise",
        "price": 30,
        "request_limit": 100000,
        "features": ["all_models", "priority_processing"],
        "stripe_price_id": "price_1SVje8QZf6X1AyY5aQpJxo0A",
        "stripe_product_id": "prod_TSeyNNEx9WnH11"
    }
}

# Token Cost Markup
TOKEN_COST_MARKUP_PERCENTAGE: float = 5.0

# Model Pricing (USD per 1K tokens)
MODEL_PRICING: dict = {
    "gpt-4": {"prompt": 0.03, "completion": 0.06},
    "gpt-4-turbo": {"prompt": 0.01, "completion": 0.03},
    "gpt-3.5-turbo": {"prompt": 0.0005, "completion": 0.0015},
    "claude-3-opus": {"prompt": 0.015, "completion": 0.075},
    "claude-3-sonnet": {"prompt": 0.003, "completion": 0.015},
    "claude-3-haiku": {"prompt": 0.00025, "completion": 0.00125},
}

# Password Security
PASSWORD_MIN_LENGTH: int = 8
PASSWORD_REQUIRE_UPPERCASE: bool = True
PASSWORD_REQUIRE_LOWERCASE: bool = True
PASSWORD_REQUIRE_DIGIT: bool = True
PASSWORD_REQUIRE_SPECIAL: bool = True

# JWT Configuration (enhance existing)
JWT_ACCESS_TOKEN_EXPIRES: int = 3600  # 1 hour
JWT_REFRESH_TOKEN_EXPIRES: int = 2592000  # 30 days

# Email Configuration (for future email verification)
SMTP_HOST: Optional[str] = None
SMTP_PORT: Optional[int] = None
SMTP_USERNAME: Optional[str] = None
SMTP_PASSWORD: Optional[str] = None
SMTP_FROM_EMAIL: Optional[str] = None
```

**Update `application/requirements.txt`:**

```txt
# Add these new dependencies
stripe==11.8.0
passlib==1.7.4
bcrypt==4.2.0
email-validator==2.2.0
pydantic[email]==2.10.5
```

### 2.2 Authentication Service

**Create `application/services/auth_service.py` (NEW FILE):**

```python
"""
Authentication service for user registration, login, and password management.
"""

from datetime import datetime, timedelta
from typing import Optional, Tuple
import secrets

from bson import ObjectId
from jose import jwt
from passlib.context import CryptContext
from pydantic import EmailStr

from application.core.settings import settings
from application.core.mongo_db import MongoDB

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Database
mongo = MongoDB.get_client()
db = mongo[settings.MONGO_DB_NAME]
users_collection = db["users"]


class AuthService:
    """Service for authentication operations"""
    
    @staticmethod
    def verify_password(plain_password: str, hashed_password: str) -> bool:
        """Verify a password against its hash"""
        return pwd_context.verify(plain_password, hashed_password)
    
    @staticmethod
    def get_password_hash(password: str) -> str:
        """Hash a password"""
        return pwd_context.hash(password)
    
    @staticmethod
    def validate_password_strength(password: str) -> Tuple[bool, Optional[str]]:
        """
        Validate password meets security requirements.
        
        Returns:
            Tuple of (is_valid, error_message)
        """
        if len(password) < settings.PASSWORD_MIN_LENGTH:
            return False, f"Password must be at least {settings.PASSWORD_MIN_LENGTH} characters"
        
        if settings.PASSWORD_REQUIRE_UPPERCASE and not any(c.isupper() for c in password):
            return False, "Password must contain at least one uppercase letter"
        
        if settings.PASSWORD_REQUIRE_LOWERCASE and not any(c.islower() for c in password):
            return False, "Password must contain at least one lowercase letter"
        
        if settings.PASSWORD_REQUIRE_DIGIT and not any(c.isdigit() for c in password):
            return False, "Password must contain at least one digit"
        
        if settings.PASSWORD_REQUIRE_SPECIAL:
            special_chars = "!@#$%^&*()_+-=[]{}|;:,.<>?"
            if not any(c in special_chars for c in password):
                return False, "Password must contain at least one special character"
        
        return True, None
    
    @staticmethod
    def create_access_token(user_id: str, expires_delta: Optional[timedelta] = None) -> str:
        """Create JWT access token"""
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(seconds=settings.JWT_ACCESS_TOKEN_EXPIRES)
        
        payload = {
            "sub": user_id,
            "exp": expire,
            "type": "access"
        }
        
        token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm="HS256")
        return token
    
    @staticmethod
    def create_refresh_token(user_id: str) -> str:
        """Create JWT refresh token"""
        expire = datetime.utcnow() + timedelta(seconds=settings.JWT_REFRESH_TOKEN_EXPIRES)
        
        payload = {
            "sub": user_id,
            "exp": expire,
            "type": "refresh"
        }
        
        token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm="HS256")
        return token
    
    @staticmethod
    def generate_verification_token() -> str:
        """Generate email verification token"""
        return secrets.token_urlsafe(32)
    
    @staticmethod
    def register_user(
        email: EmailStr,
        password: str,
        name: str
    ) -> Tuple[bool, Optional[dict], Optional[str]]:
        """
        Register a new user.
        
        Returns:
            Tuple of (success, user_data, error_message)
        """
        # Validate password
        is_valid, error_msg = AuthService.validate_password_strength(password)
        if not is_valid:
            return False, None, error_msg
        
        # Check if email already exists
        existing_user = users_collection.find_one({"email": email})
        if existing_user:
            return False, None, "Email already registered"
        
        # Generate user_id
        user_id = str(ObjectId())
        
        # Hash password
        password_hash = AuthService.get_password_hash(password)
        
        # Create user document
        now = datetime.utcnow()
        user_doc = {
            "user_id": user_id,
            "email": email,
            "password_hash": password_hash,
            "name": name,
            "created_at": now,
            "updated_at": now,
            
            # Default subscription (free)
            "subscription_plan": "free",
            "subscription_status": "active",
            "subscription_start_date": now,
            
            # Usage tracking
            "current_period_requests": 0,
            "current_period_start": now,
            "current_period_end": now + timedelta(days=30),
            
            # Agent preferences (existing field)
            "agent_preferences": {
                "pinned": [],
                "shared_with_me": []
            },
            
            # Account status
            "is_active": True,
            "is_verified": False,
            "email_verification_token": AuthService.generate_verification_token()
        }
        
        # Insert user
        try:
            users_collection.insert_one(user_doc)
            
            # Remove sensitive data before returning
            user_doc.pop("password_hash", None)
            user_doc.pop("email_verification_token", None)
            
            return True, user_doc, None
        except Exception as e:
            return False, None, f"Registration failed: {str(e)}"
    
    @staticmethod
    def authenticate_user(email: EmailStr, password: str) -> Tuple[bool, Optional[dict], Optional[str]]:
        """
        Authenticate a user with email and password.
        
        Returns:
            Tuple of (success, user_data, error_message)
        """
        # Find user by email
        user = users_collection.find_one({"email": email})
        if not user:
            return False, None, "Invalid email or password"
        
        # Check if user is active
        if not user.get("is_active", True):
            return False, None, "Account is disabled"
        
        # Verify password
        if not AuthService.verify_password(password, user.get("password_hash", "")):
            return False, None, "Invalid email or password"
        
        # Remove sensitive data
        user.pop("password_hash", None)
        user.pop("email_verification_token", None)
        user.pop("password_reset_token", None)
        
        return True, user, None
    
    @staticmethod
    def get_user_by_id(user_id: str) -> Optional[dict]:
        """Get user by user_id"""
        user = users_collection.find_one({"user_id": user_id})
        if user:
            user.pop("password_hash", None)
            user.pop("email_verification_token", None)
            user.pop("password_reset_token", None)
        return user
    
    @staticmethod
    def update_password(user_id: str, old_password: str, new_password: str) -> Tuple[bool, Optional[str]]:
        """
        Update user password.
        
        Returns:
            Tuple of (success, error_message)
        """
        # Get user
        user = users_collection.find_one({"user_id": user_id})
        if not user:
            return False, "User not found"
        
        # Verify old password
        if not AuthService.verify_password(old_password, user.get("password_hash", "")):
            return False, "Current password is incorrect"
        
        # Validate new password
        is_valid, error_msg = AuthService.validate_password_strength(new_password)
        if not is_valid:
            return False, error_msg
        
        # Hash new password
        new_password_hash = AuthService.get_password_hash(new_password)
        
        # Update password
        users_collection.update_one(
            {"user_id": user_id},
            {
                "$set": {
                    "password_hash": new_password_hash,
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        return True, None
```

### 2.3 Subscription Service

**Create `application/services/subscription_service.py` (NEW FILE):**

```python
"""
Subscription service for managing user subscriptions and Stripe integration.
"""

from datetime import datetime, timedelta
from typing import Optional, Tuple, Dict
import stripe

from application.core.settings import settings
from application.core.mongo_db import MongoDB

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
        
        plan_config = SubscriptionService.get_plan_config(user.get("subscription_plan", "free"))
        
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
            "request_limit": plan_config.get("request_limit") if plan_config else 0
        }
    
    @staticmethod
    def create_stripe_customer(user_id: str, email: str, name: str) -> Tuple[bool, Optional[str], Optional[str]]:
        """
        Create a Stripe customer for the user.
        
        Returns:
            Tuple of (success, customer_id, error_message)
        """
        try:
            customer = stripe.Customer.create(
                email=email,
                name=name,
                metadata={"user_id": user_id}
            )
            
            # Update user with Stripe customer ID
            users_collection.update_one(
                {"user_id": user_id},
                {"$set": {"stripe_customer_id": customer.id}}
            )
            
            return True, customer.id, None
        except stripe.error.StripeError as e:
            return False, None, str(e)
    
    @staticmethod
    def create_checkout_session(
        user_id: str,
        plan_name: str,
        success_url: str,
        cancel_url: str
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
                line_items=[{
                    "price": plan_config["stripe_price_id"],
                    "quantity": 1,
                }],
                mode="subscription",
                success_url=success_url,
                cancel_url=cancel_url,
                metadata={
                    "user_id": user_id,
                    "plan": plan_name
                }
            )
            
            return True, session.url, None
        except stripe.error.StripeError as e:
            return False, None, str(e)
    
    @staticmethod
    def upgrade_subscription(
        user_id: str,
        new_plan: str,
        stripe_subscription_id: Optional[str] = None
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
            "current_period_requests": 0
        }
        
        if stripe_subscription_id:
            update_data["stripe_subscription_id"] = stripe_subscription_id
        
        users_collection.update_one(
            {"user_id": user_id},
            {"$set": update_data}
        )
        
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
                    "next_reset_date": now + timedelta(days=30)
                }
            },
            upsert=True
        )
        
        # Record in subscription history
        subscription_history_collection.insert_one({
            "user_id": user_id,
            "subscription_plan": new_plan,
            "action": "upgraded",
            "stripe_subscription_id": stripe_subscription_id,
            "amount": plan_config["price"],
            "currency": "usd",
            "created_at": now,
            "metadata": {}
        })
        
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
                    stripe_subscription_id,
                    cancel_at_period_end=True
                )
            except stripe.error.StripeError as e:
                return False, str(e)
        
        # Update user status
        users_collection.update_one(
            {"user_id": user_id},
            {
                "$set": {
                    "subscription_status": "canceled",
                    "updated_at": datetime.utcnow()
                }
            }
        )
        
        # Record in history
        subscription_history_collection.insert_one({
            "user_id": user_id,
            "subscription_plan": user.get("subscription_plan", "free"),
            "action": "canceled",
            "stripe_subscription_id": stripe_subscription_id,
            "created_at": datetime.utcnow(),
            "metadata": {}
        })
        
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
            plan_config = SubscriptionService.get_plan_config(user.get("subscription_plan", "free"))
            if plan_config:
                new_period_end = now + timedelta(days=30)
                
                users_collection.update_one(
                    {"user_id": user_id},
                    {
                        "$set": {
                            "current_period_start": now,
                            "current_period_end": new_period_end,
                            "current_period_requests": 0,
                            "updated_at": now
                        }
                    }
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
                            "next_reset_date": new_period_end
                        }
                    },
                    upsert=True
                )
    
    @staticmethod
    def get_subscription_history(user_id: str, limit: int = 10) -> list:
        """Get subscription history for user"""
        history = subscription_history_collection.find(
            {"user_id": user_id}
        ).sort("created_at", -1).limit(limit)
        
        return list(history)
```

### 2.4 Usage Tracking Service

**Create `application/services/usage_service.py` (NEW FILE):**

```python
"""
Usage tracking service for token usage and request counting.
"""

from datetime import datetime, timedelta
from typing import Optional, Tuple

from application.core.settings import settings
from application.core.mongo_db import MongoDB

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
        model_name: str,
        prompt_tokens: int,
        completion_tokens: int
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
        api_key: Optional[str] = None
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
                
                "request_type": "answer"
            }
            
            token_usage_collection.insert_one(usage_doc)
            
            return True, None
        except Exception as e:
            return False, str(e)
    
    @staticmethod
    def check_request_limit(user_id: str) -> Tuple[bool, Optional[str], Optional[dict]]:
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
            "period_end": user.get("current_period_end")
        }
        
        # Check if limit exceeded
        if current_requests >= request_limit:
            return False, f"Request limit exceeded. Upgrade your plan to continue.", quota_info
        
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
                    "$set": {"updated_at": datetime.utcnow()}
                }
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
                                "requests_remaining": max(0, plan_config["request_limit"] - current_requests),
                                "last_updated": datetime.utcnow()
                            }
                        },
                        upsert=True
                    )
            
            return True, None
        except Exception as e:
            return False, str(e)
    
    @staticmethod
    def get_usage_analytics(
        user_id: str,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> dict:
        """Get usage analytics for a user"""
        if not end_date:
            end_date = datetime.utcnow()
        if not start_date:
            start_date = end_date - timedelta(days=30)
        
        # Build query
        query = {
            "user_id": user_id,
            "timestamp": {"$gte": start_date, "$lte": end_date}
        }
        
        # Get all usage records
        usage_records = list(token_usage_collection.find(query))
        
        # Calculate totals
        total_requests = len(usage_records)
        total_prompt_tokens = sum(r.get("prompt_tokens", 0) for r in usage_records)
        total_generated_tokens = sum(r.get("generated_tokens", 0) for r in usage_records)
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
                    "cost": 0
                }
            model_usage[model]["requests"] += 1
            model_usage[model]["prompt_tokens"] += record.get("prompt_tokens", 0)
            model_usage[model]["generated_tokens"] += record.get("generated_tokens", 0)
            model_usage[model]["cost"] += record.get("final_cost", 0)
        
        return {
            "period": {
                "start": start_date,
                "end": end_date
            },
            "totals": {
                "requests": total_requests,
                "prompt_tokens": total_prompt_tokens,
                "generated_tokens": total_generated_tokens,
                "total_tokens": total_prompt_tokens + total_generated_tokens,
                "total_cost": round(total_cost, 4)
            },
            "by_model": model_usage
        }
```

### 2.5 API Routes - Authentication

**Create `application/api/auth/routes.py` (NEW FILE):**

```python
"""
Authentication API routes for registration, login, and token management.
"""

from flask import request, jsonify, make_response
from flask_restx import Namespace, Resource, fields

from application.services.auth_service import AuthService
from application.auth import handle_auth

auth_ns = Namespace('auth', description='Authentication operations')

# API Models
register_model = auth_ns.model('Register', {
    'email': fields.String(required=True, description='User email'),
    'password': fields.String(required=True, description='User password'),
    'name': fields.String(required=True, description='User name')
})

login_model = auth_ns.model('Login', {
    'email': fields.String(required=True, description='User email'),
    'password': fields.String(required=True, description='User password')
})

change_password_model = auth_ns.model('ChangePassword', {
    'old_password': fields.String(required=True, description='Current password'),
    'new_password': fields.String(required=True, description='New password')
})


@auth_ns.route('/register')
class Register(Resource):
    """User registration endpoint"""
    
    @auth_ns.doc('register_user')
    @auth_ns.expect(register_model)
    def post(self):
        """Register a new user"""
        data = request.json
        
        email = data.get('email')
        password = data.get('password')
        name = data.get('name')
        
        if not email or not password or not name:
            return make_response(
                jsonify({"success": False, "message": "Missing required fields"}),
                400
            )
        
        # Register user
        success, user_data, error = AuthService.register_user(email, password, name)
        
        if not success:
            return make_response(
                jsonify({"success": False, "message": error}),
                400
            )
        
        # Create tokens
        access_token = AuthService.create_access_token(user_data["user_id"])
        refresh_token = AuthService.create_refresh_token(user_data["user_id"])
        
        return jsonify({
            "success": True,
            "message": "Registration successful",
            "user": {
                "user_id": user_data["user_id"],
                "email": user_data["email"],
                "name": user_data["name"],
                "subscription_plan": user_data["subscription_plan"]
            },
            "access_token": access_token,
            "refresh_token": refresh_token
        })


@auth_ns.route('/login')
class Login(Resource):
    """User login endpoint"""
    
    @auth_ns.doc('login_user')
    @auth_ns.expect(login_model)
    def post(self):
        """Login with email and password"""
        data = request.json
        
        email = data.get('email')
        password = data.get('password')
        
        if not email or not password:
            return make_response(
                jsonify({"success": False, "message": "Missing email or password"}),
                400
            )
        
        # Authenticate user
        success, user_data, error = AuthService.authenticate_user(email, password)
        
        if not success:
            return make_response(
                jsonify({"success": False, "message": error}),
                401
            )
        
        # Create tokens
        access_token = AuthService.create_access_token(user_data["user_id"])
        refresh_token = AuthService.create_refresh_token(user_data["user_id"])
        
        return jsonify({
            "success": True,
            "message": "Login successful",
            "user": {
                "user_id": user_data["user_id"],
                "email": user_data["email"],
                "name": user_data["name"],
                "subscription_plan": user_data.get("subscription_plan", "free")
            },
            "access_token": access_token,
            "refresh_token": refresh_token
        })


@auth_ns.route('/me')
class CurrentUser(Resource):
    """Get current authenticated user"""
    
    @auth_ns.doc('get_current_user', security='apikey')
    def get(self):
        """Get current user information"""
        decoded_token = handle_auth(request)
        
        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}),
                401
            )
        
        user_id = decoded_token.get("sub")
        user = AuthService.get_user_by_id(user_id)
        
        if not user:
            return make_response(
                jsonify({"success": False, "message": "User not found"}),
                404
            )
        
        return jsonify({
            "success": True,
            "user": {
                "user_id": user["user_id"],
                "email": user["email"],
                "name": user["name"],
                "subscription_plan": user.get("subscription_plan", "free"),
                "subscription_status": user.get("subscription_status", "active"),
                "created_at": user.get("created_at").isoformat() if user.get("created_at") else None
            }
        })


@auth_ns.route('/change-password')
class ChangePassword(Resource):
    """Change user password"""
    
    @auth_ns.doc('change_password', security='apikey')
    @auth_ns.expect(change_password_model)
    def post(self):
        """Change user password"""
        decoded_token = handle_auth(request)
        
        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}),
                401
            )
        
        user_id = decoded_token.get("sub")
        data = request.json
        
        old_password = data.get('old_password')
        new_password = data.get('new_password')
        
        if not old_password or not new_password:
            return make_response(
                jsonify({"success": False, "message": "Missing required fields"}),
                400
            )
        
        # Update password
        success, error = AuthService.update_password(user_id, old_password, new_password)
        
        if not success:
            return make_response(
                jsonify({"success": False, "message": error}),
                400
            )
        
        return jsonify({
            "success": True,
            "message": "Password updated successfully"
        })


@auth_ns.route('/refresh')
class RefreshToken(Resource):
    """Refresh access token"""
    
    @auth_ns.doc('refresh_token')
    def post(self):
        """Refresh access token using refresh token"""
        auth_header = request.headers.get("Authorization")
        
        if not auth_header:
            return make_response(
                jsonify({"success": False, "message": "Missing token"}),
                401
            )
        
        refresh_token = auth_header.replace("Bearer ", "")
        
        # Decode refresh token (will fail if expired or invalid)
        decoded = handle_auth(request)
        if not decoded or "error" in decoded:
            return make_response(
                jsonify({"success": False, "message": "Invalid or expired refresh token"}),
                401
            )
        
        # Check token type
        if decoded.get("type") != "refresh":
            return make_response(
                jsonify({"success": False, "message": "Invalid token type"}),
                401
            )
        
        user_id = decoded.get("sub")
        
        # Create new access token
        access_token = AuthService.create_access_token(user_id)
        
        return jsonify({
            "success": True,
            "access_token": access_token
        })
```

### 2.6 API Routes - Subscription

**Create `application/api/subscription/routes.py` (NEW FILE):**

```python
"""
Subscription API routes for managing user subscriptions.
"""

from flask import request, jsonify, make_response
from flask_restx import Namespace, Resource, fields

from application.services.subscription_service import SubscriptionService
from application.services.usage_service import UsageService
from application.auth import handle_auth
from application.core.settings import settings

subscription_ns = Namespace('subscription', description='Subscription management')

# API Models
checkout_model = subscription_ns.model('CreateCheckout', {
    'plan': fields.String(required=True, description='Subscription plan (pro, enterprise)'),
    'success_url': fields.String(required=True, description='Success redirect URL'),
    'cancel_url': fields.String(required=True, description='Cancel redirect URL')
})


@subscription_ns.route('/plans')
class SubscriptionPlans(Resource):
    """Get available subscription plans"""
    
    @subscription_ns.doc('get_plans')
    def get(self):
        """Get list of available subscription plans"""
        plans = []
        for plan_key, plan_config in settings.SUBSCRIPTION_PLANS.items():
            plans.append({
                "id": plan_key,
                "name": plan_config["name"],
                "price": plan_config["price"],
                "request_limit": plan_config["request_limit"],
                "features": plan_config["features"]
            })
        
        return jsonify({
            "success": True,
            "plans": plans
        })


@subscription_ns.route('/current')
class CurrentSubscription(Resource):
    """Get current user subscription"""
    
    @subscription_ns.doc('get_current_subscription', security='apikey')
    def get(self):
        """Get current subscription information"""
        decoded_token = handle_auth(request)
        
        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}),
                401
            )
        
        user_id = decoded_token.get("sub")
        
        # Check and reset quota if needed
        SubscriptionService.check_and_reset_quota(user_id)
        
        # Get subscription info
        subscription = SubscriptionService.get_user_subscription(user_id)
        
        if not subscription:
            return make_response(
                jsonify({"success": False, "message": "Subscription not found"}),
                404
            )
        
        return jsonify({
            "success": True,
            "subscription": subscription
        })


@subscription_ns.route('/checkout')
class CreateCheckout(Resource):
    """Create Stripe checkout session"""
    
    @subscription_ns.doc('create_checkout', security='apikey')
    @subscription_ns.expect(checkout_model)
    def post(self):
        """Create a Stripe checkout session for subscription"""
        decoded_token = handle_auth(request)
        
        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}),
                401
            )
        
        user_id = decoded_token.get("sub")
        data = request.json
        
        plan = data.get('plan')
        success_url = data.get('success_url')
        cancel_url = data.get('cancel_url')
        
        if not plan or not success_url or not cancel_url:
            return make_response(
                jsonify({"success": False, "message": "Missing required fields"}),
                400
            )
        
        # Create checkout session
        success, session_url, error = SubscriptionService.create_checkout_session(
            user_id, plan, success_url, cancel_url
        )
        
        if not success:
            return make_response(
                jsonify({"success": False, "message": error}),
                400
            )
        
        return jsonify({
            "success": True,
            "checkout_url": session_url
        })


@subscription_ns.route('/cancel')
class CancelSubscription(Resource):
    """Cancel subscription"""
    
    @subscription_ns.doc('cancel_subscription', security='apikey')
    def post(self):
        """Cancel current subscription"""
        decoded_token = handle_auth(request)
        
        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}),
                401
            )
        
        user_id = decoded_token.get("sub")
        
        # Cancel subscription
        success, error = SubscriptionService.cancel_subscription(user_id)
        
        if not success:
            return make_response(
                jsonify({"success": False, "message": error}),
                400
            )
        
        return jsonify({
            "success": True,
            "message": "Subscription canceled successfully"
        })


@subscription_ns.route('/history')
class SubscriptionHistory(Resource):
    """Get subscription history"""
    
    @subscription_ns.doc('get_subscription_history', security='apikey')
    def get(self):
        """Get subscription change history"""
        decoded_token = handle_auth(request)
        
        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}),
                401
            )
        
        user_id = decoded_token.get("sub")
        limit = request.args.get('limit', 10, type=int)
        
        # Get history
        history = SubscriptionService.get_subscription_history(user_id, limit)
        
        # Convert ObjectId to string
        for item in history:
            if "_id" in item:
                item["_id"] = str(item["_id"])
            if "created_at" in item:
                item["created_at"] = item["created_at"].isoformat()
        
        return jsonify({
            "success": True,
            "history": history
        })


@subscription_ns.route('/usage')
class UsageAnalytics(Resource):
    """Get usage analytics"""
    
    @subscription_ns.doc('get_usage_analytics', security='apikey')
    def get(self):
        """Get token usage analytics"""
        decoded_token = handle_auth(request)
        
        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}),
                401
            )
        
        user_id = decoded_token.get("sub")
        
        # Get analytics
        analytics = UsageService.get_usage_analytics(user_id)
        
        # Convert datetime objects
        if "period" in analytics:
            analytics["period"]["start"] = analytics["period"]["start"].isoformat()
            analytics["period"]["end"] = analytics["period"]["end"].isoformat()
        
        return jsonify({
            "success": True,
            "analytics": analytics
        })
```

### 2.7 Stripe Webhook Handler

**Create `application/api/webhooks/stripe.py` (NEW FILE):**

```python
"""
Stripe webhook handlers for subscription events.
"""

import stripe
from flask import request, jsonify, make_response
from flask_restx import Namespace, Resource

from application.core.settings import settings
from application.services.subscription_service import SubscriptionService
from application.core.mongo_db import MongoDB

stripe.api_key = settings.STRIPE_SECRET_KEY

webhook_ns = Namespace('webhooks', description='Webhook handlers')

# Database
mongo = MongoDB.get_client()
db = mongo[settings.MONGO_DB_NAME]
users_collection = db["users"]


@webhook_ns.route('/stripe')
class StripeWebhook(Resource):
    """Handle Stripe webhook events"""
    
    @webhook_ns.doc('stripe_webhook')
    def post(self):
        """Process Stripe webhook events"""
        payload = request.data
        sig_header = request.headers.get('Stripe-Signature')
        
        # Verify webhook signature (if webhook secret is configured)
        if settings.STRIPE_WEBHOOK_SECRET:
            try:
                event = stripe.Webhook.construct_event(
                    payload, sig_header, settings.STRIPE_WEBHOOK_SECRET
                )
            except stripe.error.SignatureVerificationError:
                return make_response(
                    jsonify({"success": False, "message": "Invalid signature"}),
                    400
                )
        else:
            event = stripe.Event.construct_from(
                request.json, stripe.api_key
            )
        
        # Handle event types
        event_type = event['type']
        
        if event_type == 'checkout.session.completed':
            session = event['data']['object']
            handle_checkout_completed(session)
        
        elif event_type == 'customer.subscription.created':
            subscription = event['data']['object']
            handle_subscription_created(subscription)
        
        elif event_type == 'customer.subscription.updated':
            subscription = event['data']['object']
            handle_subscription_updated(subscription)
        
        elif event_type == 'customer.subscription.deleted':
            subscription = event['data']['object']
            handle_subscription_deleted(subscription)
        
        elif event_type == 'invoice.payment_succeeded':
            invoice = event['data']['object']
            handle_payment_succeeded(invoice)
        
        elif event_type == 'invoice.payment_failed':
            invoice = event['data']['object']
            handle_payment_failed(invoice)
        
        return jsonify({"success": True})


def handle_checkout_completed(session):
    """Handle completed checkout session"""
    customer_id = session.get('customer')
    subscription_id = session.get('subscription')
    metadata = session.get('metadata', {})
    user_id = metadata.get('user_id')
    plan = metadata.get('plan')
    
    if user_id and plan:
        # Upgrade user subscription
        SubscriptionService.upgrade_subscription(user_id, plan, subscription_id)


def handle_subscription_created(subscription):
    """Handle new subscription creation"""
    customer_id = subscription.get('customer')
    subscription_id = subscription['id']
    
    # Find user by customer ID
    user = users_collection.find_one({"stripe_customer_id": customer_id})
    if user:
        # Update subscription ID
        users_collection.update_one(
            {"user_id": user["user_id"]},
            {"$set": {"stripe_subscription_id": subscription_id}}
        )


def handle_subscription_updated(subscription):
    """Handle subscription updates"""
    customer_id = subscription.get('customer')
    subscription_id = subscription['id']
    status = subscription.get('status')
    
    # Find user
    user = users_collection.find_one({"stripe_customer_id": customer_id})
    if user:
        # Update subscription status
        update_data = {
            "subscription_status": status,
            "stripe_subscription_id": subscription_id
        }
        
        users_collection.update_one(
            {"user_id": user["user_id"]},
            {"$set": update_data}
        )


def handle_subscription_deleted(subscription):
    """Handle subscription cancellation"""
    customer_id = subscription.get('customer')
    
    # Find user
    user = users_collection.find_one({"stripe_customer_id": customer_id})
    if user:
        # Downgrade to free plan
        SubscriptionService.upgrade_subscription(user["user_id"], "free", None)


def handle_payment_succeeded(invoice):
    """Handle successful payment"""
    customer_id = invoice.get('customer')
    subscription_id = invoice.get('subscription')
    
    # Find user
    user = users_collection.find_one({"stripe_customer_id": customer_id})
    if user:
        # Update subscription status to active
        users_collection.update_one(
            {"user_id": user["user_id"]},
            {"$set": {"subscription_status": "active"}}
        )


def handle_payment_failed(invoice):
    """Handle failed payment"""
    customer_id = invoice.get('customer')
    
    # Find user
    user = users_collection.find_one({"stripe_customer_id": customer_id})
    if user:
        # Update subscription status to past_due
        users_collection.update_one(
            {"user_id": user["user_id"]},
            {"$set": {"subscription_status": "past_due"}}
        )
```

### 2.8 Request Quota Middleware

**Create `application/middleware/quota_middleware.py` (NEW FILE):**

```python
"""
Middleware to enforce request quotas based on subscription plans.
"""

from functools import wraps
from flask import request, jsonify, make_response

from application.auth import handle_auth
from application.services.usage_service import UsageService
from application.services.subscription_service import SubscriptionService


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
                jsonify({"success": False, "message": "Unauthorized"}),
                401
            )
        
        user_id = decoded_token.get("sub")
        
        # Check and reset quota if needed
        SubscriptionService.check_and_reset_quota(user_id)
        
        # Check if user has available requests
        has_quota, error_msg, quota_info = UsageService.check_request_limit(user_id)
        
        if not has_quota:
            return make_response(
                jsonify({
                    "success": False,
                    "message": error_msg,
                    "quota": quota_info
                }),
                429  # Too Many Requests
            )
        
        # Increment request count
        success, increment_error = UsageService.increment_request_count(user_id)
        if not success:
            return make_response(
                jsonify({"success": False, "message": increment_error}),
                500
            )
        
        # Execute the original function
        return func(*args, **kwargs)
    
    return wrapper
```

### 2.9 Update Main Application

**Update `application/app.py`:**

```python
# Add imports at the top
from application.api.auth.routes import auth_ns
from application.api.subscription.routes import subscription_ns
from application.api.webhooks.stripe import webhook_ns

# Register new namespaces (add after existing blueprint registrations)
api.add_namespace(auth_ns, path='/api/auth')
api.add_namespace(subscription_ns, path='/api/subscription')
api.add_namespace(webhook_ns, path='/api/webhooks')

# Update API config endpoint to include Stripe publishable key
@app.route("/api/config")
def get_config():
    response = {
        "auth_type": settings.AUTH_TYPE,
        "requires_auth": settings.AUTH_TYPE in ["simple_jwt", "session_jwt"],
        "stripe_publishable_key": settings.STRIPE_PUBLISHABLE_KEY,  # NEW
        "features": {
            "subscriptions": True,
            "token_tracking": True
        }
    }
    return jsonify(response)
```

### 2.10 Update Answer Endpoint with Quota Check

**Update `application/api/answer/__init__.py` (or wherever answer endpoint is):**

```python
# Add import
from application.middleware.quota_middleware import require_quota
from application.services.usage_service import UsageService

# Apply decorator to answer endpoint
@answer_ns.route('')
class Answer(Resource):
    @require_quota  # ADD THIS DECORATOR
    @answer_ns.doc('get_answer')
    def post(self):
        """Process question and return answer"""
        # Existing answer logic...
        
        # After generating answer, record token usage
        decoded_token = handle_auth(request)
        if decoded_token:
            user_id = decoded_token.get("sub")
            
            # Get token counts from your LLM response
            prompt_tokens = ...  # Extract from response
            completion_tokens = ...  # Extract from response
            model_name = ...  # Get model name used
            model_provider = ...  # Get provider (openai, anthropic, etc.)
            
            # Record usage
            UsageService.record_token_usage(
                user_id=user_id,
                model_name=model_name,
                model_provider=model_provider,
                prompt_tokens=prompt_tokens,
                generated_tokens=completion_tokens,
                conversation_id=conversation_id,
                agent_id=agent_id
            )
        
        # Return answer...
```

---

## PHASE 3: Frontend Implementation

### 3.1 Frontend Configuration

**Create `frontend/src/config/stripe.ts` (NEW FILE):**

```typescript
/**
 * Stripe configuration
 */

export const STRIPE_CONFIG = {
  publishableKey: import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY || '',
};

export const SUBSCRIPTION_PLANS = {
  free: {
    name: 'Free',
    price: 0,
    requestLimit: 1000,
    features: [
      '1,000 requests per month',
      'Access to basic models',
      'Community support',
    ],
  },
  pro: {
    name: 'Pro',
    price: 15,
    requestLimit: 10000,
    features: [
      '10,000 requests per month',
      'Access to all models',
      'Priority support',
      'Advanced analytics',
    ],
  },
  enterprise: {
    name: 'Enterprise',
    price: 30,
    requestLimit: 100000,
    features: [
      '100,000 requests per month',
      'Access to all models',
      'Priority processing',
      'Dedicated support',
      'Custom integrations',
    ],
  },
};
```

### 3.2 API Endpoints (Frontend)

**Update `frontend/src/api/endpoints.ts`:**

```typescript
const endpoints = {
  // ... existing endpoints ...
  
  AUTH: {
    REGISTER: '/api/auth/register',
    LOGIN: '/api/auth/login',
    ME: '/api/auth/me',
    CHANGE_PASSWORD: '/api/auth/change-password',
    REFRESH: '/api/auth/refresh',
  },
  
  SUBSCRIPTION: {
    PLANS: '/api/subscription/plans',
    CURRENT: '/api/subscription/current',
    CHECKOUT: '/api/subscription/checkout',
    CANCEL: '/api/subscription/cancel',
    HISTORY: '/api/subscription/history',
    USAGE: '/api/subscription/usage',
  },
};

export default endpoints;
```

### 3.3 API Services (Frontend)

**Create `frontend/src/api/services/authService.ts` (NEW FILE):**

```typescript
import apiClient from '../client';
import endpoints from '../endpoints';

interface RegisterData {
  email: string;
  password: string;
  name: string;
}

interface LoginData {
  email: string;
  password: string;
}

interface ChangePasswordData {
  old_password: string;
  new_password: string;
}

const authService = {
  register: (data: RegisterData, token: string | null) =>
    apiClient.post(endpoints.AUTH.REGISTER, data, token),

  login: (data: LoginData, token: string | null) =>
    apiClient.post(endpoints.AUTH.LOGIN, data, token),

  getCurrentUser: (token: string | null) =>
    apiClient.get(endpoints.AUTH.ME, token),

  changePassword: (data: ChangePasswordData, token: string | null) =>
    apiClient.post(endpoints.AUTH.CHANGE_PASSWORD, data, token),

  refreshToken: (refreshToken: string) =>
    apiClient.post(endpoints.AUTH.REFRESH, {}, refreshToken),
};

export default authService;
```

**Create `frontend/src/api/services/subscriptionService.ts` (NEW FILE):**

```typescript
import apiClient from '../client';
import endpoints from '../endpoints';

interface CheckoutData {
  plan: string;
  success_url: string;
  cancel_url: string;
}

const subscriptionService = {
  getPlans: (token: string | null) =>
    apiClient.get(endpoints.SUBSCRIPTION.PLANS, token),

  getCurrentSubscription: (token: string | null) =>
    apiClient.get(endpoints.SUBSCRIPTION.CURRENT, token),

  createCheckout: (data: CheckoutData, token: string | null) =>
    apiClient.post(endpoints.SUBSCRIPTION.CHECKOUT, data, token),

  cancelSubscription: (token: string | null) =>
    apiClient.post(endpoints.SUBSCRIPTION.CANCEL, {}, token),

  getHistory: (token: string | null, limit?: number) =>
    apiClient.get(
      `${endpoints.SUBSCRIPTION.HISTORY}${limit ? `?limit=${limit}` : ''}`,
      token
    ),

  getUsage: (token: string | null) =>
    apiClient.get(endpoints.SUBSCRIPTION.USAGE, token),
};

export default subscriptionService;
```

### 3.4 Redux State Management

**Update `frontend/src/store.ts`:**

```typescript
import { configureStore } from '@reduxjs/toolkit';
import preferenceReducer from './preferences/preferenceSlice';
import authReducer from './features/auth/authSlice';  // NEW
import subscriptionReducer from './features/subscription/subscriptionSlice';  // NEW

export const store = configureStore({
  reducer: {
    preference: preferenceReducer,
    auth: authReducer,  // NEW
    subscription: subscriptionReducer,  // NEW
  },
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;
```

**Create `frontend/src/features/auth/authSlice.ts` (NEW FILE):**

```typescript
import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '../../store';

interface User {
  user_id: string;
  email: string;
  name: string;
  subscription_plan: string;
  subscription_status?: string;
}

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
}

const initialState: AuthState = {
  user: null,
  isAuthenticated: false,
  isLoading: true,
};

export const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    setUser: (state, action: PayloadAction<User | null>) => {
      state.user = action.payload;
      state.isAuthenticated = !!action.payload;
      state.isLoading = false;
    },
    setLoading: (state, action: PayloadAction<boolean>) => {
      state.isLoading = action.payload;
    },
    logout: (state) => {
      state.user = null;
      state.isAuthenticated = false;
      state.isLoading = false;
      localStorage.removeItem('authToken');
      localStorage.removeItem('refreshToken');
    },
  },
});

export const { setUser, setLoading, logout } = authSlice.actions;

export const selectUser = (state: RootState) => state.auth.user;
export const selectIsAuthenticated = (state: RootState) => state.auth.isAuthenticated;
export const selectAuthLoading = (state: RootState) => state.auth.isLoading;

export default authSlice.reducer;
```

**Create `frontend/src/features/subscription/subscriptionSlice.ts` (NEW FILE):**

```typescript
import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from '../../store';

interface Subscription {
  plan: string;
  plan_config: {
    name: string;
    price: number;
    request_limit: number;
    features: string[];
  };
  status: string;
  requests_used: number;
  request_limit: number;
  current_period_start?: string;
  current_period_end?: string;
}

interface SubscriptionState {
  current: Subscription | null;
  isLoading: boolean;
}

const initialState: SubscriptionState = {
  current: null,
  isLoading: false,
};

export const subscriptionSlice = createSlice({
  name: 'subscription',
  initialState,
  reducers: {
    setSubscription: (state, action: PayloadAction<Subscription | null>) => {
      state.current = action.payload;
    },
    setLoading: (state, action: PayloadAction<boolean>) => {
      state.isLoading = action.payload;
    },
    incrementUsage: (state) => {
      if (state.current) {
        state.current.requests_used += 1;
      }
    },
  },
});

export const { setSubscription, setLoading, incrementUsage } = subscriptionSlice.actions;

export const selectSubscription = (state: RootState) => state.subscription.current;
export const selectSubscriptionLoading = (state: RootState) => state.subscription.isLoading;

export default subscriptionSlice.reducer;
```

### 3.5 Authentication UI Components

**Create `frontend/src/components/auth/LoginForm.tsx` (NEW FILE):**

```typescript
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useDispatch } from 'react-redux';
import authService from '../../api/services/authService';
import { setUser } from '../../features/auth/authSlice';

export default function LoginForm() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  
  const navigate = useNavigate();
  const dispatch = useDispatch();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setIsLoading(true);

    try {
      const response = await authService.login({ email, password }, null);
      const data = await response.json();

      if (data.success) {
        // Store tokens
        localStorage.setItem('authToken', data.access_token);
        localStorage.setItem('refreshToken', data.refresh_token);
        
        // Update Redux state
        dispatch(setUser(data.user));
        
        // Redirect to dashboard
        navigate('/');
      } else {
        setError(data.message || 'Login failed');
      }
    } catch (err) {
      setError('An error occurred during login');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-50 px-4 py-12 dark:bg-gray-900">
      <div className="w-full max-w-md space-y-8">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900 dark:text-white">
            Sign in to DocsGPT
          </h2>
        </div>
        
        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          {error && (
            <div className="rounded-md bg-red-50 p-4 dark:bg-red-900/20">
              <p className="text-sm text-red-800 dark:text-red-300">{error}</p>
            </div>
          )}
          
          <div className="space-y-4 rounded-md shadow-sm">
            <div>
              <label htmlFor="email" className="sr-only">
                Email address
              </label>
              <input
                id="email"
                name="email"
                type="email"
                autoComplete="email"
                required
                className="relative block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white dark:placeholder-gray-400 sm:text-sm"
                placeholder="Email address"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            
            <div>
              <label htmlFor="password" className="sr-only">
                Password
              </label>
              <input
                id="password"
                name="password"
                type="password"
                autoComplete="current-password"
                required
                className="relative block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white dark:placeholder-gray-400 sm:text-sm"
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
          </div>

          <div>
            <button
              type="submit"
              disabled={isLoading}
              className="group relative flex w-full justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 disabled:opacity-50 dark:bg-indigo-500 dark:hover:bg-indigo-600"
            >
              {isLoading ? 'Signing in...' : 'Sign in'}
            </button>
          </div>
          
          <div className="text-center text-sm">
            <span className="text-gray-600 dark:text-gray-400">
              Don't have an account?{' '}
            </span>
            <button
              type="button"
              onClick={() => navigate('/register')}
              className="font-medium text-indigo-600 hover:text-indigo-500 dark:text-indigo-400"
            >
              Sign up
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
```

**Create `frontend/src/components/auth/RegisterForm.tsx` (NEW FILE):**

```typescript
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useDispatch } from 'react-redux';
import authService from '../../api/services/authService';
import { setUser } from '../../features/auth/authSlice';

export default function RegisterForm() {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    password: '',
    confirmPassword: '',
  });
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  
  const navigate = useNavigate();
  const dispatch = useDispatch();

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value,
    });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    
    // Validate passwords match
    if (formData.password !== formData.confirmPassword) {
      setError('Passwords do not match');
      return;
    }
    
    setIsLoading(true);

    try {
      const response = await authService.register(
        {
          name: formData.name,
          email: formData.email,
          password: formData.password,
        },
        null
      );
      const data = await response.json();

      if (data.success) {
        // Store tokens
        localStorage.setItem('authToken', data.access_token);
        localStorage.setItem('refreshToken', data.refresh_token);
        
        // Update Redux state
        dispatch(setUser(data.user));
        
        // Redirect to dashboard
        navigate('/');
      } else {
        setError(data.message || 'Registration failed');
      }
    } catch (err) {
      setError('An error occurred during registration');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gray-50 px-4 py-12 dark:bg-gray-900">
      <div className="w-full max-w-md space-y-8">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900 dark:text-white">
            Create your account
          </h2>
        </div>
        
        <form className="mt-8 space-y-6" onSubmit={handleSubmit}>
          {error && (
            <div className="rounded-md bg-red-50 p-4 dark:bg-red-900/20">
              <p className="text-sm text-red-800 dark:text-red-300">{error}</p>
            </div>
          )}
          
          <div className="space-y-4 rounded-md shadow-sm">
            <div>
              <label htmlFor="name" className="sr-only">
                Full name
              </label>
              <input
                id="name"
                name="name"
                type="text"
                required
                className="relative block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white dark:placeholder-gray-400 sm:text-sm"
                placeholder="Full name"
                value={formData.name}
                onChange={handleChange}
              />
            </div>
            
            <div>
              <label htmlFor="email" className="sr-only">
                Email address
              </label>
              <input
                id="email"
                name="email"
                type="email"
                autoComplete="email"
                required
                className="relative block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white dark:placeholder-gray-400 sm:text-sm"
                placeholder="Email address"
                value={formData.email}
                onChange={handleChange}
              />
            </div>
            
            <div>
              <label htmlFor="password" className="sr-only">
                Password
              </label>
              <input
                id="password"
                name="password"
                type="password"
                autoComplete="new-password"
                required
                className="relative block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white dark:placeholder-gray-400 sm:text-sm"
                placeholder="Password"
                value={formData.password}
                onChange={handleChange}
              />
              <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                Must be at least 8 characters with uppercase, lowercase, number, and special character
              </p>
            </div>
            
            <div>
              <label htmlFor="confirmPassword" className="sr-only">
                Confirm password
              </label>
              <input
                id="confirmPassword"
                name="confirmPassword"
                type="password"
                autoComplete="new-password"
                required
                className="relative block w-full appearance-none rounded-md border border-gray-300 px-3 py-2 text-gray-900 placeholder-gray-500 focus:z-10 focus:border-indigo-500 focus:outline-none focus:ring-indigo-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white dark:placeholder-gray-400 sm:text-sm"
                placeholder="Confirm password"
                value={formData.confirmPassword}
                onChange={handleChange}
              />
            </div>
          </div>

          <div>
            <button
              type="submit"
              disabled={isLoading}
              className="group relative flex w-full justify-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 disabled:opacity-50 dark:bg-indigo-500 dark:hover:bg-indigo-600"
            >
              {isLoading ? 'Creating account...' : 'Create account'}
            </button>
          </div>
          
          <div className="text-center text-sm">
            <span className="text-gray-600 dark:text-gray-400">
              Already have an account?{' '}
            </span>
            <button
              type="button"
              onClick={() => navigate('/login')}
              className="font-medium text-indigo-600 hover:text-indigo-500 dark:text-indigo-400"
            >
              Sign in
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
```

### 3.6 Subscription Management UI

**Create `frontend/src/components/subscription/PricingPlans.tsx` (NEW FILE):**

```typescript
import { useState, useEffect } from 'react';
import { useSelector } from 'react-redux';
import { useNavigate } from 'react-router-dom';
import subscriptionService from '../../api/services/subscriptionService';
import { selectToken } from '../../preferences/preferenceSlice';
import { SUBSCRIPTION_PLANS } from '../../config/stripe';

interface Plan {
  id: string;
  name: string;
  price: number;
  request_limit: number;
  features: string[];
}

export default function PricingPlans() {
  const [plans, setPlans] = useState<Plan[]>([]);
  const [currentPlan, setCurrentPlan] = useState<string>('free');
  const [isLoading, setIsLoading] = useState(false);
  const token = useSelector(selectToken);
  const navigate = useNavigate();

  useEffect(() => {
    loadPlans();
    loadCurrentSubscription();
  }, []);

  const loadPlans = async () => {
    try {
      const response = await subscriptionService.getPlans(token);
      const data = await response.json();
      if (data.success) {
        setPlans(data.plans);
      }
    } catch (error) {
      console.error('Failed to load plans:', error);
    }
  };

  const loadCurrentSubscription = async () => {
    try {
      const response = await subscriptionService.getCurrentSubscription(token);
      const data = await response.json();
      if (data.success) {
        setCurrentPlan(data.subscription.plan);
      }
    } catch (error) {
      console.error('Failed to load subscription:', error);
    }
  };

  const handleUpgrade = async (planId: string) => {
    if (planId === 'free') return;
    
    setIsLoading(true);
    try {
      const successUrl = `${window.location.origin}/subscription/success`;
      const cancelUrl = `${window.location.origin}/subscription`;
      
      const response = await subscriptionService.createCheckout(
        {
          plan: planId,
          success_url: successUrl,
          cancel_url: cancelUrl,
        },
        token
      );
      
      const data = await response.json();
      if (data.success) {
        // Redirect to Stripe Checkout
        window.location.href = data.checkout_url;
      }
    } catch (error) {
      console.error('Failed to create checkout:', error);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
      <div className="text-center">
        <h2 className="text-3xl font-extrabold text-gray-900 dark:text-white sm:text-4xl">
          Choose Your Plan
        </h2>
        <p className="mt-4 text-lg text-gray-600 dark:text-gray-400">
          Select the perfect plan for your needs
        </p>
      </div>

      <div className="mt-12 grid gap-8 lg:grid-cols-3">
        {Object.entries(SUBSCRIPTION_PLANS).map(([planId, planConfig]) => {
          const isCurrent = currentPlan === planId;
          const isPro = planId === 'pro' || planId === 'enterprise';
          
          return (
            <div
              key={planId}
              className={`flex flex-col rounded-lg shadow-lg overflow-hidden ${
                isPro
                  ? 'border-2 border-indigo-500 dark:border-indigo-400'
                  : 'border border-gray-200 dark:border-gray-700'
              }`}
            >
              <div className="px-6 py-8 bg-white dark:bg-gray-800 sm:p-10 sm:pb-6">
                <div>
                  <h3 className="inline-flex px-4 py-1 rounded-full text-sm font-semibold tracking-wide uppercase bg-indigo-100 text-indigo-600 dark:bg-indigo-900 dark:text-indigo-300">
                    {planConfig.name}
                  </h3>
                </div>
                <div className="mt-4 flex items-baseline text-6xl font-extrabold text-gray-900 dark:text-white">
                  ${planConfig.price}
                  <span className="ml-1 text-2xl font-medium text-gray-500 dark:text-gray-400">
                    /mo
                  </span>
                </div>
                <p className="mt-5 text-lg text-gray-500 dark:text-gray-400">
                  {planConfig.requestLimit.toLocaleString()} requests per month
                </p>
              </div>
              
              <div className="flex flex-1 flex-col justify-between px-6 pt-6 pb-8 bg-gray-50 dark:bg-gray-900 space-y-6 sm:p-10 sm:pt-6">
                <ul className="space-y-4">
                  {planConfig.features.map((feature, index) => (
                    <li key={index} className="flex items-start">
                      <div className="flex-shrink-0">
                        <svg
                          className="h-6 w-6 text-green-500"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M5 13l4 4L19 7"
                          />
                        </svg>
                      </div>
                      <p className="ml-3 text-base text-gray-700 dark:text-gray-300">
                        {feature}
                      </p>
                    </li>
                  ))}
                </ul>
                
                <div className="rounded-md shadow">
                  <button
                    onClick={() => handleUpgrade(planId)}
                    disabled={isCurrent || isLoading || planId === 'free'}
                    className={`flex items-center justify-center w-full px-5 py-3 border border-transparent text-base font-medium rounded-md ${
                      isCurrent
                        ? 'bg-gray-300 text-gray-500 cursor-not-allowed dark:bg-gray-700 dark:text-gray-400'
                        : isPro
                        ? 'bg-indigo-600 text-white hover:bg-indigo-700 dark:bg-indigo-500 dark:hover:bg-indigo-600'
                        : 'bg-gray-800 text-white hover:bg-gray-900 dark:bg-gray-700 dark:hover:bg-gray-600'
                    } disabled:opacity-50`}
                  >
                    {isCurrent ? 'Current Plan' : planId === 'free' ? 'Free Plan' : 'Upgrade'}
                  </button>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
```

**Create `frontend/src/components/subscription/UsageDashboard.tsx` (NEW FILE):**

```typescript
import { useState, useEffect } from 'react';
import { useSelector } from 'react-redux';
import subscriptionService from '../../api/services/subscriptionService';
import { selectToken } from '../../preferences/preferenceSlice';

export default function UsageDashboard() {
  const [subscription, setSubscription] = useState<any>(null);
  const [usage, setUsage] = useState<any>(null);
  const [isLoading, setIsLoading] = useState(true);
  const token = useSelector(selectToken);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [subResponse, usageResponse] = await Promise.all([
        subscriptionService.getCurrentSubscription(token),
        subscriptionService.getUsage(token),
      ]);

      const subData = await subResponse.json();
      const usageData = await usageResponse.json();

      if (subData.success) {
        setSubscription(subData.subscription);
      }
      if (usageData.success) {
        setUsage(usageData.analytics);
      }
    } catch (error) {
      console.error('Failed to load data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  if (isLoading) {
    return <div>Loading...</div>;
  }

  const usagePercentage = subscription
    ? (subscription.requests_used / subscription.request_limit) * 100
    : 0;

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <h2 className="text-2xl font-bold text-gray-900 dark:text-white mb-6">
        Usage Dashboard
      </h2>

      {/* Current Plan */}
      <div className="bg-white dark:bg-gray-800 shadow rounded-lg p-6 mb-6">
        <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-4">
          Current Plan: {subscription?.plan_config?.name || 'Free'}
        </h3>
        
        <div className="space-y-4">
          <div>
            <div className="flex justify-between text-sm text-gray-600 dark:text-gray-400 mb-2">
              <span>Requests Used</span>
              <span>
                {subscription?.requests_used || 0} / {subscription?.request_limit || 0}
              </span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2.5 dark:bg-gray-700">
              <div
                className={`h-2.5 rounded-full ${
                  usagePercentage > 90
                    ? 'bg-red-600'
                    : usagePercentage > 75
                    ? 'bg-yellow-600'
                    : 'bg-green-600'
                }`}
                style={{ width: `${Math.min(usagePercentage, 100)}%` }}
              />
            </div>
          </div>
          
          {subscription?.current_period_end && (
            <div className="text-sm text-gray-600 dark:text-gray-400">
              Resets on:{' '}
              {new Date(subscription.current_period_end).toLocaleDateString()}
            </div>
          )}
        </div>
      </div>

      {/* Usage Analytics */}
      {usage && (
        <div className="bg-white dark:bg-gray-800 shadow rounded-lg p-6">
          <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-4">
            Usage Analytics
          </h3>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                Total Requests
              </div>
              <div className="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                {usage.totals?.requests || 0}
              </div>
            </div>
            
            <div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                Total Tokens
              </div>
              <div className="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                {usage.totals?.total_tokens?.toLocaleString() || 0}
              </div>
            </div>
            
            <div>
              <div className="text-sm text-gray-600 dark:text-gray-400">
                Total Cost
              </div>
              <div className="mt-1 text-2xl font-semibold text-gray-900 dark:text-white">
                ${usage.totals?.total_cost?.toFixed(4) || 0}
              </div>
            </div>
          </div>

          {/* Model Usage Breakdown */}
          {usage.by_model && Object.keys(usage.by_model).length > 0 && (
            <div className="mt-6">
              <h4 className="text-md font-medium text-gray-900 dark:text-white mb-3">
                Usage by Model
              </h4>
              <div className="space-y-2">
                {Object.entries(usage.by_model).map(([model, data]: [string, any]) => (
                  <div
                    key={model}
                    className="flex justify-between items-center p-3 bg-gray-50 dark:bg-gray-900 rounded"
                  >
                    <span className="font-medium text-gray-900 dark:text-white">
                      {model}
                    </span>
                    <div className="text-right">
                      <div className="text-sm text-gray-600 dark:text-gray-400">
                        {data.requests} requests
                      </div>
                      <div className="text-sm font-medium text-gray-900 dark:text-white">
                        ${data.cost?.toFixed(4) || 0}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
```

### 3.7 Update App Routes

**Update `frontend/src/App.tsx`:**

```typescript
import LoginForm from './components/auth/LoginForm';
import RegisterForm from './components/auth/RegisterForm';
import PricingPlans from './components/subscription/PricingPlans';
import UsageDashboard from './components/subscription/UsageDashboard';

// Update Routes
<Routes>
  {/* Auth Routes */}
  <Route path="/login" element={<LoginForm />} />
  <Route path="/register" element={<RegisterForm />} />
  
  {/* Protected Routes */}
  <Route
    element={
      <AuthWrapper>
        <MainLayout />
      </AuthWrapper>
    }
  >
    <Route index element={<Conversation />} />
    <Route path="/settings/*" element={<Setting />} />
    <Route path="/agents/*" element={<Agents />} />
    <Route path="/subscription" element={<PricingPlans />} />
    <Route path="/subscription/usage" element={<UsageDashboard />} />
  </Route>
  
  {/* ... existing routes ... */}
</Routes>
```

---

## PHASE 4: Testing & Deployment

### 4.1 Testing Checklist

#### Backend Testing
- [ ] User registration with valid/invalid data
- [ ] User login with correct/incorrect credentials
- [ ] Password strength validation
- [ ] JWT token generation and verification
- [ ] Token refresh functionality
- [ ] Subscription plan retrieval
- [ ] Stripe checkout session creation
- [ ] Stripe webhook handling
- [ ] Request quota enforcement
- [ ] Token usage recording
- [ ] Usage analytics calculation
- [ ] Subscription upgrade/downgrade
- [ ] Billing period reset

#### Frontend Testing
- [ ] Registration form validation
- [ ] Login form functionality
- [ ] Token storage and retrieval
- [ ] Authenticated API calls
- [ ] Subscription plan display
- [ ] Upgrade flow to Stripe
- [ ] Usage dashboard display
- [ ] Quota exceeded handling
- [ ] Navigation and routing
- [ ] Dark mode compatibility

#### Integration Testing
- [ ] End-to-end registration → login → subscribe flow
- [ ] Stripe webhook → subscription activation
- [ ] Request counting and quota enforcement
- [ ] Token cost calculation accuracy
- [ ] Period reset on expiration
- [ ] Cancel subscription flow

### 4.2 Environment Variables

**Backend `.env` additions:**
```bash
# Stripe Configuration (get from Stripe Dashboard)
STRIPE_SECRET_KEY=sk_test_...  # Your Stripe secret key
STRIPE_PUBLISHABLE_KEY=pk_test_...  # Your Stripe publishable key
STRIPE_WEBHOOK_SECRET=whsec_...  # Set after creating webhook in Stripe dashboard

# Authentication
AUTH_TYPE=session_jwt  # Change from None to session_jwt
JWT_SECRET_KEY=  # Auto-generated on first run
JWT_ACCESS_TOKEN_EXPIRES=3600
JWT_REFRESH_TOKEN_EXPIRES=2592000

# Password Security
PASSWORD_MIN_LENGTH=8
PASSWORD_REQUIRE_UPPERCASE=true
PASSWORD_REQUIRE_LOWERCASE=true
PASSWORD_REQUIRE_DIGIT=true
PASSWORD_REQUIRE_SPECIAL=true

# Token Cost Markup
TOKEN_COST_MARKUP_PERCENTAGE=5.0
```

**Frontend `.env` additions:**
```bash
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_51SVjoMH7ebKrbxcdBYeVDbdQMlPCIhY84BZERlLTaEEH6eV1QXYEpevvExaznMWLu2bA3mcKWO4LDhwZVYGt5mAn003c7oDQJx
```

### 4.3 Deployment Steps

1. **Install new Python dependencies:**
```bash
cd /home/user/webapp
pip install -r application/requirements.txt
```

2. **Install new npm dependencies (if adding Stripe Elements):**
```bash
cd frontend
npm install @stripe/stripe-js @stripe/react-stripe-js
```

3. **Update Docker compose (if needed):**
```yaml
# deployment/docker-compose.yaml
# Ensure environment variables are passed to containers
```

4. **Set up Stripe webhook:**
   - Go to Stripe Dashboard → Webhooks
   - Create endpoint: `https://yourdomain.com/api/webhooks/stripe`
   - Select events: `checkout.session.completed`, `customer.subscription.*`, `invoice.*`
   - Copy webhook secret to `STRIPE_WEBHOOK_SECRET`

5. **Create MongoDB indexes:**
```bash
# Run these commands in MongoDB shell or via Python script
db.users.createIndex({"email": 1}, {unique: true})
db.users.createIndex({"stripe_customer_id": 1})
db.users.createIndex({"user_id": 1}, {unique: true})
db.subscription_history.createIndex({"user_id": 1})
db.token_usage.createIndex([{"user_id": 1}, {"timestamp": -1}])
db.request_quotas.createIndex({"user_id": 1}, {unique: true})
```

6. **Restart services:**
```bash
docker compose -f deployment/docker-compose.yaml down
docker compose -f deployment/docker-compose.yaml up --build -d
```

---

## Summary

This implementation plan provides:

✅ **Complete subscription system** with Free, Pro, and Enterprise tiers
✅ **Stripe payment integration** with test keys provided
✅ **User authentication** with email/password (Google OAuth ready for future)
✅ **Token tracking** with 5% markup pricing
✅ **Request quota enforcement** based on subscription plan
✅ **Usage analytics dashboard** for users
✅ **Webhook handling** for Stripe events
✅ **Billing period management** with automatic resets
✅ **MongoDB schemas** for all new data structures
✅ **Frontend UI components** for auth and subscription management
✅ **Redux state management** for authentication and subscription data

The implementation integrates seamlessly with the existing DocsGPT architecture while adding the required subscription, billing, and authentication features.

**Next Steps:**
1. Review and approve this plan
2. Ask any clarifying questions
3. Begin implementation phase by phase
4. Test thoroughly before deploying to production
