#!/bin/bash

#############################################
# List All Registered Apps
# Usage: ./list-apps.sh
#############################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }
print_info() { echo -e "${YELLOW}$1${NC}"; }
print_blue() { echo -e "${BLUE}$1${NC}"; }

INFRA_DIR="/home/munaim/docker-infrastructure"
REGISTRY_FILE="$INFRA_DIR/config/apps.json"

echo "=========================================="
echo "  Registered Apps"
echo "=========================================="
echo ""

if [ ! -f "$REGISTRY_FILE" ]; then
    print_error "No apps registered yet."
    echo ""
    echo "Add your first app:"
    echo "  ./scripts/add-app.sh /home/munaim/apps/YOUR_APP /path"
    echo ""
    exit 0
fi

# Use Python to parse and display JSON
python3 - <<EOF
import json
import subprocess
from datetime import datetime

registry_file = "$REGISTRY_FILE"

try:
    with open(registry_file, 'r') as f:
        registry = json.load(f)
    
    apps = registry.get('apps', [])
    
    if not apps:
        print("No apps registered yet.")
        print("")
        print("Add your first app:")
        print("  ./scripts/add-app.sh /home/munaim/apps/YOUR_APP /path")
        exit(0)
    
    print(f"Total Apps: {len(apps)}")
    print("")
    
    for i, app in enumerate(apps, 1):
        name = app['name']
        url = app['url']
        path = app['path']
        
        # Check if app is running
        try:
            result = subprocess.run(
                ['docker', 'compose', 'ps', '-q'],
                cwd=path,
                capture_output=True,
                text=True,
                timeout=5
            )
            is_running = bool(result.stdout.strip())
            status = "\033[0;32m●\033[0m Running" if is_running else "\033[0;31m●\033[0m Stopped"
        except:
            status = "\033[0;33m●\033[0m Unknown"
        
        print(f"{i}. \033[1m{name}\033[0m")
        print(f"   URL:    \033[0;34m{url}\033[0m")
        print(f"   Path:   {path}")
        print(f"   Status: {status}")
        print("")
    
    print("Last Updated: {}".format(registry.get('last_updated', 'Unknown')))
    
except Exception as e:
    print(f"Error reading registry: {e}")
    exit(1)
EOF

echo ""
echo "=========================================="
echo ""
echo "Commands:"
echo "  Add app:    ./scripts/add-app.sh <path> <url_path>"
echo "  Remove app: ./scripts/remove-app.sh <app_name>"
echo "  Dashboard:  http://34.93.19.177:8080"
echo ""
