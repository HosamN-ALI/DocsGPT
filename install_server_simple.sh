#!/bin/bash

# DocsGPT Subscription System - Simple Installation Script
# This script installs and configures the DocsGPT subscription system on Ubuntu server

set -e  # Exit on error

echo "=========================================="
echo "  DocsGPT Subscription System Installer"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

echo -e "${GREEN}[1/10] Checking Docker installation...${NC}"
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    systemctl start docker
    rm get-docker.sh
else
    echo "Docker is already installed ($(docker --version))"
fi

echo -e "${GREEN}[2/10] Checking Docker Compose installation...${NC}"
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "Docker Compose not found. Installing..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    echo "Docker Compose is already installed"
fi

echo -e "${GREEN}[3/10] Checking Node.js installation...${NC}"
if ! command -v node &> /dev/null; then
    echo "Node.js not found. Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
else
    echo "Node.js is already installed ($(node --version))"
fi

echo -e "${GREEN}[4/10] Checking PM2 installation...${NC}"
if ! command -v pm2 &> /dev/null; then
    echo "Installing PM2..."
    npm install -g pm2
    pm2 startup systemd -u root --hp /root
else
    echo "PM2 is already installed"
fi

echo -e "${GREEN}[5/10] Checking Nginx installation...${NC}"
if ! command -v nginx &> /dev/null; then
    echo "Installing Nginx..."
    apt-get update
    apt-get install -y nginx
    systemctl enable nginx
else
    echo "Nginx is already installed"
fi

# Get the project directory
PROJECT_DIR=$(pwd)
echo -e "${GREEN}Working in directory: $PROJECT_DIR${NC}"

echo -e "${GREEN}[6/10] Creating environment files...${NC}"

# Create backend .env
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "Creating backend .env file..."
    cat > "$PROJECT_DIR/.env" << 'EOF'
# MongoDB Configuration
MONGO_URI=mongodb://mongodb:27017/docsgpt

# Redis Configuration
REDIS_URL=redis://redis:6379

# JWT Configuration
JWT_SECRET_KEY=your-super-secret-key-change-this-in-production-12345
JWT_ACCESS_TOKEN_EXPIRES=3600
JWT_REFRESH_TOKEN_EXPIRES=2592000

# Stripe Configuration (Test Mode)
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key_here
STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret_here

# Stripe Product & Price IDs
FREE_PRODUCT_ID=prod_free
FREE_PRICE_ID=price_free
PRO_PRODUCT_ID=prod_TSey5KafEFEsW9
PRO_PRICE_ID=price_1SVje7QZf6X1AyY5KoKCiHea
ENTERPRISE_PRODUCT_ID=prod_TSeyNNEx9WnH11
ENTERPRISE_PRICE_ID=price_1SVje8QZf6X1AyY5aQpJxo0A

# Model Configuration
COMPRESSION_MODEL_OVERRIDE=gpt-4o-mini
COMPRESSION_MAX_HISTORY_POINTS=3

# Flask Configuration
FLASK_APP=application.app:create_app
FLASK_ENV=production
EOF
    echo -e "${YELLOW}⚠️  Backend .env created. Please update Stripe keys!${NC}"
else
    echo "Backend .env file already exists"
fi

# Create frontend .env
if [ ! -f "$PROJECT_DIR/frontend/.env" ]; then
    echo "Creating frontend .env file..."
    cat > "$PROJECT_DIR/frontend/.env" << 'EOF'
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key_here
VITE_API_BASE_URL=http://78.31.67.155:7091
EOF
    echo -e "${YELLOW}⚠️  Frontend .env created. Please update Stripe publishable key!${NC}"
else
    echo "Frontend .env file already exists"
fi

echo -e "${GREEN}[7/10] Starting MongoDB and Redis with Docker Compose...${NC}"
cd "$PROJECT_DIR"
docker compose up -d mongodb redis

echo "Waiting for MongoDB to be ready..."
sleep 10

echo -e "${GREEN}[8/10] Initializing database indexes...${NC}"
if [ -f "$PROJECT_DIR/application/init_db_indexes.py" ]; then
    # Install Python dependencies temporarily for initialization
    pip3 install pymongo python-dotenv
    python3 "$PROJECT_DIR/application/init_db_indexes.py"
else
    echo -e "${YELLOW}⚠️  init_db_indexes.py not found. Skipping database initialization.${NC}"
fi

echo -e "${GREEN}[9/10] Installing and building frontend...${NC}"
cd "$PROJECT_DIR/frontend"
if [ ! -d "node_modules" ]; then
    npm install
fi
npm run build

# Stop PM2 frontend if running
pm2 delete frontend 2>/dev/null || true

# Start frontend with PM2
pm2 start npm --name "frontend" -- run dev
pm2 save

echo -e "${GREEN}[10/10] Configuring Nginx...${NC}"
# Create Nginx configuration
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
nginx -t
systemctl reload nginx

echo -e "${GREEN}[11/11] Starting backend services with Docker Compose...${NC}"
cd "$PROJECT_DIR"
docker compose up -d backend celery-worker

echo ""
echo "=========================================="
echo -e "${GREEN}✅ Installation Complete!${NC}"
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
echo "  3. Set up Stripe webhook: http://78.31.67.155/api/webhooks/stripe"
echo "  4. Change JWT_SECRET_KEY in .env to a secure random string"
echo "  5. For production, set up SSL with: certbot --nginx -d yourdomain.com"
echo ""
echo -e "${GREEN}Useful Commands:${NC}"
echo "  View backend logs: cd $PROJECT_DIR && docker compose logs -f backend"
echo "  View frontend logs: pm2 logs frontend"
echo "  Restart services: cd $PROJECT_DIR && docker compose restart"
echo "  Stop services: cd $PROJECT_DIR && docker compose stop"
echo ""
