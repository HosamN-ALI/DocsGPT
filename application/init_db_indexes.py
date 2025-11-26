"""
Initialize MongoDB indexes for subscription system.
Run this script once after deploying the subscription system.
"""

from application.core.mongo_db import MongoDB
from application.core.settings import settings

def create_indexes():
    """Create all necessary MongoDB indexes"""
    print("Initializing MongoDB indexes for subscription system...")
    
    mongo = MongoDB.get_client()
    db = mongo[settings.MONGO_DB_NAME]
    
    # Users collection indexes
    print("Creating indexes for 'users' collection...")
    users_collection = db["users"]
    
    try:
        users_collection.create_index("email", unique=True)
        print("  ✓ Created unique index on 'email'")
    except Exception as e:
        print(f"  - Index 'email' already exists or error: {e}")
    
    try:
        users_collection.create_index("stripe_customer_id")
        print("  ✓ Created index on 'stripe_customer_id'")
    except Exception as e:
        print(f"  - Index 'stripe_customer_id' already exists or error: {e}")
    
    try:
        users_collection.create_index("stripe_subscription_id")
        print("  ✓ Created index on 'stripe_subscription_id'")
    except Exception as e:
        print(f"  - Index 'stripe_subscription_id' already exists or error: {e}")
    
    try:
        users_collection.create_index([("email", 1), ("is_active", 1)])
        print("  ✓ Created compound index on 'email' and 'is_active'")
    except Exception as e:
        print(f"  - Compound index already exists or error: {e}")
    
    # Subscription history collection indexes
    print("\nCreating indexes for 'subscription_history' collection...")
    subscription_history_collection = db["subscription_history"]
    
    try:
        subscription_history_collection.create_index("user_id")
        print("  ✓ Created index on 'user_id'")
    except Exception as e:
        print(f"  - Index 'user_id' already exists or error: {e}")
    
    try:
        subscription_history_collection.create_index("stripe_subscription_id")
        print("  ✓ Created index on 'stripe_subscription_id'")
    except Exception as e:
        print(f"  - Index 'stripe_subscription_id' already exists or error: {e}")
    
    try:
        subscription_history_collection.create_index([("user_id", 1), ("created_at", -1)])
        print("  ✓ Created compound index on 'user_id' and 'created_at'")
    except Exception as e:
        print(f"  - Compound index already exists or error: {e}")
    
    # Token usage collection indexes
    print("\nCreating indexes for 'token_usage' collection...")
    token_usage_collection = db["token_usage"]
    
    try:
        token_usage_collection.create_index([("user_id", 1), ("timestamp", -1)])
        print("  ✓ Created compound index on 'user_id' and 'timestamp'")
    except Exception as e:
        print(f"  - Compound index already exists or error: {e}")
    
    try:
        token_usage_collection.create_index([("user_id", 1), ("billing_period_start", 1)])
        print("  ✓ Created compound index on 'user_id' and 'billing_period_start'")
    except Exception as e:
        print(f"  - Compound index already exists or error: {e}")
    
    try:
        token_usage_collection.create_index("conversation_id")
        print("  ✓ Created index on 'conversation_id'")
    except Exception as e:
        print(f"  - Index 'conversation_id' already exists or error: {e}")
    
    try:
        token_usage_collection.create_index([("model_name", 1), ("timestamp", -1)])
        print("  ✓ Created compound index on 'model_name' and 'timestamp'")
    except Exception as e:
        print(f"  - Compound index already exists or error: {e}")
    
    # Request quotas collection indexes
    print("\nCreating indexes for 'request_quotas' collection...")
    request_quotas_collection = db["request_quotas"]
    
    try:
        request_quotas_collection.create_index("user_id", unique=True)
        print("  ✓ Created unique index on 'user_id'")
    except Exception as e:
        print(f"  - Index 'user_id' already exists or error: {e}")
    
    try:
        request_quotas_collection.create_index([("user_id", 1), ("period_start", 1)])
        print("  ✓ Created compound index on 'user_id' and 'period_start'")
    except Exception as e:
        print(f"  - Compound index already exists or error: {e}")
    
    try:
        request_quotas_collection.create_index("next_reset_date")
        print("  ✓ Created index on 'next_reset_date'")
    except Exception as e:
        print(f"  - Index 'next_reset_date' already exists or error: {e}")
    
    print("\n✅ MongoDB index initialization complete!")


if __name__ == "__main__":
    create_indexes()
