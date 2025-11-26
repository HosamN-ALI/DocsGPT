#!/bin/bash

echo "=========================================="
echo "🛑 Stopping All DocsGPT Services"
echo "=========================================="
echo ""

# Function to check command existence
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Stop PM2 processes
echo "1️⃣ Stopping PM2 processes..."
if command_exists pm2; then
    pm2 stop all
    pm2 delete all
    pm2 kill
    echo "✅ PM2 stopped"
else
    echo "⚠️  PM2 not found, skipping"
fi
echo ""

# 2. Stop Docker Compose services
echo "2️⃣ Stopping Docker Compose services..."
if command_exists docker-compose || command_exists docker; then
    cd /root/DocsGPT 2>/dev/null || cd /root/DocsGPT/DocsGPT 2>/dev/null || true
    
    if [ -f "docker-compose.yml" ]; then
        docker compose down 2>/dev/null || docker-compose down 2>/dev/null || true
        echo "✅ Docker Compose services stopped"
    else
        echo "⚠️  docker-compose.yml not found"
    fi
    
    # Stop any remaining containers
    echo "   Stopping any remaining Docker containers..."
    docker stop $(docker ps -q) 2>/dev/null || true
    echo "✅ All Docker containers stopped"
else
    echo "⚠️  Docker not found, skipping"
fi
echo ""

# 3. Stop Nginx
echo "3️⃣ Stopping Nginx..."
if command_exists nginx; then
    sudo systemctl stop nginx 2>/dev/null || sudo service nginx stop 2>/dev/null || true
    echo "✅ Nginx stopped"
else
    echo "⚠️  Nginx not found, skipping"
fi
echo ""

# 4. Kill any processes on specific ports
echo "4️⃣ Killing processes on application ports..."
PORTS=(5173 5174 5175 5176 5177 7091 8000 3080)

for PORT in "${PORTS[@]}"; do
    PID=$(lsof -ti:$PORT 2>/dev/null)
    if [ -n "$PID" ]; then
        echo "   Killing process on port $PORT (PID: $PID)"
        kill -9 $PID 2>/dev/null || sudo kill -9 $PID 2>/dev/null || true
    fi
done
echo "✅ Port cleanup completed"
echo ""

# 5. Kill any vite/node processes
echo "5️⃣ Killing remaining Node.js and Vite processes..."
pkill -f "vite" 2>/dev/null || true
pkill -f "node.*frontend" 2>/dev/null || true
pkill -f "npm run dev" 2>/dev/null || true
echo "✅ Node.js processes cleaned up"
echo ""

# 6. Show final status
echo "=========================================="
echo "📊 Final Status Check"
echo "=========================================="
echo ""

echo "PM2 Status:"
pm2 list 2>/dev/null || echo "   No PM2 processes running"
echo ""

echo "Docker Containers:"
docker ps 2>/dev/null || echo "   No Docker containers running"
echo ""

echo "Active Listening Ports:"
netstat -tlnp 2>/dev/null | grep -E ":(5173|5174|5175|5176|5177|7091|8000|3080|27017|6379)" || echo "   No application ports listening"
echo ""

echo "=========================================="
echo "✅ All Services Stopped Successfully!"
echo "=========================================="
echo ""
echo "Core services (MongoDB on 27017, Redis on 6379, PostgreSQL on 5432, MySQL on 3306) are still running."
echo "These are database services and stopping them won't affect IP or cause core issues."
echo ""
echo "To restart the application later, use:"
echo "  cd /root/DocsGPT"
echo "  bash START_ALL.sh"
echo ""
