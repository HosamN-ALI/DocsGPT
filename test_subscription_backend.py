"""
Test script for subscription backend endpoints.
Run this after starting the backend server to verify all endpoints work.
"""

import requests
import json

BASE_URL = "http://localhost:7091"


def print_response(title, response):
    """Helper to print formatted responses"""
    print(f"\n{'='*60}")
    print(f"{title}")
    print(f"{'='*60}")
    print(f"Status Code: {response.status_code}")
    try:
        print(f"Response: {json.dumps(response.json(), indent=2)}")
    except:
        print(f"Response: {response.text}")


def test_config_endpoint():
    """Test the config endpoint includes subscription features"""
    print("\n🔍 Testing /api/config endpoint...")
    response = requests.get(f"{BASE_URL}/api/config")
    print_response("GET /api/config", response)
    
    if response.status_code == 200:
        data = response.json()
        if "stripe_publishable_key" in data and "features" in data:
            print("✅ Config endpoint includes subscription features")
        else:
            print("❌ Config endpoint missing subscription features")


def test_subscription_plans():
    """Test getting subscription plans"""
    print("\n🔍 Testing /api/subscription/plans endpoint...")
    response = requests.get(f"{BASE_URL}/api/subscription/plans")
    print_response("GET /api/subscription/plans", response)
    
    if response.status_code == 200:
        data = response.json()
        if data.get("success") and len(data.get("plans", [])) == 3:
            print("✅ Subscription plans retrieved successfully")
        else:
            print("❌ Failed to retrieve subscription plans")


def test_user_registration():
    """Test user registration"""
    print("\n🔍 Testing user registration...")
    
    user_data = {
        "email": "test@example.com",
        "password": "TestPass123!",
        "name": "Test User"
    }
    
    response = requests.post(f"{BASE_URL}/api/auth/register", json=user_data)
    print_response("POST /api/auth/register", response)
    
    if response.status_code == 200:
        data = response.json()
        if data.get("success") and data.get("access_token"):
            print("✅ User registration successful")
            return data.get("access_token")
        else:
            print("❌ User registration failed")
            return None
    else:
        print("⚠️  User might already exist, trying login...")
        return test_user_login(user_data["email"], user_data["password"])


def test_user_login(email, password):
    """Test user login"""
    print("\n🔍 Testing user login...")
    
    login_data = {
        "email": email,
        "password": password
    }
    
    response = requests.post(f"{BASE_URL}/api/auth/login", json=login_data)
    print_response("POST /api/auth/login", response)
    
    if response.status_code == 200:
        data = response.json()
        if data.get("success") and data.get("access_token"):
            print("✅ User login successful")
            return data.get("access_token")
        else:
            print("❌ User login failed")
            return None
    else:
        return None


def test_get_current_user(token):
    """Test getting current user info"""
    print("\n🔍 Testing /api/auth/me endpoint...")
    
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(f"{BASE_URL}/api/auth/me", headers=headers)
    print_response("GET /api/auth/me", response)
    
    if response.status_code == 200:
        data = response.json()
        if data.get("success") and data.get("user"):
            print("✅ Get current user successful")
        else:
            print("❌ Failed to get current user")


def test_get_current_subscription(token):
    """Test getting current subscription"""
    print("\n🔍 Testing /api/subscription/current endpoint...")
    
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(f"{BASE_URL}/api/subscription/current", headers=headers)
    print_response("GET /api/subscription/current", response)
    
    if response.status_code == 200:
        data = response.json()
        if data.get("success") and data.get("subscription"):
            print("✅ Get current subscription successful")
        else:
            print("❌ Failed to get current subscription")


def test_usage_analytics(token):
    """Test getting usage analytics"""
    print("\n🔍 Testing /api/subscription/usage endpoint...")
    
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(f"{BASE_URL}/api/subscription/usage", headers=headers)
    print_response("GET /api/subscription/usage", response)
    
    if response.status_code == 200:
        data = response.json()
        if data.get("success") and data.get("analytics"):
            print("✅ Get usage analytics successful")
        else:
            print("❌ Failed to get usage analytics")


def run_all_tests():
    """Run all backend tests"""
    print("\n" + "="*60)
    print("🚀 TESTING SUBSCRIPTION BACKEND ENDPOINTS")
    print("="*60)
    
    # Test public endpoints
    test_config_endpoint()
    test_subscription_plans()
    
    # Test authentication and protected endpoints
    token = test_user_registration()
    
    if token:
        test_get_current_user(token)
        test_get_current_subscription(token)
        test_usage_analytics(token)
    else:
        print("\n❌ Could not obtain auth token, skipping protected endpoint tests")
    
    print("\n" + "="*60)
    print("✅ BACKEND TESTS COMPLETED")
    print("="*60)
    print("\nNext steps:")
    print("1. Initialize database indexes: python application/init_db_indexes.py")
    print("2. Set up Stripe webhook in Stripe Dashboard")
    print("3. Test Stripe checkout flow")
    print("4. Implement frontend UI components")


if __name__ == "__main__":
    try:
        run_all_tests()
    except requests.exceptions.ConnectionError:
        print("\n❌ ERROR: Could not connect to backend server")
        print("Make sure the backend is running at http://localhost:7091")
        print("\nStart the backend with:")
        print("  docker compose -f deployment/docker-compose.yaml up")
