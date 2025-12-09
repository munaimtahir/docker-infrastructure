#!/bin/bash

#############################################
# Test Infrastructure Connectivity
# Usage: ./test-connectivity.sh
#############################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${YELLOW}ℹ $1${NC}"; }
print_blue() { echo -e "${BLUE}$1${NC}"; }

# Allow override via environment variable for flexibility
INFRA_DIR="${INFRA_DIR:-/home/munaim/docker-infrastructure}"
SERVER_HOST="${SERVER_HOST:-$(hostname -I | awk '{print $1}')}"

echo "=========================================="
echo "  Infrastructure Connectivity Test"
echo "=========================================="
echo ""

print_info "Testing server: $SERVER_HOST"
echo ""

# Test 1: Check Docker is running
echo "Test 1: Docker Service"
if docker ps &> /dev/null; then
    print_success "Docker is running"
else
    print_error "Docker is not running or not accessible"
    echo "  Try: sudo systemctl start docker"
    exit 1
fi
echo ""

# Test 2: Check Traefik container
echo "Test 2: Traefik Container"
if docker ps | grep -q traefik; then
    print_success "Traefik container is running"
    docker ps --filter "name=traefik" --format "  Status: {{.Status}}"
else
    print_error "Traefik container is not running"
    echo "  Try: cd $INFRA_DIR/traefik && docker compose up -d"
    exit 1
fi
echo ""

# Test 3: Check web network
echo "Test 3: Docker Network"
if docker network inspect web &> /dev/null; then
    CONTAINER_COUNT=$(docker network inspect web --format '{{len .Containers}}')
    print_success "Web network exists with $CONTAINER_COUNT containers"
else
    print_error "Web network does not exist"
    echo "  Try: docker network create web"
    exit 1
fi
echo ""

# Test 4: Check port 80 is listening
echo "Test 4: Port 80 Listening"
if sudo netstat -tlnp 2>/dev/null | grep -q ":80"; then
    print_success "Port 80 is listening"
    sudo netstat -tlnp 2>/dev/null | grep ":80" | head -1
elif command -v ss &> /dev/null && sudo ss -tlnp 2>/dev/null | grep -q ":80"; then
    print_success "Port 80 is listening"
    sudo ss -tlnp 2>/dev/null | grep ":80" | head -1
else
    print_error "Port 80 is not listening"
    echo "  Check Traefik logs: cd $INFRA_DIR/traefik && docker compose logs"
fi
echo ""

# Test 5: Test local connectivity to dashboard
echo "Test 5: Local Dashboard Connectivity"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://localhost/dashboard/ 2>/dev/null || echo "000")
if [ "$RESPONSE" = "401" ] || [ "$RESPONSE" = "200" ]; then
    print_success "Dashboard is responding (HTTP $RESPONSE - auth required is expected)"
elif [ "$RESPONSE" = "404" ]; then
    print_error "Dashboard returns 404 - Traefik routing issue"
    echo "  Check Traefik config: cat $INFRA_DIR/traefik/docker-compose.yml | grep dashboard"
elif [ "$RESPONSE" = "000" ]; then
    print_error "Cannot connect to dashboard - connection timeout"
    echo "  Check if Traefik is running and port 80 is accessible"
else
    print_error "Dashboard returns HTTP $RESPONSE"
fi
echo ""

# Test 6: Test with authentication
echo "Test 6: Dashboard Authentication"
AUTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 -u admin:admin123 http://localhost/dashboard/ 2>/dev/null || echo "000")
if [ "$AUTH_RESPONSE" = "200" ]; then
    print_success "Dashboard authentication working (HTTP 200)"
elif [ "$AUTH_RESPONSE" = "401" ]; then
    print_error "Authentication failed - wrong credentials or config issue"
    echo "  Default credentials are admin/admin123"
else
    print_error "Dashboard with auth returns HTTP $AUTH_RESPONSE"
fi
echo ""

# Test 7: Check registered apps
echo "Test 7: Registered Apps"
if [ -f "$INFRA_DIR/config/apps.json" ]; then
    APP_COUNT=$(python3 -c "import json; exec(\"with open('$INFRA_DIR/config/apps.json') as f: data=json.load(f); print(len(data.get('apps', [])))\");" 2>/dev/null || echo "0")
    if [ "$APP_COUNT" -gt 0 ]; then
        print_success "$APP_COUNT apps registered"
        echo ""
        echo "  Testing app connectivity..."
        
        # Test each app
        python3 - <<EOF
import json
import subprocess

