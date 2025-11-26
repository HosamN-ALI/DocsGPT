#!/bin/bash

# إصلاح إعدادات Nginx
# Fix Nginx configuration

echo "إعداد Nginx..."

# إنشاء ملف إعداد Nginx
cat > /etc/nginx/sites-available/docsgpt << 'EOF'
server {
    listen 80;
    server_name 78.31.67.155 _;

    client_max_body_size 100M;

    # Frontend (React/Vite)
    location / {
        proxy_pass http://localhost:5173;
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
    location /api {
        proxy_pass http://localhost:7091;
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

    # Backend webhooks (Stripe)
    location /webhooks {
        proxy_pass http://localhost:7091;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# تفعيل الموقع
ln -sf /etc/nginx/sites-available/docsgpt /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# اختبار الإعدادات
echo "اختبار إعدادات Nginx..."
if nginx -t; then
    echo "✓ إعدادات Nginx صحيحة"
    systemctl reload nginx
    echo "✓ تم إعادة تحميل Nginx"
else
    echo "✗ خطأ في إعدادات Nginx"
    exit 1
fi

echo ""
echo "✅ تم إعداد Nginx بنجاح!"
