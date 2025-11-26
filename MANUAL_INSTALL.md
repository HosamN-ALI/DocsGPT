# دليل التثبيت اليدوي - DocsGPT Subscription System
## Manual Installation Guide

## المتطلبات الأساسية / Prerequisites

- Ubuntu 20.04+ or similar Linux distribution
- Root access
- 4GB+ RAM recommended
- 20GB+ disk space

---

## الطريقة 1: التثبيت التلقائي (الأسرع)
## Method 1: Automatic Installation (Fastest)

```bash
# 1. Clone the repository
cd /root
git clone https://github.com/HosamN-ALI/DocsGPT.git
cd DocsGPT

# 2. Make install script executable
chmod +x install_server_simple.sh

# 3. Run the installer
./install_server_simple.sh
```

**هذا كل شيء!** البرنامج سيثبت كل شيء تلقائياً.

**That's it!** The script will install everything automatically.

---

## الطريقة 2: التثبيت اليدوي (خطوة بخطوة)
## Method 2: Manual Installation (Step by Step)

### الخطوة 1: تثبيت Docker / Step 1: Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker
rm get-docker.sh

# Verify installation
docker --version
```

### الخطوة 2: تثبيت Docker Compose / Step 2: Install Docker Compose

```bash
# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verify installation
docker-compose --version
# OR
docker compose version
```

### الخطوة 3: تثبيت Node.js و PM2 / Step 3: Install Node.js & PM2

```bash
# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Verify Node.js
node --version
npm --version

# Install PM2 globally
npm install -g pm2

# Configure PM2 to start on boot
pm2 startup systemd -u root --hp /root
```

### الخطوة 4: تثبيت Nginx / Step 4: Install Nginx

```bash
# Install Nginx
apt-get update
apt-get install -y nginx

# Enable and start Nginx
systemctl enable nginx
systemctl start nginx

# Check status
systemctl status nginx
```

### الخطوة 5: استنساخ المشروع / Step 5: Clone Project

```bash
# Clone the repository
cd /root
git clone https://github.com/HosamN-ALI/DocsGPT.git
cd DocsGPT
```

### الخطوة 6: إعداد ملفات البيئة / Step 6: Setup Environment Files

#### Backend .env

```bash
cat > .env << 'EOF'
# MongoDB Configuration
MONGO_URI=mongodb://mongodb:27017/docsgpt

# Redis Configuration
REDIS_URL=redis://redis:6379

# JWT Configuration
JWT_SECRET_KEY=your-super-secret-key-change-this-in-production-12345
JWT_ACCESS_TOKEN_EXPIRES=3600
JWT_REFRESH_TOKEN_EXPIRES=2592000

# Stripe Configuration (Test Mode)
# ⚠️ REPLACE WITH YOUR REAL STRIPE KEYS
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
```

#### Frontend .env

```bash
cat > frontend/.env << 'EOF'
# ⚠️ REPLACE WITH YOUR REAL STRIPE PUBLISHABLE KEY
VITE_STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key_here
VITE_API_BASE_URL=http://78.31.67.155:7091
EOF
```

### الخطوة 7: تشغيل MongoDB و Redis / Step 7: Start MongoDB & Redis

```bash
# Start MongoDB and Redis only
docker compose up -d mongodb redis

# Wait for MongoDB to be ready
sleep 10

# Check if containers are running
docker compose ps
```

### الخطوة 8: تهيئة قاعدة البيانات / Step 8: Initialize Database

```bash
# Install required Python packages
pip3 install pymongo python-dotenv

# Run database initialization
python3 application/init_db_indexes.py
```

### الخطوة 9: بناء وتشغيل Frontend / Step 9: Build & Run Frontend

```bash
# Install frontend dependencies
cd /root/DocsGPT/frontend
npm install

# Build the frontend
npm run build

# Start frontend with PM2
pm2 start npm --name "frontend" -- run dev

# Save PM2 configuration
pm2 save

# Check PM2 status
pm2 list
```

### الخطوة 10: إعداد Nginx / Step 10: Configure Nginx

```bash
# Create Nginx configuration file
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

# Test Nginx configuration
nginx -t

# Reload Nginx
systemctl reload nginx
```

### الخطوة 11: تشغيل Backend Services / Step 11: Start Backend Services

```bash
# Go back to project directory
cd /root/DocsGPT

# Start all backend services (Backend API + Celery Worker)
docker compose up -d backend celery-worker

# Check if all containers are running
docker compose ps
```

### الخطوة 12: التحقق من التثبيت / Step 12: Verify Installation

```bash
# Check Docker containers
docker compose ps

# Check PM2 processes
pm2 list

# Check Nginx status
systemctl status nginx

# Test API endpoint
curl http://localhost:7091/api/subscription/plans

