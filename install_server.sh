#!/bin/bash

# DocsGPT Subscription System - Auto Installation Script
# Server: 78.31.67.155
# User: root
# Directory: /root/docgpt

set -e  # Exit on error

echo "=================================================="
echo "🚀 DocsGPT Subscription System Installation"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root"
    exit 1
fi

print_success "Running as root"

# Step 1: Update system
print_info "Step 1: Updating system..."
apt update && apt upgrade -y
apt install -y git curl wget vim nano software-properties-common
print_success "System updated"

# Step 2: Install Docker
print_info "Step 2: Installing Docker..."
if ! command -v docker &> /dev/null; then
    # Remove old versions
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker repository
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
    
    print_success "Docker installed: $(docker --version)"
else
    print_success "Docker already installed: $(docker --version)"
fi

# Step 3: Install Python
print_info "Step 3: Installing Python..."
apt install -y python3 python3-pip python3-venv
print_success "Python installed: $(python3 --version)"

# Step 4: Install Node.js
print_info "Step 4: Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt install -y nodejs
    print_success "Node.js installed: $(node --version)"
else
    print_success "Node.js already installed: $(node --version)"
fi

# Step 5: Clone repository
print_info "Step 5: Cloning repository..."
cd /root
if [ -d "docgpt" ]; then
    print_info "Directory exists, updating..."
    cd docgpt
    git pull origin main
else
    git clone https://github.com/HosamN-ALI/DocsGPT.git docgpt
    cd docgpt
fi
print_success "Repository ready"

# Step 6: Create .env files
print_info "Step 6: Creating environment files..."

# Backend .env
cat > /root/docgpt/.env << 'EOF'
# MongoDB Configuration
MONGO_URI=mongodb://mongodb:27017/
MONGO_DB_NAME=docsgpt

# Authentication
AUTH_TYPE=session_jwt
JWT_SECRET_KEY=your-super-secret-key-change-this-in-production-12345

# Stripe Configuration (Get keys from .env.subscription.example)
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key_here
STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret_here

# Stripe Product IDs
FREE_PRODUCT_ID=prod_free
FREE_PRICE_ID=price_free
PRO_PRODUCT_ID=prod_TSey5KafEFEsW9
PRO_PRICE_ID=price_1SVje7QZf6X1AyY5KoKCiHea
ENTERPRISE_PRODUCT_ID=prod_TSeyNNEx9WnH11
ENTERPRISE_PRICE_ID=price_1SVje8QZf6X1AyY5aQpJxo0A

# Application Settings
COMPRESSION_MODEL_OVERRIDE=gpt-4o-mini
COMPRESSION_PROMPT_VERSION=v1.0
COMPRESSION_MAX_HISTORY_POINTS=3
EOF

# Frontend .env
cat > /root/docgpt/frontend/.env << 'EOF'
# Stripe (Same as backend publishable key)
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key_here

# API Base URL
VITE_API_BASE_URL=http://78.31.67.155:7091
EOF

print_success "Environment files created"

# Step 7: Install Python dependencies
print_info "Step 7: Installing Python dependencies..."
cd /root/docgpt
pip3 install -r application/requirements.txt
print_success "Python dependencies installed"

# Step 8: Start MongoDB and initialize database
print_info "Step 8: Starting MongoDB and initializing database..."
cd /root/docgpt
docker compose up -d mongodb

# Wait for MongoDB to be ready
print_info "Waiting for MongoDB to start (30 seconds)..."
sleep 30

# Initialize database indexes
python3 application/init_db_indexes.py
print_success "Database initialized"

# Step 9: Start all services
print_info "Step 9: Starting all services..."
docker compose up -d
print_success "All Docker services started"

# Step 10: Install and build frontend
print_info "Step 10: Building frontend..."
cd /root/docgpt/frontend
npm install
npm run build
print_success "Frontend built"

# Step 11: Install Nginx
print_info "Step 11: Installing and configuring Nginx..."
apt install -y nginx

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
    }

    # Backend API
    location /api {
        proxy_pass http://localhost:7091;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/docsgpt /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and restart Nginx
nginx -t
systemctl restart nginx
systemctl enable nginx
print_success "Nginx configured"

# Step 12: Setup systemd service for auto-start
print_info "Step 12: Setting up systemd service..."
cat > /etc/systemd/system/docsgpt-backend.service << 'EOF'
[Unit]
Description=DocsGPT Backend Services
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/root/docgpt
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl enable docsgpt-backend
print_success "Systemd service configured"

# Step 13: Setup firewall
print_info "Step 13: Configuring firewall..."
apt install -y ufw
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
print_success "Firewall configured"

# Step 14: Start frontend
print_info "Step 14: Starting frontend..."
cd /root/docgpt/frontend

# Install PM2 for process management
npm install -g pm2

# Start frontend with PM2
pm2 delete frontend 2>/dev/null || true
pm2 start npm --name "frontend" -- run preview -- --host 0.0.0.0 --port 5173
pm2 save
pm2 startup systemd -u root --hp /root

print_success "Frontend started with PM2"

# Final checks
echo ""
echo "=================================================="
echo "🎉 Installation Complete!"
echo "=================================================="
echo ""

# Display service status
print_info "Checking services status..."
echo ""

echo "Docker Services:"
docker compose ps
echo ""

echo "PM2 Processes:"
pm2 list
echo ""

echo "Nginx Status:"
systemctl status nginx --no-pager | head -3
echo ""

# Display access URLs
echo "=================================================="
echo "📱 Access Information"
echo "=================================================="
echo ""
echo "Frontend URL: http://78.31.67.155"
echo "Backend API:  http://78.31.67.155/api"
echo ""
echo "Direct URLs (for testing):"
echo "Frontend:     http://78.31.67.155:5173"
echo "Backend:      http://78.31.67.155:7091"
echo ""

# Display test commands
echo "=================================================="
echo "🧪 Test Commands"
echo "=================================================="
echo ""
echo "Test Backend API:"
echo "curl http://localhost:7091/api/subscription/plans"
echo ""
echo "Test Registration:"
echo 'curl -X POST http://localhost:7091/api/auth/register -H "Content-Type: application/json" -d '"'"'{"email":"test@example.com","password":"password123","name":"Test User"}'"'"''
echo ""

# Display management commands
echo "=================================================="
echo "🔧 Management Commands"
echo "=================================================="
echo ""
echo "View logs:"
echo "  docker compose logs -f"
echo "  pm2 logs frontend"
echo ""
echo "Restart services:"
echo "  docker compose restart"
echo "  pm2 restart frontend"
echo ""
echo "Stop services:"
echo "  docker compose stop"
echo "  pm2 stop frontend"
echo ""

# Display important notes
echo "=================================================="
echo "⚠️  Important Notes"
echo "=================================================="
echo ""
echo "1. Change JWT_SECRET_KEY in /root/docgpt/.env"
echo "2. Use production Stripe keys for production"
echo "3. Setup SSL certificate for HTTPS"
echo "4. Configure Stripe webhook endpoint"
echo "5. Setup regular backups for MongoDB"
echo ""

print_success "Installation script completed successfully!"
echo ""
echo "🚀 Your DocsGPT Subscription System is now running!"
echo ""
