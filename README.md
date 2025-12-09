# Traefik Multi-App Infrastructure

Automated setup for running multiple Docker applications behind Traefik reverse proxy with path-based routing.

## 🎯 Latest Updates

### ✅ PUBLIC IP ACCESS FIXED (December 2025)
The critical issue preventing Traefik dashboard and apps from being accessible via public IP has been **RESOLVED**.

**What was fixed**:
- Removed restrictive Host rules for IP-based access
- Apps now work with both IP addresses and domain names
- Dashboard accessible at `http://<your-ip>/dashboard/`
- Apps accessible at `http://<your-ip>/<app-path>`

**To apply fix to existing installations**: See [Troubleshooting](#-troubleshooting) section below.

📖 **Full documentation**: See [FEATURE_ANALYSIS.md](FEATURE_ANALYSIS.md) for complete feature list and [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed help.

## 🚀 Quick Start

### Option 1: Deploy from Windows (Easiest)

1. **Deploy infrastructure to server:**
   ```powershell
   cd C:\Users\Munaim\.gemini\antigravity\scratch\ssh-docker-setup
   .\local-scripts\deploy-to-server.ps1
   ```
   This will upload everything and run the setup automatically.

2. **Add your first app:**
   ```powershell
   .\local-scripts\quick-add-app.ps1 -AppPath "/home/munaim/apps/consult" -URLPath "/consult"
   ```

3. **Access your app:**
   - App: `http://<server_host>/consult`
   - Traefik Dashboard: `http://<server_host>/dashboard`
     - Username: `admin`
     - Password: `admin123`

### Option 2: Manual SSH Deployment

1. **Upload files to server:**
   ```powershell
   scp -r deployment-package munaim@<server_host>:/home/munaim/docker-infrastructure
   ```

2. **SSH to server:**
   ```bash
   ssh munaim@<server_host>
   ```

3. **Run setup:**
   ```bash
   cd /home/munaim/docker-infrastructure
   chmod +x scripts/*.sh
   ./scripts/setup-infrastructure.sh
   ```

4. **Add apps:**
   ```bash
   ./scripts/add-app.sh /home/munaim/apps/consult /consult
   ./scripts/add-app.sh /home/munaim/apps/myapp /myapp
   ```

### Server host setting
- By default the scripts detect the server's primary IP for routing and for the registry.  
- If you're using a domain, export it before running the scripts: `export SERVER_HOST=accreditrack.example.com`.
- The dashboard and apps will be reachable at `http://$SERVER_HOST/<path>`.

## 📁 What Gets Installed

On your server at `/home/munaim/docker-infrastructure`:

```
docker-infrastructure/
├── traefik/
│   ├── docker-compose.yml    # Traefik container config
│   ├── traefik.yml           # Traefik settings
│   └── acme.json             # SSL certificates (auto-generated)
├── scripts/
│   ├── setup-infrastructure.sh   # One-time setup
│   ├── add-app.sh               # Add app to Traefik
│   ├── remove-app.sh            # Remove app
│   ├── list-apps.sh             # List all apps
│   ├── restart-proxy.sh         # Restart Traefik
│   ├── rebuild-app.sh           # Rebuild frontend apps
│   └── test-connectivity.sh     # Test infrastructure (NEW)
├── config/
│   └── apps.json                # Registry of apps
└── docs/
    ├── FEATURE_ANALYSIS.md      # Complete feature inventory (NEW)
    ├── TROUBLESHOOTING.md       # Detailed troubleshooting (NEW)
    └── MIGRATION_GUIDE.md       # Migration guide for existing users (NEW)
```

## 🔧 Available Scripts

### On Server (SSH)

```bash
# Test infrastructure connectivity (NEW!)
./scripts/test-connectivity.sh

# List all registered apps
./scripts/list-apps.sh

# Add an app with path-based routing
./scripts/add-app.sh /home/munaim/apps/myapp /myapp

# Remove an app
./scripts/remove-app.sh myapp

# Restart Traefik
./scripts/restart-proxy.sh

# Rebuild frontend app with base path
./scripts/rebuild-app.sh /home/munaim/apps/myapp /myapp
```

### From Windows (PowerShell)

```powershell
# Deploy everything to server
.\local-scripts\deploy-to-server.ps1

# Add app from Windows
.\local-scripts\quick-add-app.ps1 -AppPath "/home/munaim/apps/myapp" -URLPath "/myapp"

# Quick SSH connection
.\local-scripts\ssh-connect.ps1
```

## 🌐 How Path-Based Routing Works

Your apps will be accessible at:
- `http://<server_host>/consult` → Your consult app
- `http://<server_host>/myapp` → Your myapp
- `http://<server_host>/another` → Another app

All apps run simultaneously on the same server, same IP!

## 📝 What Happens When You Add an App

1. **Backup Created**: Your original `docker-compose.yml` is backed up
2. **Traefik Labels Added**: Automatic routing configuration
3. **Network Connected**: App joins the `web` network
4. **App Restarted**: Container restarts with new config
5. **Registry Updated**: App registered in `apps.json`

### Before:
```yaml
services:
  web:
    image: nginx
    ports:
      - "8080:80"
```

### After:
```yaml
services:
  web:
    image: nginx
    networks:
      - web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`your.host`) && PathPrefix(`/myapp`)"
      - "traefik.http.routers.myapp.entrypoints=web"
      - "traefik.http.services.myapp.loadbalancer.server.port=80"
      - "traefik.http.middlewares.myapp-stripprefix.stripprefix.prefixes=/myapp"
      - "traefik.http.routers.myapp.middlewares=myapp-stripprefix"

networks:
  web:
    external: true
```

## 🔐 Security Notes

1. **Change Traefik Dashboard Password**:
   ```bash
   # Generate new password hash
   sudo apt-get install apache2-utils
   htpasswd -nb admin YOUR_NEW_PASSWORD
   
   # Update docker-compose.yml with the new hash
   ```

2. **Firewall**: The setup script opens ports 22, 80, 443

3. **SSL/HTTPS**: Currently disabled. To enable:
   - Get a domain name
   - Point it to your server IP
   - Uncomment SSL section in `traefik.yml`
   - Update scripts to use domain instead of IP

## 🐛 Troubleshooting

> **📖 See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for comprehensive troubleshooting guide**

### Quick Fixes

#### Dashboard/Apps Not Accessible on Public IP? ✅ FIXED

If you're using an **IP address** (not a domain name) and can't access the dashboard or apps, this is now fixed!

**The Fix**: Updated routing to work with IP addresses without Host header restrictions.

**To apply to existing apps**:
```bash
cd /home/munaim/docker-infrastructure

# Re-add your apps (this updates their routing rules)
./scripts/add-app.sh /home/munaim/apps/consult /consult
./scripts/add-app.sh /home/munaim/apps/lab /lab

# Restart Traefik
./scripts/restart-proxy.sh
```

### App not accessible

```bash
# Check if app is running
cd /home/munaim/apps/YOUR_APP
docker-compose ps

# Check Traefik logs
cd /home/munaim/docker-infrastructure/traefik
docker-compose logs

# Check if app is in web network
docker network inspect web
```

### Traefik not starting

```bash
cd /home/munaim/docker-infrastructure/traefik
docker-compose down
docker-compose up -d
docker-compose logs
```

### Dashboard needs trailing slash

The dashboard must be accessed with a trailing slash:
- ✅ Correct: `http://YOUR_IP/dashboard/`
- ❌ Wrong: `http://YOUR_IP/dashboard`

### List all apps and their status

```bash
cd /home/munaim/docker-infrastructure
./scripts/list-apps.sh
```

## 📊 Monitoring

- **Traefik Dashboard**: `http://<server_host>/dashboard`
  - See all registered apps
  - Monitor traffic
  - Check routing rules

## 🔄 Adding More Apps

Every time you deploy a new app:

1. Put it in `/home/munaim/apps/new-app`
2. Run: `./scripts/add-app.sh /home/munaim/apps/new-app /new-app`
3. Access at: `http://<server_host>/new-app`

That's it! No manual configuration needed.

## 📚 Complete Documentation

This README provides a quick start guide. For detailed information, see:

### 📖 [FEATURE_ANALYSIS.md](FEATURE_ANALYSIS.md)
Complete inventory of all features in the repository:
- ✅ **6 Built and Working Features** - Core functionality that's ready to use
- ⚠️ **5 Built but Needs Debugging** - Features that need attention (with fixes!)
- ❌ **21 Not Built Features** - Roadmap for future development

### 🔧 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
Comprehensive troubleshooting guide covering:
- Dashboard access issues (404, blank page, authentication)
- App connectivity problems (503, 502, connection timeout)
- Firewall and network configuration
- Frontend asset loading issues
- SSL/HTTPS setup
- VPS provider-specific firewall settings
- 11+ common issues with detailed solutions

### 🚀 [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
For existing users updating to the latest version:
- Step-by-step migration instructions
- Understanding what changed and why
- Verification checklist
- Rollback procedures
- Technical details about the fix

### 🧪 Testing Your Setup

Run the connectivity test script:
```bash
cd /home/munaim/docker-infrastructure
./scripts/test-connectivity.sh
```

This will check:
- ✅ Docker and Traefik status
- ✅ Network configuration
- ✅ Port accessibility
- ✅ Dashboard connectivity
- ✅ All registered apps
- ✅ Firewall settings

## 📞 Support

If something doesn't work:
1. **Run diagnostics**: `./scripts/test-connectivity.sh`
2. **Check detailed troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
3. **View Traefik logs**: `cd traefik && docker-compose logs`
4. **View app logs**: `cd /home/munaim/apps/YOUR_APP && docker-compose logs`
5. **Check apps registry**: `./scripts/list-apps.sh` or `cat config/apps.json`