try:
    with open('$INFRA_DIR/config/apps.json', 'r') as f:
        data = json.load(f)
    
    for app in data.get('apps', []):
        name = app['name']
        url_path = app['url_path']
        
        # Test local connectivity
        result = subprocess.run(
            ['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', '--max-time', '5', f'http://localhost{url_path}'],
            capture_output=True,
            text=True,
            timeout=6
        )
        
        status_code = result.stdout.strip() if result.returncode == 0 else '000'
        
        if status_code in ['200', '301', '302', '304']:
            print(f"  \033[0;32m✓\033[0m {name:15} http://localhost{url_path:20} (HTTP {status_code})")
        elif status_code == '503':
            print(f"  \033[0;31m✗\033[0m {name:15} http://localhost{url_path:20} (503 - Service down)")
        elif status_code == '404':
            print(f"  \033[0;31m✗\033[0m {name:15} http://localhost{url_path:20} (404 - Not found)")
        elif status_code == '000':
            print(f"  \033[0;31m✗\033[0m {name:15} http://localhost{url_path:20} (Timeout)")
        else:
            print(f"  \033[0;33m⚠\033[0m {name:15} http://localhost{url_path:20} (HTTP {status_code})")
            
except Exception as e:
    print(f"  Error testing apps: {e}")
EOF
    else
        print_info "No apps registered yet"
        echo "  Add your first app: ./scripts/add-app.sh /path/to/app /url-path"
    fi
else
    print_error "Apps registry not found"
fi
echo ""

# Test 8: Firewall check
echo "Test 8: Firewall Configuration"
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(sudo ufw status | grep "Status:" | awk '{print $2}')
    if [ "$UFW_STATUS" = "active" ]; then
        print_info "UFW firewall is active"
        
        # Check if ports are allowed
        if sudo ufw status | grep -q "80/tcp.*ALLOW"; then
            print_success "Port 80 is allowed in firewall"
        else
            print_error "Port 80 is not allowed in firewall"
            echo "  Try: sudo ufw allow 80/tcp"
        fi
        
        if sudo ufw status | grep -q "443/tcp.*ALLOW"; then
            print_success "Port 443 is allowed in firewall"
        else
            print_info "Port 443 is not allowed in firewall (needed for HTTPS)"
            echo "  Try: sudo ufw allow 443/tcp"
        fi
    else
        print_info "UFW firewall is not active"
    fi
else
    print_info "UFW not installed - ensure firewall allows ports 80 and 443"
fi
echo ""

# Test 9: External IP detection
echo "Test 9: IP Address Detection"
print_info "Detected IP: $SERVER_HOST"

# Try to get public IP
if command -v curl &> /dev/null; then
    PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || echo "")
    if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "$SERVER_HOST" ]; then
        print_info "Public IP: $PUBLIC_IP"
        echo "  Note: Detected IP differs from public IP"
        echo "  Set manually if needed: export SERVER_HOST=$PUBLIC_IP"
    elif [ -n "$PUBLIC_IP" ]; then
        print_success "Public IP matches detected IP"
    else
        print_info "Could not determine public IP"
    fi
fi
echo ""

# Summary
echo "=========================================="
echo "  Test Summary"
echo "=========================================="
echo ""

# Get Traefik status
TRAEFIK_RUNNING=$(docker ps --filter "name=traefik" --format "{{.Status}}" 2>/dev/null | grep -q "Up" && echo "yes" || echo "no")

if [ "$TRAEFIK_RUNNING" = "yes" ] && ([ "$RESPONSE" = "401" ] || [ "$RESPONSE" = "200" ]); then
    print_success "Infrastructure is operational!"
    echo ""
    print_blue "Access your services:"
    echo "  Dashboard: http://$SERVER_HOST/dashboard/"
    echo "  Username: admin"
    echo "  Password: admin123"
    echo ""
    
    if [ "$APP_COUNT" -gt 0 ]; then
        print_blue "Your apps:"
        python3 - <<EOF
import json
try:
    with open('$INFRA_DIR/config/apps.json', 'r') as f:
        data = json.load(f)
    for app in data.get('apps', []):
        print(f"  - {app['name']}: http://$SERVER_HOST{app['url_path']}")
except:
    pass
EOF
    fi
    echo ""
    print_info "Note: If accessing from outside, ensure your VPS provider firewall allows HTTP traffic"
else
    print_error "Infrastructure has issues - see test results above"
    echo ""
    echo "Common fixes:"
    echo "  1. Start Traefik: cd $INFRA_DIR/traefik && docker compose up -d"
    echo "  2. Check logs: cd $INFRA_DIR/traefik && docker compose logs"
    echo "  3. Recreate network: docker network create web"
    echo "  4. Check firewall: sudo ufw status"
    echo ""
    print_info "For detailed help, see: TROUBLESHOOTING.md"
fi

echo "=========================================="
