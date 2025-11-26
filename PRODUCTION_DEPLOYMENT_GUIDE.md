# 🚀 DocsGPT Subscription System - Production Deployment Guide

## Server Information
- **IP Address**: 78.31.67.155
- **SSH User**: root
- **SSH Keys**: Provided
- **Current Location**: `/root/docgpt`

---

## 📋 Pre-Deployment Checklist

### 1. Server Requirements
- [ ] Ubuntu/Debian Linux (recommended) or compatible OS
- [ ] Docker and Docker Compose installed
- [ ] MongoDB 5.0+ (via Docker)
- [ ] Redis (via Docker)
- [ ] Python 3.9+
- [ ] Node.js 22+
- [ ] Nginx (for reverse proxy)
- [ ] SSL Certificate (Let's Encrypt recommended)
- [ ] Domain name configured (optional but recommended)

### 2. Required Accounts
- [ ] Stripe account (production keys)
- [ ] MongoDB connection (if using Atlas)
- [ ] Email service (SendGrid/AWS SES for future notifications)

---

## 🔧 Step-by-Step Deployment

### Step 1: Connect to Server

```bash
# Set proper permissions for SSH key
chmod 600 /home/user/uploaded_files/root

# Connect to server
ssh -i /home/user/uploaded_files/root root@78.31.67.155
```

### Step 2: Update System and Install Dependencies

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y git curl wget nano vim

# Install Docker (if not installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose (if not installed)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installations
docker --version
docker-compose --version
```

### Step 3: Clone/Update Repository

```bash
# Navigate to deployment directory
cd /root/docgpt

# If directory doesn't exist, clone the repository
# git clone https://github.com/HosamN-ALI/DocsGPT.git .

# If already cloned, pull latest changes
git pull origin main

# Verify you have the subscription system
git log --oneline -4
# Should show:
# - feat: implement complete frontend subscription system
# - feat: implement complete backend subscription system
```

### Step 4: Configure Production Environment Variables

```bash
# Create production .env file
cd /root/docgpt
nano .env
```

**Production `.env` Configuration:**

```env
# ============================================
# PRODUCTION ENVIRONMENT CONFIGURATION
# ============================================

# --------------------------------------
# Database Configuration
# --------------------------------------
MONGO_URI=mongodb://mongodb:27017/
MONGO_DB_NAME=docsgpt_production

# For MongoDB Atlas (recommended for production):
# MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/docsgpt_production?retryWrites=true&w=majority

# --------------------------------------
# Authentication
# --------------------------------------
AUTH_TYPE=session_jwt

# IMPORTANT: Generate a strong JWT secret key
# Generate with: openssl rand -hex 32
JWT_SECRET_KEY=REPLACE_WITH_STRONG_RANDOM_KEY_32_CHARS_MIN

# --------------------------------------
# Stripe Configuration (PRODUCTION KEYS)
# --------------------------------------
# Get these from: https://dashboard.stripe.com/apikeys
STRIPE_SECRET_KEY=sk_live_YOUR_PRODUCTION_SECRET_KEY
STRIPE_PUBLISHABLE_KEY=pk_live_YOUR_PRODUCTION_PUBLISHABLE_KEY

# Get from: https://dashboard.stripe.com/webhooks
STRIPE_WEBHOOK_SECRET=whsec_YOUR_WEBHOOK_SECRET

# --------------------------------------
# Stripe Product Configuration (Production)
# --------------------------------------
# Free Plan (No payment required)
FREE_PRODUCT_ID=prod_free
FREE_PRICE_ID=price_free

# Pro Plan - $15/month
# Create in Stripe Dashboard and paste IDs here
PRO_PRODUCT_ID=prod_YOUR_PRO_PRODUCT_ID
PRO_PRICE_ID=price_YOUR_PRO_PRICE_ID

# Enterprise Plan - $30/month
# Create in Stripe Dashboard and paste IDs here
ENTERPRISE_PRODUCT_ID=prod_YOUR_ENTERPRISE_PRODUCT_ID
ENTERPRISE_PRICE_ID=price_YOUR_ENTERPRISE_PRICE_ID

# --------------------------------------
# Application Configuration
# --------------------------------------
API_KEY=YOUR_MAIN_API_KEY
FLASK_ENV=production
DEBUG=False

# OpenAI Configuration (if using OpenAI models)
OPENAI_API_KEY=sk-YOUR_OPENAI_API_KEY

# Other LLM providers (configure as needed)
# ANTHROPIC_API_KEY=
# COHERE_API_KEY=
# HUGGINGFACE_API_KEY=

# --------------------------------------
# Celery Configuration
# --------------------------------------
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0

# --------------------------------------
# Upload Configuration
# --------------------------------------
UPLOAD_FOLDER=/app/uploads

# --------------------------------------
# CORS Configuration
# --------------------------------------
# Update with your actual domain
CORS_ORIGINS=https://yourdomain.com,https://www.yourdomain.com

# --------------------------------------
# Redis Configuration
# --------------------------------------
REDIS_HOST=redis
REDIS_PORT=6379

# --------------------------------------
# Application Settings
# --------------------------------------
COMPRESSION_MODEL_OVERRIDE=gpt-4o-mini
COMPRESSION_PROMPT_VERSION=v1.0
COMPRESSION_MAX_HISTORY_POINTS=3
```

### Step 5: Configure Frontend Environment

```bash
# Create frontend .env file
cd /root/docgpt/frontend
nano .env
```

**Frontend `.env.production`:**

```env
# Stripe Public Key (Production)
VITE_STRIPE_PUBLISHABLE_KEY=pk_live_YOUR_PRODUCTION_PUBLISHABLE_KEY

# API Base URL (use your domain or server IP)
# With domain:
VITE_API_BASE_URL=https://api.yourdomain.com

# Or with IP:
# VITE_API_BASE_URL=https://78.31.67.155:7091
```

### Step 6: Set Up Stripe Production Environment

#### A. Create Stripe Products (if not already created)

1. Go to Stripe Dashboard: https://dashboard.stripe.com/products
2. Create three products:

**Free Plan:**
- Name: Free Plan
- Price: $0 (one-time or free)
- Note the Product ID and Price ID

**Pro Plan:**
- Name: Pro Plan
- Price: $15/month (recurring)
- Billing period: Monthly
- Note the Product ID and Price ID

**Enterprise Plan:**
- Name: Enterprise Plan
- Price: $30/month (recurring)
- Billing period: Monthly
- Note the Product ID and Price ID

3. Update the `.env` file with the actual Product and Price IDs

#### B. Configure Stripe Webhook

1. Go to: https://dashboard.stripe.com/webhooks
2. Click "Add endpoint"
3. Endpoint URL: `https://yourdomain.com/api/webhooks/stripe`
   - Or: `https://78.31.67.155/api/webhooks/stripe`
4. Select events to listen for:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.paid`
   - `invoice.payment_failed`
5. Copy the "Signing secret" (starts with `whsec_`)
6. Add it to `.env` as `STRIPE_WEBHOOK_SECRET`

### Step 7: Initialize Database

```bash
cd /root/docgpt

# Start MongoDB first
docker-compose up -d mongodb redis

# Wait for MongoDB to be ready (about 10 seconds)
sleep 10

# Initialize database indexes
docker-compose exec backend python application/init_db_indexes.py

# Or if not using Docker yet:
python application/init_db_indexes.py
```

### Step 8: Build and Start Services

```bash
cd /root/docgpt

# Build Docker images
docker-compose build

# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f

# Check specific service
docker-compose logs -f backend
docker-compose logs -f frontend
```

### Step 9: Set Up Nginx Reverse Proxy

```bash
# Install Nginx
sudo apt install -y nginx

# Create Nginx configuration
sudo nano /etc/nginx/sites-available/docsgpt
```

**Nginx Configuration:**

```nginx
# Backend API
server {
    listen 80;
    server_name api.yourdomain.com;  # Or use IP: 78.31.67.155

    # Redirect HTTP to HTTPS (after SSL is configured)
    # return 301 https://$server_name$request_uri;

    location / {
        proxy_pass http://localhost:7091;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Increase timeouts for long requests
        proxy_connect_timeout 600;
        proxy_send_timeout 600;
        proxy_read_timeout 600;
        send_timeout 600;
    }

    # Stripe webhook endpoint (no timeout)
    location /api/webhooks/stripe {
        proxy_pass http://localhost:7091;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # No timeout for webhooks
        proxy_read_timeout 300;
    }
}

# Frontend
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;  # Or use IP

    # Redirect HTTP to HTTPS (after SSL is configured)
    # return 301 https://$server_name$request_uri;

    location / {
        proxy_pass http://localhost:5173;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

**Enable the configuration:**

```bash
# Create symbolic link
sudo ln -s /etc/nginx/sites-available/docsgpt /etc/nginx/sites-enabled/

# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# Enable Nginx to start on boot
sudo systemctl enable nginx
```

### Step 10: Configure SSL with Let's Encrypt (Recommended)

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com -d api.yourdomain.com

# Certbot will automatically:
# 1. Obtain certificates
# 2. Update Nginx configuration
# 3. Set up auto-renewal

# Test auto-renewal
sudo certbot renew --dry-run

# Check renewal timer
sudo systemctl status certbot.timer
```

**After SSL is configured, update your `.env` files:**

```bash
# Backend .env - update CORS
CORS_ORIGINS=https://yourdomain.com,https://www.yourdomain.com

# Frontend .env - update API URL
VITE_API_BASE_URL=https://api.yourdomain.com
```

### Step 11: Rebuild Frontend with Production Settings

```bash
cd /root/docgpt/frontend

# Build production frontend
npm run build

# Or rebuild with Docker
cd /root/docgpt
docker-compose build frontend
docker-compose up -d frontend
```

### Step 12: Test Production Deployment

```bash
# Check all services are running
docker-compose ps

# Test backend API
curl https://api.yourdomain.com/api/subscription/plans

# Test frontend
curl https://yourdomain.com

# Check logs for errors
docker-compose logs backend | grep ERROR
docker-compose logs frontend | grep ERROR
```

---

## 🧪 Production Testing Checklist

### Backend Testing
- [ ] API is accessible at production URL
- [ ] `/api/subscription/plans` returns plan data
- [ ] MongoDB connection is working
- [ ] Redis connection is working
- [ ] Celery workers are running

### Frontend Testing
- [ ] Website loads at production URL
- [ ] Registration form works
- [ ] Login form works
- [ ] Pricing page displays correctly
- [ ] Can create Stripe checkout session

### Stripe Integration Testing
- [ ] Checkout redirects to Stripe
- [ ] Can complete test payment (use test mode first)
- [ ] Webhook receives events
- [ ] Subscription status updates in database
- [ ] Usage tracking works

### SSL/Security Testing
- [ ] HTTPS is working
- [ ] HTTP redirects to HTTPS
- [ ] SSL certificate is valid
- [ ] No mixed content warnings
- [ ] CORS is configured correctly

---

## 🔐 Security Hardening

### 1. Firewall Configuration

```bash
# Install UFW (if not installed)
sudo apt install -y ufw

# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

### 2. Secure MongoDB

```bash
# If using Docker MongoDB, it's already isolated
# For external MongoDB:
# - Enable authentication
# - Use strong passwords
# - Restrict network access
# - Enable SSL/TLS
```

### 3. Secure Environment Variables

```bash
# Restrict .env file permissions
chmod 600 /root/docgpt/.env
chmod 600 /root/docgpt/frontend/.env

# Never commit .env to git
echo ".env" >> /root/docgpt/.gitignore
```

### 4. Set Up Fail2Ban (Optional)

```bash
# Install Fail2Ban
sudo apt install -y fail2ban

# Configure for SSH protection
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

---

## 📊 Monitoring and Maintenance

### 1. Set Up Log Rotation

```bash
# Docker logs are automatically rotated
# For application logs:
sudo nano /etc/logrotate.d/docsgpt
```

```
/root/docgpt/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
}
```

### 2. Monitor Service Health

```bash
# Create health check script
cat > /root/docgpt/health_check.sh << 'EOF'
#!/bin/bash

# Check backend
BACKEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:7091/api/subscription/plans)
if [ "$BACKEND_STATUS" != "200" ]; then
    echo "Backend is down! Status: $BACKEND_STATUS"
    # Send alert (configure email/Slack)
