#!/bin/bash

# إصلاح عاجل لمشاكل التثبيت
# Urgent fix for installation issues

set -e

echo "=========================================="
echo "  إصلاح عاجل - DocsGPT"
echo "  Urgent Fix - DocsGPT"
echo "=========================================="
echo ""

PROJECT_DIR="/root/DocsGPT/DocsGPT"
cd "$PROJECT_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}[1/7] إيقاف جميع الخدمات / Stopping all services...${NC}"
pm2 delete frontend 2>/dev/null || true
pm2 delete all 2>/dev/null || true
docker compose down 2>/dev/null || true

echo -e "${GREEN}[2/7] التأكد من ملفات البيئة / Checking environment files...${NC}"

# تحديث ملف .env للـ Backend
cat > "$PROJECT_DIR/.env" << 'EOF'
# MongoDB Configuration
MONGO_URI=mongodb://mongodb:27017/docsgpt

# Redis Configuration  
REDIS_URL=redis://redis:6379

# JWT Configuration
JWT_SECRET_KEY=your-super-secret-jwt-key-change-this-in-production-please-12345
JWT_ACCESS_TOKEN_EXPIRES=3600
JWT_REFRESH_TOKEN_EXPIRES=2592000

# Stripe Configuration (Test Mode)
STRIPE_SECRET_KEY=sk_test_51QZ0example_your_stripe_secret_key_here
STRIPE_PUBLISHABLE_KEY=pk_test_51QZ0example_your_stripe_publishable_key_here
STRIPE_WEBHOOK_SECRET=whsec_example_your_webhook_secret_here

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
FLASK_APP=application.app:create_app
FLASK_ENV=production
PORT=7091
EOF

echo "✓ ملف .env للـ Backend محدث"

# تحديث ملف .env للـ Frontend
cat > "$PROJECT_DIR/frontend/.env" << 'EOF'
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_51QZ0example_your_stripe_publishable_key_here
VITE_API_BASE_URL=http://78.31.67.155:7091
EOF

echo "✓ ملف .env للـ Frontend محدث"

echo -e "${GREEN}[3/7] بدء MongoDB و Redis / Starting MongoDB and Redis...${NC}"
docker compose up -d mongodb redis
echo "انتظار 15 ثانية لـ MongoDB..."
sleep 15

echo -e "${GREEN}[4/7] تهيئة قاعدة البيانات / Initializing database...${NC}"
export MONGO_URI="mongodb://localhost:27017/"
export MONGO_DB_NAME="docsgpt"
python3 "$PROJECT_DIR/init_db_standalone.py" || echo "تحذير: قد تكون الفهارس موجودة بالفعل"

echo -e "${GREEN}[5/7] بناء الـ Backend / Building backend...${NC}"
# تثبيت المتطلبات في حاوية Docker
docker compose build backend celery-worker

echo -e "${GREEN}[6/7] بدء الـ Backend و Celery / Starting backend and Celery...${NC}"
docker compose up -d backend celery-worker

echo "انتظار 10 ثوانٍ لبدء الـ Backend..."
sleep 10

# اختبار الـ Backend
echo "اختبار الـ Backend API..."
if curl -f http://localhost:7091/api/subscription/plans 2>/dev/null; then
    echo -e "${GREEN}✓ Backend يعمل بنجاح!${NC}"
else
    echo -e "${YELLOW}⚠ Backend قد لا يعمل بشكل صحيح. تحقق من السجلات.${NC}"
fi

echo -e "${GREEN}[7/7] بناء وبدء الـ Frontend / Building and starting frontend...${NC}"
cd "$PROJECT_DIR/frontend"

# حذف node_modules و package-lock.json للتأكد من تثبيت نظيف
rm -rf node_modules package-lock.json

# تثبيت المكتبات
echo "تثبيت مكتبات Frontend..."
npm install --legacy-peer-deps

# بناء المشروع
echo "بناء Frontend..."
npm run build

# بدء Frontend مع PM2
pm2 delete frontend 2>/dev/null || true
pm2 start npm --name "frontend" -- run dev
pm2 save

cd "$PROJECT_DIR"

echo ""
echo "=========================================="
echo -e "${GREEN}✅ تم الإصلاح! / Fixed!${NC}"
echo "=========================================="
echo ""
echo "حالة الخدمات / Services Status:"
echo ""
docker compose ps
echo ""
pm2 list
echo ""
echo -e "${GREEN}الوصول للتطبيق / Access Application:${NC}"
echo "  الواجهة / Frontend: http://78.31.67.155"
echo "  الـ API / Backend: http://78.31.67.155/api"
echo ""
echo -e "${YELLOW}خطوات مهمة / Important Steps:${NC}"
echo "  1. تحديث مفاتيح Stripe في / Update Stripe keys in:"
echo "     $PROJECT_DIR/.env"
echo "     $PROJECT_DIR/frontend/.env"
echo ""
echo "  2. إعادة تشغيل الخدمات / Restart services:"
echo "     docker compose restart backend"
echo "     pm2 restart frontend"
echo ""
echo "  3. اختبار API / Test API:"
echo "     curl http://localhost:7091/api/subscription/plans"
echo ""
echo -e "${GREEN}عرض السجلات / View Logs:${NC}"
echo "  Backend: docker compose logs -f backend"
echo "  Frontend: pm2 logs frontend"
echo ""
