"""
Authentication service for user registration, login, and password management.
"""

import secrets
from datetime import datetime, timedelta
from typing import Optional, Tuple

from bson import ObjectId
from jose import jwt
from passlib.context import CryptContext
from pydantic import EmailStr

from application.core.mongo_db import MongoDB
from application.core.settings import settings

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
            return (
                False,
                f"Password must be at least {settings.PASSWORD_MIN_LENGTH} characters",
            )

        if settings.PASSWORD_REQUIRE_UPPERCASE and not any(
            c.isupper() for c in password
        ):
            return False, "Password must contain at least one uppercase letter"

        if settings.PASSWORD_REQUIRE_LOWERCASE and not any(
            c.islower() for c in password
        ):
            return False, "Password must contain at least one lowercase letter"

        if settings.PASSWORD_REQUIRE_DIGIT and not any(c.isdigit() for c in password):
            return False, "Password must contain at least one digit"

        if settings.PASSWORD_REQUIRE_SPECIAL:
            special_chars = "!@#$%^&*()_+-=[]{}|;:,.<>?"
            if not any(c in special_chars for c in password):
                return False, "Password must contain at least one special character"

        return True, None

    @staticmethod
    def create_access_token(
        user_id: str, expires_delta: Optional[timedelta] = None
    ) -> str:
        """Create JWT access token"""
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(
                seconds=settings.JWT_ACCESS_TOKEN_EXPIRES
            )

        payload = {"sub": user_id, "exp": expire, "type": "access"}

        token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm="HS256")
        return token

    @staticmethod
    def create_refresh_token(user_id: str) -> str:
        """Create JWT refresh token"""
        expire = datetime.utcnow() + timedelta(
            seconds=settings.JWT_REFRESH_TOKEN_EXPIRES
        )

        payload = {"sub": user_id, "exp": expire, "type": "refresh"}

        token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm="HS256")
        return token

    @staticmethod
    def generate_verification_token() -> str:
        """Generate email verification token"""
        return secrets.token_urlsafe(32)

    @staticmethod
    def register_user(
        email: EmailStr, password: str, name: str
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
            "agent_preferences": {"pinned": [], "shared_with_me": []},
            # Account status
            "is_active": True,
            "is_verified": False,
            "email_verification_token": AuthService.generate_verification_token(),
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
    def authenticate_user(
        email: EmailStr, password: str
    ) -> Tuple[bool, Optional[dict], Optional[str]]:
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
    def update_password(
        user_id: str, old_password: str, new_password: str
    ) -> Tuple[bool, Optional[str]]:
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
                    "updated_at": datetime.utcnow(),
                }
            },
        )

        return True, None