fi

# Check frontend
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5173)
if [ "$FRONTEND_STATUS" != "200" ]; then
    echo "Frontend is down! Status: $FRONTEND_STATUS"
    # Send alert
fi

# Check MongoDB
MONGO_STATUS=$(docker-compose exec -T mongodb mongosh --eval "db.adminCommand('ping')" 2>&1 | grep -c "ok")
if [ "$MONGO_STATUS" -eq 0 ]; then
    echo "MongoDB is down!"
    # Send alert
fi
EOF

chmod +x /root/docgpt/health_check.sh

# Add to crontab (check every 5 minutes)
(crontab -l 2>/dev/null; echo "*/5 * * * * /root/docgpt/health_check.sh") | crontab -
```

### 3. Database Backups

```bash
# Create backup script
cat > /root/docgpt/backup_mongodb.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/root/docgpt_backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup MongoDB
docker-compose exec -T mongodb mongodump --out=/backup/$DATE

# Move to local directory
docker cp $(docker-compose ps -q mongodb):/backup/$DATE $BACKUP_DIR/

# Compress
tar -czf $BACKUP_DIR/mongodb_$DATE.tar.gz $BACKUP_DIR/$DATE
rm -rf $BACKUP_DIR/$DATE

# Keep only last 7 days
find $BACKUP_DIR -type f -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: mongodb_$DATE.tar.gz"
EOF

