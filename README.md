# Traefik Multi-App Infrastructure

Automated setup for running multiple Docker applications behind Traefik reverse proxy with path-based routing.

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
│   └── restart-proxy.sh         # Restart Traefik
└── config/
    └── apps.json                # Registry of apps
```

## 🔧 Available Scripts

### On Server (SSH)

```bash
# List all registered apps
./scripts/list-apps.sh

# Add an app with path-based routing
./scripts/add-app.sh /home/munaim/apps/myapp /myapp

# Remove an app
./scripts/remove-app.sh myapp

# Restart Traefik
./scripts/restart-proxy.sh
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

## 📞 Support

If something doesn't work:
1. Check the troubleshooting section above
2. View Traefik logs: `docker-compose logs` in traefik directory
3. View app logs: `docker-compose logs` in app directory
4. Check apps registry: `cat /home/munaim/docker-infrastructure/config/apps.json`
