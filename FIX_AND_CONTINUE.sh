#!/bin/bash

# Quick fix script to continue installation after the error
# Run this on your server: bash FIX_AND_CONTINUE.sh

set -e

echo "=========================================="
echo "  DocsGPT - Fix and Continue Installation"
echo "=========================================="
echo ""

# Get current directory
PROJECT_DIR=$(pwd)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}[1/6] Installing Python dependencies (without warnings)...${NC}"
pip3 install --quiet pymongo python-dotenv 2>/dev/null || pip3 install pymongo python-dotenv

echo -e "${GREEN}[2/6] Initializing MongoDB indexes with standalone script...${NC}"
export MONGO_URI="mongodb://localhost:27017/"
export MONGO_DB_NAME="docsgpt"

# Create standalone init script if not exists
if [ ! -f "init_db_standalone.py" ]; then
    echo "Downloading standalone init script..."
    curl -s https://raw.githubusercontent.com/HosamN-ALI/DocsGPT/main/init_db_standalone.py -o init_db_standalone.py
fi

python3 init_db_standalone.py

echo -e "${GREEN}[3/6] Installing and building frontend...${NC}"
cd "$PROJECT_DIR/frontend"
if [ ! -d "node_modules" ]; then
    echo "Installing frontend dependencies (this may take a few minutes)..."
    npm install --quiet
fi

echo "Building frontend..."
npm run build

echo -e "${GREEN}[4/6] Starting frontend with PM2...${NC}"
pm2 delete frontend 2>/dev/null || true
pm2 start npm --name "frontend" -- run dev
pm2 save

echo -e "${GREEN}[5/6] Configuring Nginx...${NC}"
cd "$PROJECT_DIR"

# Create Nginx config if not exists
if [ ! -f "/etc/nginx/sites-available/docsgpt" ]; then
    cat > /etc/nginx/sites-available/docsgpt << 'EOF'
server {
    listen 80;
    server_name 78.31.67.155;

    # Frontend
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
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:7091/api;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
EOF

    # Enable the site
    ln -sf /etc/nginx/sites-available/docsgpt /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and reload Nginx
    nginx -t && systemctl reload nginx
    echo "✓ Nginx configured and reloaded"
else
    echo "✓ Nginx already configured"
fi

echo -e "${GREEN}[6/6] Starting backend services with Docker Compose...${NC}"
docker compose up -d backend celery-worker

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Installation Fixed and Complete!${NC}"
echo "=========================================="
echo ""
echo "Services Status:"
docker compose ps
echo ""
pm2 list
echo ""
echo -e "${GREEN}Access the application:${NC}"
echo "  Frontend: http://78.31.67.155"
echo "  API: http://78.31.67.155/api"
echo ""
echo -e "${YELLOW}Important Next Steps:${NC}"
echo "  1. Update Stripe keys in: $PROJECT_DIR/.env"
echo "  2. Update Stripe publishable key in: $PROJECT_DIR/frontend/.env"
echo "  3. Restart services: docker compose restart backend && pm2 restart frontend"
echo "  4. Test API: curl http://localhost:7091/api/subscription/plans"
echo ""
