#!/bin/bash

# Remote Deployment Helper Script
# Deploys DocsGPT to production server: 78.31.67.155

set -e

SERVER="78.31.67.155"
SSH_KEY="/home/user/uploaded_files/root"
REMOTE_DIR="/root/docgpt"
REPO_URL="https://github.com/HosamN-ALI/DocsGPT.git"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${YELLOW}ℹ $1${NC}"; }

echo "=========================================="
echo "Remote Deployment to $SERVER"
echo "=========================================="
echo ""

# Check SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    print_error "SSH key not found at $SSH_KEY"
    exit 1
fi

# Set proper permissions
chmod 600 "$SSH_KEY"
print_success "SSH key permissions set"

# Test SSH connection
print_info "Testing SSH connection..."
if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@$SERVER "echo 'Connected'" &> /dev/null; then
    print_success "SSH connection successful"
else
    print_error "Cannot connect to server"
    exit 1
fi

echo ""
echo "Step 1: Checking if repository exists on server..."
echo "----------------------------------------"

REPO_EXISTS=$(ssh -i "$SSH_KEY" root@$SERVER "[ -d '$REMOTE_DIR/.git' ] && echo 'yes' || echo 'no'")

if [ "$REPO_EXISTS" = "yes" ]; then
    print_success "Repository exists, pulling latest changes..."
    ssh -i "$SSH_KEY" root@$SERVER "cd $REMOTE_DIR && git pull origin main"
else
    print_info "Repository not found, cloning..."
    ssh -i "$SSH_KEY" root@$SERVER "git clone $REPO_URL $REMOTE_DIR"
    print_success "Repository cloned"
fi

echo ""
echo "Step 2: Uploading SSH key to server..."
echo "----------------------------------------"

# Upload the SSH key to server for future git operations
scp -i "$SSH_KEY" "$SSH_KEY" root@$SERVER:/root/.ssh/id_rsa_github
ssh -i "$SSH_KEY" root@$SERVER "chmod 600 /root/.ssh/id_rsa_github"
print_success "SSH key uploaded"

echo ""
echo "Step 3: Checking Docker installation..."
echo "----------------------------------------"

DOCKER_INSTALLED=$(ssh -i "$SSH_KEY" root@$SERVER "command -v docker &> /dev/null && echo 'yes' || echo 'no'")

if [ "$DOCKER_INSTALLED" = "no" ]; then
    print_warning "Docker not installed, installing..."
    ssh -i "$SSH_KEY" root@$SERVER "curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh"
    print_success "Docker installed"
else
    print_success "Docker is already installed"
fi

# Check Docker Compose
COMPOSE_INSTALLED=$(ssh -i "$SSH_KEY" root@$SERVER "command -v docker-compose &> /dev/null && echo 'yes' || echo 'no'")

if [ "$COMPOSE_INSTALLED" = "no" ]; then
    print_warning "Docker Compose not installed, installing..."
    ssh -i "$SSH_KEY" root@$SERVER 'curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose'
    print_success "Docker Compose installed"
else
    print_success "Docker Compose is already installed"
fi

echo ""
echo "Step 4: Checking environment configuration..."
echo "----------------------------------------"

ENV_EXISTS=$(ssh -i "$SSH_KEY" root@$SERVER "[ -f '$REMOTE_DIR/.env' ] && echo 'yes' || echo 'no'")

if [ "$ENV_EXISTS" = "no" ]; then
    print_warning ".env file not found on server"
    print_info "Creating from template..."
    ssh -i "$SSH_KEY" root@$SERVER "cd $REMOTE_DIR && cp .env.subscription.example .env"
    print_warning "IMPORTANT: You need to configure .env on the server!"
    print_info "SSH to server and edit: nano $REMOTE_DIR/.env"
    echo ""
    print_info "Required environment variables:"
    echo "  - JWT_SECRET_KEY (generate: openssl rand -hex 32)"
    echo "  - STRIPE_SECRET_KEY (production key)"
    echo "  - STRIPE_PUBLISHABLE_KEY (production key)"
    echo "  - STRIPE_WEBHOOK_SECRET (from Stripe dashboard)"
    echo "  - Stripe Product/Price IDs"
    echo ""
    read -p "Press Enter after you've configured .env, or Ctrl+C to exit..."
else
    print_success ".env file exists on server"
fi

echo ""
echo "Step 5: Running deployment script on server..."
echo "----------------------------------------"

ssh -i "$SSH_KEY" root@$SERVER "cd $REMOTE_DIR && bash deploy.sh"

echo ""
echo "=========================================="
echo "Remote Deployment Complete!"
echo "=========================================="
echo ""

print_success "Application deployed to $SERVER"
echo ""

print_info "Access your application:"
echo "  - SSH: ssh -i $SSH_KEY root@$SERVER"
echo "  - Backend: http://$SERVER:7091"
echo "  - Frontend: http://$SERVER:5173"
echo ""

print_info "Next steps:"
echo "  1. Configure Nginx reverse proxy"
echo "  2. Set up SSL certificate"
echo "  3. Configure Stripe webhook"
echo "  4. Test the application"
echo ""

print_info "Documentation on server:"
echo "  - $REMOTE_DIR/PRODUCTION_DEPLOYMENT_GUIDE.md"
echo "  - $REMOTE_DIR/QUICK_START_GUIDE.md"
echo ""

print_success "Deployment completed! 🚀"
