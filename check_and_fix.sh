#!/bin/bash

# فحص وإصلاح المشاكل المتبقية
# Check and fix remaining issues

echo "=========================================="
echo "فحص المشاكل / Checking Issues"
echo "=========================================="
echo ""

cd /root/DocsGPT/DocsGPT

echo "[1/5] فحص سجلات Backend..."
echo "Backend logs (last 20 lines):"
docker compose logs --tail=20 backend
echo ""

echo "[2/5] فحص سجلات Celery..."
echo "Celery logs (last 20 lines):"
docker compose logs --tail=20 celery-worker
echo ""

echo "[3/5] اختبار اتصال Backend..."
sleep 5
if curl -s http://localhost:7091/api/subscription/plans | grep -q "plans"; then
    echo "✓ Backend يعمل بنجاح!"
else
    echo "✗ Backend لا يستجيب. إعادة المحاولة..."
    docker compose restart backend
    sleep 10
    if curl -s http://localhost:7091/api/subscription/plans | grep -q "plans"; then
        echo "✓ Backend يعمل الآن!"
    else
        echo "✗ Backend ما زال لا يعمل. اعرض السجلات:"
        docker compose logs --tail=50 backend
    fi
fi
echo ""

echo "[4/5] فحص Frontend..."
if pm2 list | grep -q "online"; then
    echo "✓ Frontend يعمل"
else
    echo "✗ Frontend متوقف. إعادة التشغيل..."
    pm2 restart frontend
fi
echo ""

echo "[5/5] فحص Nginx..."
if systemctl is-active --quiet nginx; then
    echo "✓ Nginx يعمل"
    nginx -t 2>&1 | grep -q "successful" && echo "✓ إعدادات Nginx صحيحة" || echo "⚠ تحقق من إعدادات Nginx"
else
    echo "✗ Nginx متوقف"
    systemctl start nginx
fi
echo ""

echo "=========================================="
echo "الحالة النهائية / Final Status"
echo "=========================================="
docker compose ps
echo ""
pm2 list
echo ""

echo "=========================================="
echo "اختبارات سريعة / Quick Tests"
echo "=========================================="

echo ""
echo "1. اختبار API المباشر (localhost:7091):"
curl -s http://localhost:7091/api/subscription/plans | head -20
echo ""

echo ""
echo "2. اختبار API عبر Nginx (localhost:80):"
curl -s http://localhost/api/subscription/plans | head -20
echo ""

echo ""
echo "3. اختبار Frontend:"
curl -s -I http://localhost:5173 | head -5
echo ""

echo "=========================================="
echo "الخطوات التالية / Next Steps"
echo "=========================================="
echo ""
echo "إذا رأيت أخطاء، قم بما يلي:"
echo ""
echo "1. عرض سجلات Backend بالتفصيل:"
echo "   docker compose logs -f backend"
echo ""
echo "2. عرض سجلات Celery:"
echo "   docker compose logs -f celery-worker"
echo ""
echo "3. إعادة تشغيل الخدمات:"
echo "   docker compose restart backend celery-worker"
echo "   pm2 restart frontend"
echo ""
echo "4. افتح في المتصفح:"
echo "   http://78.31.67.155"
echo ""
