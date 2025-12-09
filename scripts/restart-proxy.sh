#!/bin/bash

#############################################
# Restart Traefik Reverse Proxy
# Usage: ./restart-proxy.sh
#############################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_info() { echo -e "${YELLOW}ℹ $1${NC}"; }

INFRA_DIR="/home/munaim/docker-infrastructure"

echo "=========================================="
echo "  Restarting Traefik"
echo "=========================================="
echo ""

cd "$INFRA_DIR/traefik"

print_info "Stopping Traefik..."
docker compose down

print_info "Starting Traefik..."
docker compose up -d

sleep 3

if docker ps | grep -q traefik; then
    print_success "Traefik restarted successfully!"
    echo ""
    docker ps --filter "name=traefik" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    echo "Failed to restart Traefik. Check logs:"
    echo "  cd $INFRA_DIR/traefik"
    echo "  docker compose logs"
fi

echo ""