chmod +x /root/docgpt/backup_mongodb.sh

# Add to crontab (daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * /root/docgpt/backup_mongodb.sh") | crontab -
```

---

## 🔄 Updating the Application

### When New Features Are Added

```bash
cd /root/docgpt

# Pull latest changes
git pull origin main

# Rebuild Docker images
docker-compose build

# Restart services
docker-compose down
docker-compose up -d

# Check logs for errors
docker-compose logs -f
```

---

## 🆘 Troubleshooting

### Issue: Services Won't Start

```bash
# Check Docker logs
docker-compose logs

# Check specific service
docker-compose logs backend
docker-compose logs mongodb

# Restart services
docker-compose restart

# Full restart
docker-compose down
docker-compose up -d
```

### Issue: Database Connection Error

```bash
# Check MongoDB is running
docker-compose ps mongodb

# Test MongoDB connection
docker-compose exec mongodb mongosh --eval "db.adminCommand('ping')"

# Check connection string in .env
cat .env | grep MONGO_URI
```

### Issue: Stripe Webhook Not Working

```bash
# Check webhook endpoint is accessible
curl -X POST https://yourdomain.com/api/webhooks/stripe

# Check Stripe webhook logs in dashboard
# Check backend logs for webhook errors
docker-compose logs backend | grep webhook
```

### Issue: Frontend Not Loading

```bash
# Check frontend service
docker-compose logs frontend

