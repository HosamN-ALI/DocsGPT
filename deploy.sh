#!/bin/bash

# DocsGPT Subscription System - Production Deployment Script
# Server: 78.31.67.155
# Location: /root/docgpt

set -e  # Exit on any error

echo "=========================================="
echo "DocsGPT Production Deployment Script"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root"
    exit 1
fi

# Check if we're in the correct directory
if [ ! -f "docker-compose.yml" ]; then
    print_error "docker-compose.yml not found. Please run from /root/docgpt directory"
    exit 1
fi

echo "Step 1: Checking system requirements..."
echo "----------------------------------------"

# Check Docker
if command -v docker &> /dev/null; then
    print_success "Docker is installed: $(docker --version)"
else
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    print_success "Docker Compose is installed: $(docker-compose --version)"
else
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo ""
echo "Step 2: Pulling latest code..."
echo "----------------------------------------"

# Pull latest changes
git pull origin main
print_success "Code updated from GitHub"

echo ""
echo "Step 3: Checking environment configuration..."
echo "----------------------------------------"

# Check if .env exists
if [ ! -f ".env" ]; then
    print_warning ".env file not found!"
    print_info "Creating .env from .env.subscription.example..."
    
    if [ -f ".env.subscription.example" ]; then
        cp .env.subscription.example .env
        print_success ".env file created"
        print_warning "IMPORTANT: Edit .env file with production values before continuing!"
        print_info "Required changes:"
        echo "  - JWT_SECRET_KEY (generate with: openssl rand -hex 32)"
        echo "  - STRIPE_SECRET_KEY (production key)"
        echo "  - STRIPE_PUBLISHABLE_KEY (production key)"
        echo "  - STRIPE_WEBHOOK_SECRET (from Stripe dashboard)"
        echo "  - Product and Price IDs (from Stripe dashboard)"
        echo ""
        read -p "Press Enter after you've updated .env file, or Ctrl+C to exit..."
    else
        print_error ".env.subscription.example not found"
        exit 1
    fi
else
    print_success ".env file found"
fi

# Check if frontend .env exists
if [ ! -f "frontend/.env" ]; then
    print_warning "frontend/.env file not found!"
    print_info "You'll need to create it with:"
    echo "  VITE_STRIPE_PUBLISHABLE_KEY=pk_live_..."
    echo "  VITE_API_BASE_URL=https://api.yourdomain.com"
    echo ""
fi

echo ""
echo "Step 4: Stopping existing services..."
echo "----------------------------------------"

docker-compose down
print_success "Services stopped"

echo ""
echo "Step 5: Building Docker images..."
echo "----------------------------------------"

docker-compose build
print_success "Docker images built"

echo ""
echo "Step 6: Starting MongoDB and Redis..."
echo "----------------------------------------"

docker-compose up -d mongodb redis
print_success "MongoDB and Redis started"

# Wait for MongoDB to be ready
print_info "Waiting for MongoDB to be ready..."
sleep 10

echo ""
echo "Step 7: Initializing database indexes..."
echo "----------------------------------------"

# Check if init_db_indexes.py exists
if [ -f "application/init_db_indexes.py" ]; then
    docker-compose exec -T backend python application/init_db_indexes.py || {
        print_warning "Failed to initialize indexes via Docker, trying directly..."
        python3 application/init_db_indexes.py
    }
    print_success "Database indexes initialized"
else
    print_warning "init_db_indexes.py not found, skipping..."
fi

echo ""
echo "Step 8: Starting all services..."
echo "----------------------------------------"

docker-compose up -d
print_success "All services started"

echo ""
echo "Step 9: Checking service health..."
echo "----------------------------------------"

sleep 5

# Check service status
if docker-compose ps | grep -q "Up"; then
    print_success "Services are running"
    echo ""
    docker-compose ps
else
    print_error "Some services failed to start"
    echo ""
    docker-compose ps
    echo ""
    print_info "Check logs with: docker-compose logs"
    exit 1
fi

echo ""
echo "=========================================="
echo "Deployment Summary"
echo "=========================================="
echo ""

# Get container IPs
BACKEND_PORT=$(docker-compose port backend 7091 2>/dev/null | cut -d: -f2 || echo "7091")
FRONTEND_PORT=$(docker-compose port frontend 5173 2>/dev/null | cut -d: -f2 || echo "5173")

print_success "Backend API: http://localhost:${BACKEND_PORT}"
print_success "Frontend: http://localhost:${FRONTEND_PORT}"
echo ""

print_info "Next steps:"
echo "  1. Configure Nginx reverse proxy (see PRODUCTION_DEPLOYMENT_GUIDE.md)"
echo "  2. Set up SSL with Let's Encrypt"
echo "  3. Configure Stripe webhook endpoint"
echo "  4. Test the application thoroughly"
echo ""

print_info "Useful commands:"
echo "  - View logs: docker-compose logs -f"
echo "  - Restart services: docker-compose restart"
echo "  - Stop services: docker-compose down"
echo "  - Check status: docker-compose ps"
echo ""

print_info "Documentation:"
echo "  - Deployment Guide: PRODUCTION_DEPLOYMENT_GUIDE.md"
echo "  - Quick Start: QUICK_START_GUIDE.md"
echo "  - Complete Docs: SUBSCRIPTION_SYSTEM_COMPLETE.md"
echo ""

print_success "Deployment completed successfully! 🎉"
echo ""
