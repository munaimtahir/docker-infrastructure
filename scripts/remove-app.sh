#!/bin/bash

#############################################
# Remove App from Traefik
# Usage: ./remove-app.sh <app_name>
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

INFRA_DIR="/home/munaim/docker-infrastructure"
REGISTRY_FILE="$INFRA_DIR/config/apps.json"

# Check arguments
if [ $# -lt 1 ]; then
    print_error "Usage: $0 <app_name>"
    echo ""
    echo "Example:"
    echo "  $0 consult"
    echo ""
    echo "Available apps:"
    ./list-apps.sh
    exit 1
fi

APP_NAME="$1"

echo "=========================================="
echo "  Removing App from Traefik"
echo "=========================================="
echo ""

# Get app path from registry
APP_PATH=$(python3 - <<EOF
import json
import sys

registry_file = "$REGISTRY_FILE"
app_name = "$APP_NAME"

try:
    with open(registry_file, 'r') as f:
        registry = json.load(f)
    
    for app in registry.get('apps', []):
        if app['name'] == app_name:
            print(app['path'])
            sys.exit(0)
    
    sys.exit(1)
    
except Exception as e:
    sys.exit(1)
EOF
)

if [ -z "$APP_PATH" ]; then
    print_error "App '$APP_NAME' not found in registry"
    echo ""
    echo "Available apps:"
    ./list-apps.sh
    exit 1
fi

print_info "App Path: $APP_PATH"

# Check for docker-compose.yml
COMPOSE_FILE="$APP_PATH/docker-compose.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    print_error "docker-compose.yml not found in $APP_PATH"
    exit 1
fi

# Stop the app
print_info "Stopping app..."
cd "$APP_PATH"
docker compose down 2>/dev/null || true
print_success "App stopped"

# Check if backup exists
LATEST_BACKUP=$(ls -t "$APP_PATH"/docker-compose.yml.backup.* 2>/dev/null | head -n 1)

if [ -n "$LATEST_BACKUP" ]; then
    print_info "Restoring from backup: $LATEST_BACKUP"
    cp "$LATEST_BACKUP" "$COMPOSE_FILE"
    print_success "Original docker-compose.yml restored"
else
    print_info "No backup found. Removing Traefik labels manually..."
    
    # Remove Traefik labels using Python
    python3 - <<EOF
import yaml

compose_file = "$COMPOSE_FILE"

try:
    with open(compose_file, 'r') as f:
        compose = yaml.safe_load(f)
    
    # Remove Traefik labels from all services
    for service_name, service in compose.get('services', {}).items():
        if 'labels' in service:
            service['labels'] = [l for l in service['labels'] if not l.startswith('traefik.')]
            if not service['labels']:
                del service['labels']
        
        # Remove web network
        if 'networks' in service and 'web' in service['networks']:
            service['networks'].remove('web')
            if not service['networks']:
                del service['networks']
    
    # Remove web network from networks section
    if 'networks' in compose and 'web' in compose['networks']:
        del compose['networks']['web']
        if not compose['networks']:
            del compose['networks']
    
    with open(compose_file, 'w') as f:
        yaml.dump(compose, f, default_flow_style=False, sort_keys=False)
    
    print("SUCCESS")
    
except Exception as e:
    print(f"ERROR: {e}")
    exit(1)
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Traefik configuration removed"
    else
        print_error "Failed to remove Traefik configuration"
        exit 1
    fi
fi

# Remove from registry
print_info "Removing from registry..."
python3 - <<EOF
import json
from datetime import datetime

registry_file = "$REGISTRY_FILE"
app_name = "$APP_NAME"

try:
    with open(registry_file, 'r') as f:
        registry = json.load(f)
    
    registry['apps'] = [a for a in registry['apps'] if a['name'] != app_name]
    registry['last_updated'] = datetime.now().isoformat()
    
    with open(registry_file, 'w') as f:
        json.dump(registry, f, indent=2)
    
    print("SUCCESS")
    
except Exception as e:
    print(f"ERROR: {e}")
EOF

print_success "Removed from registry"

echo ""
echo "=========================================="
echo "  ✓ App Removed Successfully!"
echo "=========================================="
echo ""
print_success "App '$APP_NAME' has been removed from Traefik"
echo ""
echo "The app is stopped but files are still in: $APP_PATH"
echo ""
echo "To start the app again (without Traefik):"
echo "  cd $APP_PATH"
echo "  docker compose up -d"
echo ""
echo "To add it back to Traefik:"
echo "  ./scripts/add-app.sh $APP_PATH /path"
echo ""
