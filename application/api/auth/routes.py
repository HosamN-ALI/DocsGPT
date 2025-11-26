"""
Authentication API routes for registration, login, and token management.
"""

from flask import jsonify, make_response, request
from flask_restx import Namespace, Resource, fields

from application.auth import handle_auth
from application.services.auth_service import AuthService

auth_ns = Namespace("auth", description="Authentication operations")

# API Models
register_model = auth_ns.model(
    "Register",
    {
        "email": fields.String(required=True, description="User email"),
        "password": fields.String(required=True, description="User password"),
        "name": fields.String(required=True, description="User name"),
    },
)

login_model = auth_ns.model(
    "Login",
    {
        "email": fields.String(required=True, description="User email"),
        "password": fields.String(required=True, description="User password"),
    },
)

change_password_model = auth_ns.model(
    "ChangePassword",
    {
        "old_password": fields.String(required=True, description="Current password"),
        "new_password": fields.String(required=True, description="New password"),
    },
)


@auth_ns.route("/register")
class Register(Resource):
    """User registration endpoint"""

    @auth_ns.doc("register_user")
    @auth_ns.expect(register_model)
    def post(self):
        """Register a new user"""
        data = request.json

        email = data.get("email")
        password = data.get("password")
        name = data.get("name")

        if not email or not password or not name:
            return make_response(
                jsonify({"success": False, "message": "Missing required fields"}), 400
            )

        # Register user
        success, user_data, error = AuthService.register_user(email, password, name)

        if not success:
            return make_response(jsonify({"success": False, "message": error}), 400)

        # Create tokens
        access_token = AuthService.create_access_token(user_data["user_id"])
        refresh_token = AuthService.create_refresh_token(user_data["user_id"])

        return jsonify(
            {
                "success": True,
                "message": "Registration successful",
                "user": {
                    "user_id": user_data["user_id"],
                    "email": user_data["email"],
                    "name": user_data["name"],
                    "subscription_plan": user_data["subscription_plan"],
                },
                "access_token": access_token,
                "refresh_token": refresh_token,
            }
        )


@auth_ns.route("/login")
class Login(Resource):
    """User login endpoint"""

    @auth_ns.doc("login_user")
    @auth_ns.expect(login_model)
    def post(self):
        """Login with email and password"""
        data = request.json

        email = data.get("email")
        password = data.get("password")

        if not email or not password:
            return make_response(
                jsonify({"success": False, "message": "Missing email or password"}),
                400,
            )

        # Authenticate user
        success, user_data, error = AuthService.authenticate_user(email, password)

        if not success:
            return make_response(jsonify({"success": False, "message": error}), 401)

        # Create tokens
        access_token = AuthService.create_access_token(user_data["user_id"])
        refresh_token = AuthService.create_refresh_token(user_data["user_id"])

        return jsonify(
            {
                "success": True,
                "message": "Login successful",
                "user": {
                    "user_id": user_data["user_id"],
                    "email": user_data["email"],
                    "name": user_data["name"],
                    "subscription_plan": user_data.get("subscription_plan", "free"),
                },
                "access_token": access_token,
                "refresh_token": refresh_token,
            }
        )


@auth_ns.route("/me")
class CurrentUser(Resource):
    """Get current authenticated user"""

    @auth_ns.doc("get_current_user", security="apikey")
    def get(self):
        """Get current user information"""
        decoded_token = handle_auth(request)

        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}), 401
            )

        user_id = decoded_token.get("sub")
        user = AuthService.get_user_by_id(user_id)

        if not user:
            return make_response(
                jsonify({"success": False, "message": "User not found"}), 404
            )

        return jsonify(
            {
                "success": True,
                "user": {
                    "user_id": user["user_id"],
                    "email": user["email"],
                    "name": user["name"],
                    "subscription_plan": user.get("subscription_plan", "free"),
                    "subscription_status": user.get("subscription_status", "active"),
                    "created_at": (
                        user.get("created_at").isoformat()
                        if user.get("created_at")
                        else None
                    ),
                },
            }
        )


@auth_ns.route("/change-password")
class ChangePassword(Resource):
    """Change user password"""

    @auth_ns.doc("change_password", security="apikey")
    @auth_ns.expect(change_password_model)
    def post(self):
        """Change user password"""
        decoded_token = handle_auth(request)

        if not decoded_token or "error" in decoded_token:
            return make_response(
                jsonify({"success": False, "message": "Unauthorized"}), 401
            )

        user_id = decoded_token.get("sub")
        data = request.json

        old_password = data.get("old_password")
        new_password = data.get("new_password")

        if not old_password or not new_password:
            return make_response(
                jsonify({"success": False, "message": "Missing required fields"}), 400
            )

        # Update password
        success, error = AuthService.update_password(user_id, old_password, new_password)

        if not success:
            return make_response(jsonify({"success": False, "message": error}), 400)

        return jsonify({"success": True, "message": "Password updated successfully"})


@auth_ns.route("/refresh")
class RefreshToken(Resource):
    """Refresh access token"""

    @auth_ns.doc("refresh_token")
    def post(self):
        """Refresh access token using refresh token"""
        auth_header = request.headers.get("Authorization")

        if not auth_header:
            return make_response(
                jsonify({"success": False, "message": "Missing token"}), 401
            )

        refresh_token = auth_header.replace("Bearer ", "")

        # Decode refresh token (will fail if expired or invalid)
        decoded = handle_auth(request)
        if not decoded or "error" in decoded:
            return make_response(
                jsonify(
                    {"success": False, "message": "Invalid or expired refresh token"}
                ),
                401,
            )

        # Check token type
        if decoded.get("type") != "refresh":
            return make_response(
                jsonify({"success": False, "message": "Invalid token type"}), 401
            )

        user_id = decoded.get("sub")

        # Create new access token
        access_token = AuthService.create_access_token(user_id)

        return jsonify({"success": True, "access_token": access_token})
