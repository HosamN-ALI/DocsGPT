#!/bin/bash

# إنشاء ملفات .env المطلوبة
# Create required .env files

echo "=========================================="
echo "إنشاء ملفات البيئة / Creating .env files"
echo "=========================================="
echo ""

PROJECT_DIR=$(pwd)
echo "المجلد الحالي: $PROJECT_DIR"

# إنشاء ملف .env للـ Backend
echo "إنشاء .env للـ Backend..."
cat > "$PROJECT_DIR/.env" << 'EOF'
# MongoDB Configuration
MONGO_URI=mongodb://mongodb:27017/docsgpt

# Redis Configuration
REDIS_URL=redis://redis:6379

# JWT Configuration
JWT_SECRET_KEY=your-super-secret-jwt-key-change-this-in-production-12345
JWT_ACCESS_TOKEN_EXPIRES=3600
JWT_REFRESH_TOKEN_EXPIRES=2592000

# Stripe Configuration (Test Mode)
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key_here
STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret_here

# Stripe Product & Price IDs
FREE_PRODUCT_ID=prod_free
FREE_PRICE_ID=price_free
PRO_PRODUCT_ID=prod_TSey5KafEFEsW9
PRO_PRICE_ID=price_1SVje7QZf6X1AyY5KoKCiHea
ENTERPRISE_PRODUCT_ID=prod_TSeyNNEx9WnH11
ENTERPRISE_PRICE_ID=price_1SVje8QZf6X1AyY5aQpJxo0A

# Model Configuration
COMPRESSION_MODEL_OVERRIDE=gpt-4o-mini
COMPRESSION_MAX_HISTORY_POINTS=3

# Flask Configuration
FLASK_APP=application.app:app
FLASK_ENV=production
PORT=7091

# Celery Configuration
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0
EOF

echo "✓ تم إنشاء $PROJECT_DIR/.env"

# إنشاء ملف .env للـ Frontend
echo ""
echo "إنشاء .env للـ Frontend..."
cat > "$PROJECT_DIR/frontend/.env" << 'EOF'
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key_here
VITE_API_BASE_URL=http://78.31.67.155:7091
EOF

echo "✓ تم إنشاء $PROJECT_DIR/frontend/.env"

echo ""
echo "=========================================="
echo "✅ اكتمل!"
echo "=========================================="
echo ""
echo "الخطوات التالية:"
echo "1. حدّث مفاتيح Stripe في:"
echo "   nano $PROJECT_DIR/.env"
echo "   nano $PROJECT_DIR/frontend/.env"
echo ""
echo "2. أعد تشغيل الخدمات:"
echo "   docker compose up -d"
echo ""
