#!/bin/bash

echo "=========================================="
echo "🔧 Applying Final Fixes and Shutting Down"
echo "=========================================="
echo ""

cd /root/DocsGPT || { echo "❌ Error: /root/DocsGPT not found"; exit 1; }

# Pull latest fixes
echo "1️⃣ Pulling latest fixes from GitHub..."
git pull origin main
echo "✅ Latest code pulled"
echo ""

# Rebuild Celery with the fix
echo "2️⃣ Rebuilding Celery service with fix..."
docker compose build celery-worker --no-cache
echo "✅ Celery rebuilt"
echo ""

# Stop all services gracefully
echo "3️⃣ Stopping all services..."
echo ""

# Stop PM2
echo "   → Stopping PM2 processes..."
pm2 stop all 2>/dev/null || true
pm2 delete all 2>/dev/null || true
pm2 kill 2>/dev/null || true
echo "   ✅ PM2 stopped"

# Stop Docker Compose
echo "   → Stopping Docker Compose services..."
docker compose down
echo "   ✅ Docker services stopped"

# Stop Nginx
echo "   → Stopping Nginx..."
sudo systemctl stop nginx 2>/dev/null || sudo service nginx stop 2>/dev/null || true
echo "   ✅ Nginx stopped"

# Kill processes on application ports
echo "   → Cleaning up application ports..."
PORTS=(5173 5174 5175 5176 5177 7091 8000 3080)
for PORT in "${PORTS[@]}"; do
    PID=$(lsof -ti:$PORT 2>/dev/null)
    if [ -n "$PID" ]; then
        echo "     Killing port $PORT (PID: $PID)"
        kill -9 $PID 2>/dev/null || sudo kill -9 $PID 2>/dev/null || true
    fi
done
echo "   ✅ Ports cleaned"

# Kill any remaining Node/Vite processes
echo "   → Cleaning up Node.js processes..."
pkill -f "vite" 2>/dev/null || true
pkill -f "node.*frontend" 2>/dev/null || true
pkill -f "npm run dev" 2>/dev/null || true
echo "   ✅ Node processes cleaned"

echo ""
echo "=========================================="
echo "📊 Final Status"
echo "=========================================="
echo ""

echo "Docker Containers:"
docker ps 2>/dev/null | grep -E "(docsgpt|CONTAINER)" || echo "   ✅ No DocsGPT containers running"
echo ""

echo "PM2 Processes:"
pm2 list 2>/dev/null | grep -E "(frontend|online)" || echo "   ✅ No PM2 processes running"
echo ""

echo "Application Ports:"
netstat -tlnp 2>/dev/null | grep -E ":(5173|7091|8000)" || echo "   ✅ No application ports listening"
echo ""

echo "=========================================="
echo "✅ SHUTDOWN COMPLETE!"
echo "=========================================="
echo ""
echo "📝 Summary:"
echo "   • Celery fix applied (changed to application.celery_init.celery)"
echo "   • All Docker services stopped (backend, celery, mongo, redis)"
echo "   • PM2 frontend stopped"
echo "   • Nginx stopped"
echo "   • All application ports freed"
echo ""
echo "🔄 To restart later with working Celery:"
echo "   cd /root/DocsGPT"
echo "   bash START_ALL.sh"
echo ""
echo "📍 GitHub: https://github.com/HosamN-ALI/DocsGPT"
echo ""
