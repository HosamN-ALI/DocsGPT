#!/bin/bash

# بدء جميع خدمات DocsGPT
# Start all DocsGPT services

echo "=========================================="
echo "بدء جميع خدمات DocsGPT"
echo "Starting all DocsGPT services"
echo "=========================================="
echo ""

PROJECT_DIR=$(pwd)
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# التحقق من وجود ملف .env
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo -e "${YELLOW}⚠ ملف .env غير موجود. إنشاؤه الآن...${NC}"
    bash create_env.sh
fi

echo -e "${GREEN}[1/6] بدء MongoDB و Redis...${NC}"
docker compose up -d mongodb redis
echo "انتظار 15 ثانية..."
sleep 15

echo -e "${GREEN}[2/6] التحقق من MongoDB...${NC}"
if docker compose ps mongodb | grep -q "Up"; then
    echo "✓ MongoDB يعمل"
else
    echo -e "${RED}✗ MongoDB لا يعمل${NC}"
fi

echo -e "${GREEN}[3/6] تهيئة قاعدة البيانات...${NC}"
if [ -f "init_db_standalone.py" ]; then
    export MONGO_URI="mongodb://localhost:27017/"
    export MONGO_DB_NAME="docsgpt"
    python3 init_db_standalone.py || echo "تحذير: قد تكون الفهارس موجودة"
fi

echo -e "${GREEN}[4/6] بدء Backend و Celery...${NC}"
docker compose up -d backend celery-worker
echo "انتظار 20 ثانية لبدء Backend..."
sleep 20

echo -e "${GREEN}[5/6] التحقق من Backend API...${NC}"
for i in {1..3}; do
    echo "محاولة $i:"
    if curl -s http://localhost:7091/api/subscription/plans | grep -q "plans"; then
        echo -e "${GREEN}✓ Backend API يعمل!${NC}"
        break
    else
        echo "Backend لم يستجب بعد، انتظار..."
        sleep 10
    fi
done

echo -e "${GREEN}[6/6] التحقق من Frontend...${NC}"
if pm2 list | grep -q "frontend.*online"; then
    echo "✓ Frontend يعمل"
else
    echo -e "${YELLOW}بدء Frontend...${NC}"
    cd frontend
    pm2 delete frontend 2>/dev/null || true
    pm2 start npm --name "frontend" -- run dev
    pm2 save
    cd ..
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✅ حالة النظام / System Status${NC}"
echo "=========================================="
echo ""
echo "Docker Services:"
docker compose ps
echo ""
echo "PM2 Processes:"
pm2 list
echo ""
echo "=========================================="
echo "اختبار سريع / Quick Test:"
echo "=========================================="
echo ""
echo "Backend API:"
curl -s http://localhost:7091/api/subscription/plans | head -20 || echo "Backend لا يستجيب"
echo ""
echo ""
echo "=========================================="
echo "الوصول للتطبيق / Access:"
echo "=========================================="
echo ""
echo "  الواجهة / Frontend: http://78.31.67.155"
echo "  API: http://78.31.67.155/api"
echo "  تسجيل / Register: http://78.31.67.155/register"
echo "  الاشتراكات / Plans: http://78.31.67.155/subscription"
echo ""
echo "=========================================="
echo "عرض السجلات / View Logs:"
echo "=========================================="
echo ""
echo "  Backend: docker compose logs -f backend"
echo "  Celery: docker compose logs -f celery-worker"
echo "  Frontend: pm2 logs frontend"
echo ""
