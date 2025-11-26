#!/bin/bash

# DocsGPT Complete Installation Script
# Run this on the server after connecting

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${YELLOW}ℹ️  $1${NC}"; }

echo "=================================================="
echo "🚀 DocsGPT Complete Installation"
echo "=================================================="

# Step 1: Remove old directory and clone fresh
print_info "Step 1: Setting up repository..."
cd /root
rm -rf docgpt
git clone https://github.com/HosamN-ALI/DocsGPT.git docgpt
cd docgpt
print_success "Repository cloned"

# Step 2: Create .env files
print_info "Step 2: Creating environment files..."

cat > /root/docgpt/.env << 'EOF'
MONGO_URI=mongodb://mongodb:27017/
MONGO_DB_NAME=docsgpt
AUTH_TYPE=session_jwt
JWT_SECRET_KEY=your-super-secret-key-change-this-in-production-12345
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key_here
STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret_here
FREE_PRODUCT_ID=prod_free
FREE_PRICE_ID=price_free
PRO_PRODUCT_ID=prod_TSey5KafEFEsW9
PRO_PRICE_ID=price_1SVje7QZf6X1AyY5KoKCiHea
ENTERPRISE_PRODUCT_ID=prod_TSeyNNEx9WnH11
ENTERPRISE_PRICE_ID=price_1SVje8QZf6X1AyY5aQpJxo0A
COMPRESSION_MODEL_OVERRIDE=gpt-4o-mini
COMPRESSION_PROMPT_VERSION=v1.0
COMPRESSION_MAX_HISTORY_POINTS=3
EOF

cat > /root/docgpt/frontend/.env << 'EOF'
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key_here
VITE_API_BASE_URL=http://78.31.67.155:7091
EOF

print_success "Environment files created"

# Step 3: Install Python dependencies
print_info "Step 3: Installing Python dependencies..."
cd /root/docgpt
pip3 install -r application/requirements.txt
print_success "Python dependencies installed"

# Step 4: Start MongoDB
print_info "Step 4: Starting MongoDB..."
docker compose up -d mongodb
print_info "Waiting 30 seconds for MongoDB to start..."
sleep 30
print_success "MongoDB started"

# Step 5: Initialize database
print_info "Step 5: Initializing database..."
python3 application/init_db_indexes.py
print_success "Database initialized"

# Step 6: Start all services
print_info "Step 6: Starting all Docker services..."
docker compose up -d
print_success "All services started"

# Step 7: Build frontend
print_info "Step 7: Building frontend..."
cd /root/docgpt/frontend
npm install
npm run build
print_success "Frontend built"

# Step 8: Install PM2
print_info "Step 8: Installing PM2..."
npm install -g pm2
print_success "PM2 installed"

# Step 9: Start frontend with PM2
print_info "Step 9: Starting frontend..."
pm2 delete frontend 2>/dev/null || true
pm2 start npm --name "frontend" -- run preview -- --host 0.0.0.0 --port 5173
pm2 save
pm2 startup systemd -u root --hp /root
print_success "Frontend started"

# Step 10: Install Nginx
print_info "Step 10: Installing Nginx..."
apt install -y nginx

cat > /etc/nginx/sites-available/docsgpt << 'EOFNGINX'
server {
    listen 80;
    server_name 78.31.67.155;

    location / {
        proxy_pass http://localhost:5173;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /api {
        proxy_pass http://localhost:7091;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOFNGINX

ln -sf /etc/nginx/sites-available/docsgpt /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
systemctl enable nginx
print_success "Nginx configured"

# Step 11: Setup systemd service
print_info "Step 11: Setting up systemd service..."
cat > /etc/systemd/system/docsgpt-backend.service << 'EOFSYSTEMD'
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
EOFSYSTEMD

systemctl enable docsgpt-backend
print_success "Systemd service configured"

# Step 12: Configure firewall
print_info "Step 12: Configuring firewall..."
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
print_success "Firewall configured"

# Final status
echo ""
echo "=================================================="
echo "🎉 Installation Complete!"
echo "=================================================="
echo ""

print_info "Checking services..."
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

echo "=================================================="
echo "📱 Access Information"
echo "=================================================="
echo ""
echo "Frontend: http://78.31.67.155"
echo "Backend:  http://78.31.67.155/api"
echo ""
echo "Direct URLs:"
echo "Frontend: http://78.31.67.155:5173"
echo "Backend:  http://78.31.67.155:7091"
echo ""

echo "=================================================="
echo "🧪 Test Commands"
echo "=================================================="
echo ""
echo "Test Backend:"
echo "curl http://localhost:7091/api/subscription/plans"
echo ""
echo "Test Registration:"
echo "curl -X POST http://localhost:7091/api/auth/register -H \"Content-Type: application/json\" -d '{\"email\":\"test@example.com\",\"password\":\"password123\",\"name\":\"Test User\"}'"
echo ""

echo "=================================================="
echo "⚠️  Important Next Steps"
echo "=================================================="
echo ""
echo "1. Get Stripe keys from .env.subscription.example"
echo "2. Update /root/docgpt/.env with real Stripe keys"
echo "3. Change JWT_SECRET_KEY in .env"
echo "4. Setup Stripe webhook at: http://78.31.67.155/api/webhooks/stripe"
echo "5. For production, setup SSL with: certbot --nginx -d yourdomain.com"
echo ""

print_success "Installation completed successfully!"
