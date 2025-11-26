#!/bin/bash

# إعادة بناء سريعة بعد إصلاح الأخطاء
# Quick rebuild after fixing errors

echo "=========================================="
echo "إعادة بناء Backend و Celery"
echo "Rebuilding Backend & Celery"
echo "=========================================="
echo ""

cd /root/DocsGPT/DocsGPT

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[1/5] سحب آخر التحديثات / Pulling latest updates...${NC}"
git pull origin main

echo -e "${GREEN}[2/5] إيقاف الخدمات القديمة / Stopping old services...${NC}"
docker compose down

echo -e "${GREEN}[3/5] إعادة بناء الحاويات / Rebuilding containers...${NC}"
docker compose build --no-cache backend celery-worker

echo -e "${GREEN}[4/5] بدء جميع الخدمات / Starting all services...${NC}"
docker compose up -d

echo -e "${YELLOW}انتظار 20 ثانية لبدء الخدمات...${NC}"
sleep 20

echo -e "${GREEN}[5/5] اختبار Backend API...${NC}"
echo ""
echo "محاولة 1:"
curl -s http://localhost:7091/api/subscription/plans | head -20

sleep 5
echo ""
echo "محاولة 2:"
curl -s http://localhost:7091/api/subscription/plans | head -20

echo ""
echo ""
echo "=========================================="
echo -e "${GREEN}✅ اكتمل! / Done!${NC}"
echo "=========================================="
echo ""
echo "حالة الخدمات / Services Status:"
docker compose ps
echo ""

echo "اختبار نهائي / Final Test:"
if curl -s http://localhost:7091/api/subscription/plans | grep -q "plans"; then
    echo -e "${GREEN}✓✓✓ Backend يعمل بنجاح! ✓✓✓${NC}"
    echo ""
    echo "افتح في المتصفح:"
    echo "  http://78.31.67.155"
    echo "  http://78.31.67.155/register"
    echo "  http://78.31.67.155/subscription"
else
    echo -e "${YELLOW}⚠ Backend قد يحتاج المزيد من الوقت${NC}"
    echo "عرض السجلات:"
    echo "  docker compose logs backend"
fi
echo ""