# Rebuild frontend
cd frontend
npm run build
cd ..
docker-compose restart frontend
```

---

## 📞 Post-Deployment Support

### Stripe Dashboard Monitoring
- Monitor successful/failed payments
- Check webhook delivery status
- Review customer subscriptions

### Application Monitoring
- Check Docker container health: `docker-compose ps`
- Monitor logs: `docker-compose logs -f`
- Check disk space: `df -h`
- Monitor memory: `free -m`

### Database Monitoring
- Check MongoDB stats: `docker-compose exec mongodb mongosh --eval "db.stats()"`
- Monitor connections: `docker-compose exec mongodb mongosh --eval "db.serverStatus().connections"`

---

## ✅ Deployment Completion Checklist

- [ ] Server is accessible via SSH
- [ ] Docker and Docker Compose installed
- [ ] Repository cloned/updated with latest code
- [ ] Production `.env` files configured
- [ ] Stripe production keys configured
- [ ] Stripe webhook endpoint created
- [ ] Database indexes initialized
- [ ] All Docker services running
- [ ] Nginx reverse proxy configured
- [ ] SSL certificate installed
- [ ] Firewall configured
- [ ] Health monitoring set up
- [ ] Database backups configured
- [ ] Application tested end-to-end
- [ ] Documentation updated with production URLs

---

## 🎯 Production URLs

After deployment, your application will be available at:

- **Frontend**: https://yourdomain.com (or https://78.31.67.155)
- **Backend API**: https://api.yourdomain.com (or https://78.31.67.155:7091)
- **Stripe Webhook**: https://api.yourdomain.com/api/webhooks/stripe

---

## 📚 Additional Resources

- **Stripe Dashboard**: https://dashboard.stripe.com
- **Stripe Webhooks**: https://dashboard.stripe.com/webhooks
- **Docker Logs**: `docker-compose logs -f`
- **MongoDB Admin**: Access via `docker-compose exec mongodb mongosh`

---

**Deployment Guide Version**: 1.0  
**Last Updated**: November 26, 2025  
**Support**: Check `QUICK_START_GUIDE.md` for testing procedures