# Test frontend (should return HTML)
curl http://localhost:5173
```

---

## إدارة الخدمات / Service Management

### Docker Services

```bash
# View logs
docker compose logs -f backend
docker compose logs -f celery-worker

# Restart services
docker compose restart backend
docker compose restart celery-worker

# Stop services
docker compose stop

# Start services
docker compose up -d

# Remove all containers
docker compose down
```

### PM2 (Frontend)

```bash
# View logs
pm2 logs frontend

# Restart frontend
pm2 restart frontend

# Stop frontend
pm2 stop frontend

# Start frontend
pm2 start frontend

# Remove from PM2
pm2 delete frontend
```

### Nginx

```bash
# Test configuration
nginx -t

# Reload Nginx
systemctl reload nginx

# Restart Nginx
systemctl restart nginx

# Stop Nginx
systemctl stop nginx

# View Nginx logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

---

## الوصول إلى التطبيق / Accessing the Application

- **Frontend**: http://78.31.67.155
- **API**: http://78.31.67.155/api

### اختبار التسجيل / Test Registration

```bash
curl -X POST http://78.31.67.155/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#",
    "name": "Test User"
  }'
```

### اختبار تسجيل الدخول / Test Login

```bash
curl -X POST http://78.31.67.155/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!@#"
  }'
```

---

## إعداد Stripe Webhook

1. Go to Stripe Dashboard: https://dashboard.stripe.com/test/webhooks
2. Click "Add endpoint"
3. Enter URL: `http://78.31.67.155/api/webhooks/stripe`
4. Select events:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
5. Copy the webhook secret
6. Update `STRIPE_WEBHOOK_SECRET` in `.env`
7. Restart backend: `docker compose restart backend`

---

## الأمان للإنتاج / Production Security

### 1. تغيير JWT Secret

```bash
# Generate a secure random string
openssl rand -hex 32

# Update JWT_SECRET_KEY in .env with the generated string
```

### 2. استخدام Stripe Keys الحقيقية

```bash
# Replace test keys with production keys in .env and frontend/.env
# STRIPE_SECRET_KEY=sk_live_...
# STRIPE_PUBLISHABLE_KEY=pk_live_...
# VITE_STRIPE_PUBLISHABLE_KEY=pk_live_...
```

### 3. إعداد SSL/HTTPS

```bash
# Install Certbot
apt-get install -y certbot python3-certbot-nginx

# Get SSL certificate (replace yourdomain.com)
certbot --nginx -d yourdomain.com

# Auto-renewal is configured automatically
```

### 4. إعداد Firewall

```bash
# Allow SSH, HTTP, HTTPS
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp

# Enable firewall
ufw enable

# Check status
ufw status
```

---

## استكشاف الأخطاء / Troubleshooting

### المشكلة: Backend لا يعمل

```bash
# Check backend logs
docker compose logs -f backend

# Check if MongoDB is running
docker compose ps mongodb

# Restart backend
docker compose restart backend
```

### المشكلة: Frontend لا يعمل

```bash
# Check PM2 logs
pm2 logs frontend

# Restart frontend
pm2 restart frontend

# Check if port 5173 is in use
lsof -i :5173
```

### المشكلة: خطأ في الاتصال بقاعدة البيانات

```bash
# Check MongoDB logs
docker compose logs -f mongodb

# Check MongoDB connection
docker exec -it docsgpt-mongo mongosh

# Inside MongoDB shell
use docsgpt
db.users.find()
exit
```

### المشكلة: Nginx error

```bash
# Check Nginx error log
tail -f /var/log/nginx/error.log

# Test configuration
nginx -t

# Restart Nginx
systemctl restart nginx
```

---

## النسخ الاحتياطي / Backup

### نسخ قاعدة البيانات / Backup Database

```bash
# Create backup directory
mkdir -p /root/backups

# Backup MongoDB
docker exec docsgpt-mongo mongodump --out=/data/backup
docker cp docsgpt-mongo:/data/backup /root/backups/mongodb-$(date +%Y%m%d)
```

### استعادة قاعدة البيانات / Restore Database

```bash
# Restore MongoDB
docker cp /root/backups/mongodb-YYYYMMDD docsgpt-mongo:/data/restore
docker exec docsgpt-mongo mongorestore /data/restore
```

---

## الدعم / Support

- GitHub: https://github.com/HosamN-ALI/DocsGPT
- Documentation: `/root/DocsGPT/SUBSCRIPTION_SYSTEM_COMPLETE.md`
- Quick Start: `/root/DocsGPT/QUICK_START_GUIDE.md`

---

## إحصائيات المشروع / Project Statistics

- **Total Files**: 47 files (25 backend + 19 frontend + 3 docs)
- **API Endpoints**: 13 new endpoints
- **Code Lines**: ~7,500+ lines
- **Docker Services**: 4 services (MongoDB, Redis, Backend, Celery)
- **Subscription Plans**: Free, Pro ($15/mo), Enterprise ($30/mo)
