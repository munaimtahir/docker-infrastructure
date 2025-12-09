#!/bin/bash

#############################################
# Add App to Traefik
# Usage: ./add-app.sh <app_path> <url_path>
# Example: ./add-app.sh /home/munaim/apps/consult /consult
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${YELLOW}ℹ $1${NC}"; }

# Configuration
INFRA_DIR="/home/munaim/docker-infrastructure"
# Allow override for domains or new IPs: export SERVER_HOST=mydomain.com
SERVER_HOST="${SERVER_HOST:-$(hostname -I | awk '{print $1}')}"
# Normalize in case a scheme/path was provided
SERVER_HOST="${SERVER_HOST#http://}"
SERVER_HOST="${SERVER_HOST#https://}"
SERVER_HOST="${SERVER_HOST%%/*}"
if [ -z "$SERVER_HOST" ]; then
    print_error "Unable to determine server host. Set SERVER_HOST env var."
    exit 1
fi

# Check arguments
if [ $# -lt 2 ]; then
    print_error "Usage: $0 <app_path> <url_path>"
    exit 1
fi

APP_PATH="$1"
URL_PATH="$2"

# Validate app path
if [ ! -d "$APP_PATH" ]; then
    print_error "App directory not found: $APP_PATH"
    exit 1
fi

# Ensure URL path starts with /
if [[ ! "$URL_PATH" =~ ^/ ]]; then
    URL_PATH="/$URL_PATH"
fi
URL_PATH="${URL_PATH%/}"

echo "=========================================="
echo "  Adding App to Traefik"
echo "=========================================="
print_info "App Path: $APP_PATH"
print_info "URL Path: http://$SERVER_HOST$URL_PATH"

# Check for docker-compose.yml
COMPOSE_FILE="$APP_PATH/docker-compose.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    print_error "docker-compose.yml not found in $APP_PATH"
    exit 1
fi

# Call Python script to handle logic
print_info "Configuring app..."
python3 "$INFRA_DIR/scripts/add_app_logic.py" "$APP_PATH" "$URL_PATH" "$SERVER_HOST"

# Restart the app
echo ""
print_info "Restarting app..."
cd "$APP_PATH"

# Stop the app
docker compose down 2>/dev/null || true

# Start the app
docker compose up -d

if [ $? -eq 0 ]; then
    print_success "App started successfully!"
else
    print_error "Failed to start app"
    exit 1
fi

echo ""
echo "=========================================="
echo "  ✓ App Added Successfully!"
echo "=========================================="
print_success "URL: http://$SERVER_HOST$URL_PATH"
echo ""
