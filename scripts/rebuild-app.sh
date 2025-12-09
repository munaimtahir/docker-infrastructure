#!/bin/bash

#############################################
# Rebuild App Frontend with Base Path
# Usage: ./rebuild-app.sh <app_path> <url_path>
# Example: ./rebuild-app.sh /home/munaim/apps/consult /consult
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

# Check arguments
if [ $# -lt 2 ]; then
    print_error "Usage: $0 <app_path> <url_path>"
    exit 1
fi

APP_PATH="$1"
URL_PATH="$2"

# Ensure URL path starts with / and ends with /
if [[ ! "$URL_PATH" =~ ^/ ]]; then
    URL_PATH="/$URL_PATH"
fi
if [[ ! "$URL_PATH" =~ /$ ]]; then
    URL_PATH="${URL_PATH}/"
fi

print_info "Rebuilding app: $APP_PATH"
print_info "Base path: $URL_PATH"

# Check for frontend directory
FRONTEND_DIR="$APP_PATH/frontend"
if [ ! -d "$FRONTEND_DIR" ]; then
    print_error "Frontend directory not found: $FRONTEND_DIR"
    exit 1
fi

cd "$FRONTEND_DIR"

# Check for Vite config
if [ -f "vite.config.js" ] || [ -f "vite.config.ts" ]; then
    print_info "Found Vite config, updating base path..."
    
    VITE_CONFIG=""
    if [ -f "vite.config.js" ]; then
        VITE_CONFIG="vite.config.js"
    else
        VITE_CONFIG="vite.config.ts"
    fi
    
    # Check if base is already set
    if grep -q "base:" "$VITE_CONFIG"; then
        print_info "Base path already configured in $VITE_CONFIG"
        print_info "Please manually update it to: base: '$URL_PATH'"
    else
        print_info "Adding base path to $VITE_CONFIG..."
        # This is a simple approach - user may need to manually edit for complex configs
        print_info "Please add: base: '$URL_PATH' to your vite config"
    fi
fi

# Check for React (CRA) package.json
if [ -f "package.json" ] && grep -q "react-scripts" package.json 2>/dev/null; then
    print_info "Found React (CRA) app, updating package.json..."
    if ! grep -q '"homepage"' package.json; then
        print_info "Please add to package.json: \"homepage\": \"$URL_PATH\""
    else
        print_info "Homepage already configured in package.json"
    fi
fi

# Rebuild the frontend
print_info "Rebuilding frontend..."
if [ -f "package.json" ]; then
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        print_info "Installing dependencies..."
        npm install
    fi
    
    # Build
    print_info "Building..."
    npm run build
    
    print_success "Frontend rebuilt successfully!"
    print_info "Restart the app container to use the new build"
else
    print_error "No package.json found"
    exit 1
fi

echo ""
print_info "Next steps:"
print_info "1. Restart the app: cd $APP_PATH && docker compose restart"
print_info "2. Or rebuild the container: cd $APP_PATH && docker compose up -d --build"

