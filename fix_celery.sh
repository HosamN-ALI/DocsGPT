#!/bin/bash

# إصلاح مشكلة Celery
# Fix Celery issue

echo "=========================================="
echo "إصلاح Celery / Fixing Celery"
echo "=========================================="
echo ""

cd /root/DocsGPT/DocsGPT

echo "[1/3] عرض سجلات Celery الأخيرة..."
docker compose logs --tail=50 celery-worker

echo ""
echo "[2/3] إعادة بناء Celery worker..."
docker compose build celery-worker

echo ""
echo "[3/3] إعادة تشغيل Celery..."
docker compose up -d celery-worker

echo ""
echo "انتظار 10 ثوانٍ..."
sleep 10

echo ""
echo "حالة Celery الآن:"
docker compose ps celery-worker

echo ""
echo "آخر 20 سطر من سجلات Celery:"
docker compose logs --tail=20 celery-worker

echo ""
echo "✅ تم!"
