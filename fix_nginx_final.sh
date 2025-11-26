#!/bin/bash

# إصلاح نهائي لـ Nginx والواجهة الأمامية
# Final fix for Nginx and Frontend

echo "=========================================="
echo "إصلاح Nginx والواجهة الأمامية"
echo "Fixing Nginx and Frontend"
echo "=========================================="
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[1/5] التحقق من Frontend...${NC}"
if pm2 list | grep -q "frontend.*online"; then
    echo "✓ Frontend يعمل على PM2"
    echo "Frontend URL: http://localhost:5173"
else
    echo -e "${RED}✗ Frontend متوقف${NC}"
    echo "بدء Frontend..."
    cd /root/DocsGPT/frontend
    pm2 delete frontend 2>/dev/null || true
    pm2 start npm --name "frontend" -- run dev
    pm2 save
    cd /root/DocsGPT
fi

echo ""
echo -e "${GREEN}[2/5] اختبار Frontend مباشرة...${NC}"
sleep 3
curl -I http://localhost:5173 2>&1 | head -10

echo ""
echo -e "${GREEN}[3/5] إعداد Nginx...${NC}"

# حذف الإعداد القديم
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/docsgpt

# إنشاء إعداد جديد
cat > /etc/nginx/sites-available/docsgpt << 'NGINXCONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name 78.31.67.155 _;

    client_max_body_size 100M;

    # Root location - Frontend
    location / {
        proxy_pass http://127.0.0.1:5173;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # Backend API
    location /api/ {
        proxy_pass http://127.0.0.1:7091/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Increase timeouts for API
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        proxy_send_timeout 300s;
    }

    # Webhooks
    location /webhooks/ {
        proxy_pass http://127.0.0.1:7091/webhooks/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINXCONF

echo "✓ تم إنشاء ملف إعداد Nginx"

# تفعيل الموقع
ln -sf /etc/nginx/sites-available/docsgpt /etc/nginx/sites-enabled/docsgpt

echo ""
echo -e "${GREEN}[4/5] اختبار إعدادات Nginx...${NC}"
if nginx -t 2>&1; then
    echo "✓ إعدادات Nginx صحيحة"
else
    echo -e "${RED}✗ خطأ في إعدادات Nginx${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}[5/5] إعادة تحميل Nginx...${NC}"
systemctl reload nginx
systemctl status nginx --no-pager | head -10

echo ""
echo "=========================================="
echo -e "${GREEN}✅ اكتمل!${NC}"
echo "=========================================="
echo ""
echo "اختبارات:"
echo ""
echo "1. Frontend المباشر (localhost:5173):"
curl -s -I http://localhost:5173 2>&1 | grep -E "HTTP|Content-Type" || echo "لا يستجيب"

echo ""
echo "2. عبر Nginx (localhost:80):"
curl -s -I http://localhost:80 2>&1 | grep -E "HTTP|Content-Type" || echo "لا يستجيب"

echo ""
echo "3. Backend API:"
curl -s http://localhost/api/subscription/plans 2>&1 | head -20

echo ""
echo ""
echo "=========================================="
echo "افتح في المتصفح:"
echo "=========================================="
echo ""
echo "  http://78.31.67.155"
echo ""
echo "إذا لم يعمل، عرض السجلات:"
echo "  sudo tail -f /var/log/nginx/error.log"
echo "  pm2 logs frontend"
echo ""
