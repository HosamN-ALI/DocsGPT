#!/usr/bin/env python3
"""
Standalone MongoDB index initialization script.
This script can be run independently without the application module.
"""

import os
from pymongo import MongoClient, ASCENDING, DESCENDING

def create_indexes():
    """Create all necessary MongoDB indexes"""
    
    # Get MongoDB connection string from environment or use default
    mongo_uri = os.getenv('MONGO_URI', 'mongodb://localhost:27017/')
    db_name = os.getenv('MONGO_DB_NAME', 'docsgpt')
    
    print(f"Connecting to MongoDB: {mongo_uri}")
    print(f"Database: {db_name}")
    
    try:
        # Connect to MongoDB
        client = MongoClient(mongo_uri)
        db = client[db_name]
        
        # Test connection
        client.admin.command('ping')
        print("✓ Successfully connected to MongoDB\n")
        
    except Exception as e:
        print(f"✗ Failed to connect to MongoDB: {e}")
        return
    
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
        users_collection.create_index([("email", ASCENDING), ("is_active", ASCENDING)])
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
        subscription_history_collection.create_index([("user_id", ASCENDING), ("created_at", DESCENDING)])
        print("  ✓ Created compound index on 'user_id' and 'created_at'")
    except Exception as e:
        print(f"  - Compound index already exists or error: {e}")
    
    # Token usage collection indexes
    print("\nCreating indexes for 'token_usage' collection...")
    token_usage_collection = db["token_usage"]
    
    try:
        token_usage_collection.create_index([("user_id", ASCENDING), ("timestamp", DESCENDING)])
        print("  ✓ Created compound index on 'user_id' and 'timestamp'")
    except Exception as e:
        print(f"  - Compound index already exists or error: {e}")
    
    try:
        token_usage_collection.create_index([("user_id", ASCENDING), ("billing_period_start", ASCENDING)])
        print("  ✓ Created compound index on 'user_id' and 'billing_period_start'")
    except Exception as e:
        print(f"  - Compound index already exists or error: {e}")
    
    try:
        token_usage_collection.create_index("conversation_id")
        print("  ✓ Created index on 'conversation_id'")
    except Exception as e:
        print(f"  - Index 'conversation_id' already exists or error: {e}")
    
    try:
        token_usage_collection.create_index([("model_name", ASCENDING), ("timestamp", DESCENDING)])
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
        request_quotas_collection.create_index([("user_id", ASCENDING), ("period_start", ASCENDING)])
        print("  ✓ Created compound index on 'user_id' and 'period_start'")
    except Exception as e:
        print(f"  - Compound index already exists or error: {e}")
    
    try:
        request_quotas_collection.create_index("next_reset_date")
        print("  ✓ Created index on 'next_reset_date'")
    except Exception as e:
        print(f"  - Index 'next_reset_date' already exists or error: {e}")
    
    print("\n✅ MongoDB index initialization complete!")
    
    # List all indexes created
    print("\n📋 Summary of indexes:")
    print(f"  users: {list(users_collection.list_indexes())}")
    print(f"  subscription_history: {list(subscription_history_collection.list_indexes())}")
    print(f"  token_usage: {list(token_usage_collection.list_indexes())}")
    print(f"  request_quotas: {list(request_quotas_collection.list_indexes())}")
    
    client.close()


if __name__ == "__main__":
    create_indexes()
