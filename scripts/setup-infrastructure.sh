#!/bin/bash

#############################################
# Traefik Infrastructure Setup Script
# Runs on: Ubuntu/Debian VPS
# User: munaim (sudo access required)
#############################################

set -e  # Exit on error

echo "=========================================="
echo "  Traefik Multi-App Infrastructure Setup"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INFRA_DIR="/home/munaim/docker-infrastructure"
APPS_DIR="/home/munaim/apps"
SERVER_HOST="${SERVER_HOST:-$(hostname -I | awk '{print $1}')}"

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if running as munaim user
if [ "$USER" != "munaim" ]; then
    print_error "This script must be run as user 'munaim'"
    exit 1
fi

print_info "Running as user: $USER"
echo ""

# Step 1: Check Docker installation
echo "Step 1: Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed!"
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker munaim
    print_success "Docker installed. Please log out and log back in, then run this script again."
    exit 0
else
    print_success "Docker is installed: $(docker --version)"
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed!"
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_success "Docker Compose installed"
else
    print_success "Docker Compose is installed"
fi

echo ""

# Step 2: Create directory structure
echo "Step 2: Setting up directory structure..."
mkdir -p "$INFRA_DIR/traefik"
mkdir -p "$INFRA_DIR/scripts"
mkdir -p "$INFRA_DIR/config"
mkdir -p "$APPS_DIR"
print_success "Directory structure created"
echo ""

# Step 3: Create Docker network
echo "Step 3: Creating Docker network 'web'..."
if docker network inspect web &> /dev/null; then
    print_info "Network 'web' already exists"
else
    docker network create web
    print_success "Network 'web' created"
fi
echo ""

# Step 4: Create acme.json for SSL certificates
echo "Step 4: Setting up SSL certificate storage..."
touch "$INFRA_DIR/traefik/acme.json"
chmod 600 "$INFRA_DIR/traefik/acme.json"
print_success "SSL certificate storage ready"
echo ""

# Step 5: Create apps registry
echo "Step 5: Creating apps registry..."
cat > "$INFRA_DIR/config/apps.json" << 'EOF'
{
  "apps": [],
  "last_updated": ""
}
EOF
print_success "Apps registry created"
echo ""

# Step 6: Configure firewall
echo "Step 6: Configuring firewall..."
if command -v ufw &> /dev/null; then
    print_info "Configuring UFW firewall..."
    sudo ufw allow 22/tcp comment 'SSH'
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'
    
    # Enable UFW if not already enabled
    if ! sudo ufw status | grep -q "Status: active"; then
        echo "y" | sudo ufw enable
    fi
    
    print_success "Firewall configured"
    sudo ufw status
else
    print_info "UFW not installed. Please configure firewall manually:"
    echo "  - Allow ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)"
fi
echo ""

# Step 7: Start Traefik
echo "Step 7: Starting Traefik reverse proxy..."
cd "$INFRA_DIR/traefik"

if [ -f "docker-compose.yml" ]; then
    # Stop existing Traefik if running
    docker compose down 2>/dev/null || true
    
    # Start Traefik
    docker compose up -d
    
    # Wait for Traefik to start
    sleep 5
    
    # Check if Traefik is running
    if docker ps | grep -q traefik; then
        print_success "Traefik is running!"
    else
        print_error "Traefik failed to start. Check logs with: docker compose logs"
        exit 1
    fi
else
    print_error "docker-compose.yml not found in $INFRA_DIR/traefik"
    exit 1
fi
echo ""

# Step 8: Verify setup
echo "Step 8: Verifying setup..."
echo ""
echo "Docker Network:"
docker network inspect web --format '{{.Name}}: {{len .Containers}} containers connected' || true
echo ""
echo "Traefik Status:"
docker ps --filter "name=traefik" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Final summary
echo "=========================================="
echo "  ✓ Setup Complete!"
echo "=========================================="
echo ""
print_success "Infrastructure is ready!"
echo ""
echo "Next Steps:"
echo "  1. Access Traefik Dashboard: http://$SERVER_HOST/dashboard"
echo "     Username: admin"
echo "     Password: admin123"
echo "     (Change this password after first login!)"
echo ""
echo "  2. Add your first app:"
echo "     cd $INFRA_DIR"
echo "     ./scripts/add-app.sh /home/munaim/apps/YOUR_APP_NAME /consult"
echo ""
echo "  3. List all apps:"
echo "     ./scripts/list-apps.sh"
echo ""
echo "=========================================="
