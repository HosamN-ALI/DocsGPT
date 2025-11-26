#!/bin/bash

# اختبار شامل لجميع الخدمات
# Comprehensive test of all services

echo "=========================================="
echo "اختبار شامل للخدمات"
echo "Comprehensive Services Test"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[1/8] اختبار MongoDB...${NC}"
if docker compose ps mongodb | grep -q "Up"; then
    echo -e "${GREEN}✓ MongoDB يعمل${NC}"
    docker exec -it docsgpt-mongo mongosh --eval "db.adminCommand('ping')" 2>/dev/null && echo "✓ MongoDB متصل" || echo "⚠ MongoDB غير متصل"
else
    echo -e "${RED}✗ MongoDB متوقف${NC}"
fi

echo ""
echo -e "${YELLOW}[2/8] اختبار Redis...${NC}"
if docker compose ps redis | grep -q "Up"; then
    echo -e "${GREEN}✓ Redis يعمل${NC}"
    docker exec -it docsgpt-redis redis-cli ping 2>/dev/null && echo "✓ Redis متصل" || echo "⚠ Redis غير متصل"
else
    echo -e "${RED}✗ Redis متوقف${NC}"
fi

echo ""
echo -e "${YELLOW}[3/8] اختبار Backend (Port 7091)...${NC}"
if docker compose ps backend | grep -q "Up"; then
    echo -e "${GREEN}✓ Backend Container يعمل${NC}"
    
    echo "اختبار API..."
    RESPONSE=$(curl -s http://localhost:7091/api/subscription/plans)
    if echo "$RESPONSE" | grep -q "plans"; then
        echo -e "${GREEN}✓ Backend API يستجيب${NC}"
        echo "$RESPONSE" | head -50
    else
        echo -e "${RED}✗ Backend API لا يستجيب${NC}"
        echo "الرد: $RESPONSE"
    fi
else
    echo -e "${RED}✗ Backend Container متوقف${NC}"
fi

echo ""
echo -e "${YELLOW}[4/8] اختبار Celery...${NC}"
if docker compose ps celery-worker | grep -q "Up"; then
    echo -e "${GREEN}✓ Celery Worker يعمل${NC}"
else
    echo -e "${RED}✗ Celery Worker متوقف أو يعيد التشغيل${NC}"
fi

echo ""
echo -e "${YELLOW}[5/8] اختبار Frontend (Port 5173)...${NC}"
if pm2 list | grep -q "frontend.*online"; then
    echo -e "${GREEN}✓ Frontend PM2 يعمل${NC}"
    
    echo "اختبار الوصول..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5173)
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ Frontend يستجيب (HTTP $HTTP_CODE)${NC}"
    else
        echo -e "${YELLOW}⚠ Frontend يستجيب بـ HTTP $HTTP_CODE${NC}"
    fi
else
    echo -e "${RED}✗ Frontend PM2 متوقف${NC}"
fi

echo ""
echo -e "${YELLOW}[6/8] اختبار Nginx...${NC}"
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx يعمل${NC}"
    
    echo "اختبار الوصول عبر Nginx..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/)
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ Nginx يستجيب (HTTP $HTTP_CODE)${NC}"
    else
        echo -e "${YELLOW}⚠ Nginx يستجيب بـ HTTP $HTTP_CODE${NC}"
    fi
    
    echo "اختبار توجيه API..."
    API_RESPONSE=$(curl -s http://localhost/api/subscription/plans)
    if echo "$API_RESPONSE" | grep -q "plans"; then
        echo -e "${GREEN}✓ Nginx يوجه API بشكل صحيح${NC}"
    else
        echo -e "${RED}✗ Nginx لا يوجه API${NC}"
        echo "الرد: $API_RESPONSE"
    fi
else
    echo -e "${RED}✗ Nginx متوقف${NC}"
fi

echo ""
echo -e "${YELLOW}[7/8] اختبار المنافذ المفتوحة...${NC}"
netstat -tlnp 2>/dev/null | grep -E ":(80|5173|7091|27017|6379)" || ss -tlnp | grep -E ":(80|5173|7091|27017|6379)"

echo ""
echo -e "${YELLOW}[8/8] اختبار من الخارج...${NC}"
echo "محاولة الوصول عبر IP العام..."
EXTERNAL_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://78.31.67.155/ --connect-timeout 5)
if [ "$EXTERNAL_RESPONSE" = "200" ]; then
    echo -e "${GREEN}✓ الموقع يعمل من الخارج (HTTP $EXTERNAL_RESPONSE)${NC}"
else
    echo -e "${RED}✗ الموقع لا يعمل من الخارج (HTTP $EXTERNAL_RESPONSE)${NC}"
fi

echo ""
echo "=========================================="
echo "ملخص النتائج / Summary"
echo "=========================================="
echo ""
docker compose ps
echo ""
pm2 list
echo ""
echo "للوصول للتطبيق:"
echo "  http://78.31.67.155"
echo ""
echo "إذا واجهت مشاكل:"
echo "  sudo tail -f /var/log/nginx/error.log"
echo "  docker compose logs backend"
echo "  pm2 logs frontend"
echo ""
