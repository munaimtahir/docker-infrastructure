# Troubleshooting Guide - Docker Infrastructure

## 🔴 CRITICAL: Dashboard & Apps Not Accessible via Public IP

### Problem
You cannot access the Traefik dashboard or your apps using the public IP address of your VPS.

**Expected**:
- Dashboard: `http://34.93.19.177/dashboard`
- Apps: `http://34.93.19.177/consult`

**Actual**: Connection timeout, 404, or "Bad Gateway"

---

### ✅ SOLUTION

This has been **FIXED** in the latest version. The issue was that Traefik router rules were using `Host()` rules with IP addresses, which caused routing failures.

**What was changed**:
1. **Modified `scripts/add_app_logic.py`** to NOT add Host rules when using IP addresses
2. Apps now use **PathPrefix-only routing** for IP access, making them accessible from any IP/host
3. Host rules are only added when using domain names

**To apply the fix to existing apps**:

```bash
# Re-add all your apps to update their routing rules
cd /home/munaim/docker-infrastructure

# For each app, run:
./scripts/add-app.sh /home/munaim/apps/consult /consult
./scripts/add-app.sh /home/munaim/apps/lab /lab
./scripts/add-app.sh /home/munaim/apps/test-app /test-app

# Restart Traefik
./scripts/restart-proxy.sh
```

---

## Common Issues & Solutions

### 1. Dashboard Returns 404 or Blank Page

**Symptoms**:
- Accessing `/dashboard` shows 404
- Dashboard loads but shows no data
- API errors in browser console

**Causes & Solutions**:

#### A. Missing Trailing Slash
The dashboard needs to be accessed WITH a trailing slash.

```bash
# ❌ Wrong
http://your-ip/dashboard

# ✅ Correct  
http://your-ip/dashboard/
```

**Fix**: Always use `/dashboard/` with trailing slash

#### B. API Endpoint Not Accessible
The dashboard needs both `/dashboard` and `/api` endpoints to work.

**Check**: Verify both routers exist:
```bash
cd /home/munaim/docker-infrastructure/traefik
docker compose logs traefik | grep "router"
```

You should see:
- `Router dashboard`
- `Router dashboard-api`

#### C. Authentication Issues
Wrong password or authentication not working.

**Fix**: Check credentials (default is admin/admin123):
```bash
# Generate new password hash if needed
htpasswd -nb admin YOUR_NEW_PASSWORD

# Update in traefik/docker-compose.yml line 40
```

---

### 2. Apps Not Accessible After Adding

**Symptoms**:
- Added app with `add-app.sh` but getting 404
- App shows in `list-apps.sh` but not accessible
- Traefik dashboard shows no routers for the app

**Solutions**:

#### A. Check App is Running
```bash
cd /home/munaim/apps/YOUR_APP
docker compose ps

# If not running:
docker compose up -d
docker compose logs
```

#### B. Check App is on Web Network
```bash
docker network inspect web

# Should show your app containers
# If not, the app wasn't properly configured
```

**Fix**: Re-run add-app.sh:
```bash
cd /home/munaim/docker-infrastructure
./scripts/add-app.sh /home/munaim/apps/YOUR_APP /your-path
```

#### C. Check Traefik Sees the App
```bash
cd /home/munaim/docker-infrastructure/traefik
docker compose logs | grep "YOUR_APP"
```

Should see messages like:
- "Provider docker: Discovered router YOUR_APP"
- "Router YOUR_APP created"

#### D. Port Detection Wrong
The script auto-detects ports but may get it wrong.

**Check**: Look at your app's docker-compose.yml
```bash
cat /home/munaim/apps/YOUR_APP/docker-compose.yml | grep traefik
```

Look for: `traefik.http.services.YOUR_APP.loadbalancer.server.port=`

**Fix**: Manually edit the port number to match your app's exposed port:
```bash
# Edit the file
nano /home/munaim/apps/YOUR_APP/docker-compose.yml

# Change the port in the Traefik labels
# Then restart:
cd /home/munaim/apps/YOUR_APP
docker compose restart
```

---

### 3. "503 Service Unavailable" Error

**Symptoms**:
- Traefik dashboard works
- Accessing app URL shows "503 Service Unavailable"

**Causes**:

#### A. App Container Not Running
```bash
cd /home/munaim/apps/YOUR_APP
docker compose ps

# Check status - should be "Up"
# If exited or restarting:
docker compose logs
```

**Common causes**:
- App crashed on startup
- Port already in use
- Missing environment variables
- Build failed

**Fix**: Check logs and fix the app issue, then restart:
```bash
docker compose up -d
```

#### B. Wrong Port in Traefik Config
Traefik is trying to connect to wrong port.

**Fix**: See "Port Detection Wrong" above

#### C. App Not Listening on Correct Interface
Some apps only listen on localhost (127.0.0.1) instead of all interfaces (0.0.0.0).

**Fix**: Update your app to listen on `0.0.0.0` or `::`:
```javascript
// Node/Express example
app.listen(80, '0.0.0.0');  // ✅ Correct

// NOT this:
app.listen(80, 'localhost');  // ❌ Won't work
```

---

### 4. "Bad Gateway" Error

**Symptoms**:
- Error 502 Bad Gateway
- Traefik can't connect to backend

**Solutions**:

#### A. App Not on Same Network
```bash
docker network inspect web
```

**Fix**: Ensure app's docker-compose.yml has:
```yaml
networks:
  - web

networks:
  web:
    external: true
```

#### B. Container Name Mismatch
Traefik connects using container names.

**Check**: Ensure your docker-compose.yml has predictable container names:
```yaml
services:
  web:
    container_name: your-app-web  # Good practice
```

---

### 5. Firewall Blocking Access

**Symptoms**:
- Everything works locally (from server)
- External access times out
- No error, just timeout

**Check Firewall**:
```bash
sudo ufw status

# Should show:
# 80/tcp     ALLOW       Anywhere
# 443/tcp    ALLOW       Anywhere
```

**Fix**:
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

**Check if Traefik is listening**:
```bash
sudo netstat -tlnp | grep :80

# Should show:
# tcp6  0  0  :::80  :::*  LISTEN  PID/docker-proxy
```

---

### 6. VPS Provider Firewall

Some VPS providers (Google Cloud, AWS, Azure) have **external firewalls** in addition to UFW.

**Google Cloud**:
1. Go to Google Cloud Console
2. Navigate to VPC Network → Firewall
3. Ensure rules allow ingress on ports 80 and 443
4. Source IP ranges: `0.0.0.0/0` (or specific IPs)

**AWS**:
1. Check Security Groups
2. Ensure inbound rules allow TCP 80 and 443
3. From 0.0.0.0/0 (or specific IPs)

**Digital Ocean**:
1. Check Cloud Firewalls
2. Ensure HTTP and HTTPS are allowed

---

### 7. Wrong IP Address Detected

**Symptoms**:
- Scripts detect internal IP instead of public IP
- Apps registered with wrong IP in apps.json

**Check Current Detection**:
```bash
hostname -I | awk '{print $1}'
```

**Get Public IP**:
```bash
curl -4 ifconfig.me
```

**Fix**: Set SERVER_HOST manually:
```bash
# Before running scripts
export SERVER_HOST=34.93.19.177

# Or your domain
export SERVER_HOST=yourdomain.com

# Then run your commands
./scripts/add-app.sh /home/munaim/apps/consult /consult
```

---

### 8. Frontend Assets Not Loading (404 on JS/CSS)

**Symptoms**:
- App page loads but is blank
- Browser console shows 404 errors for .js, .css files
- Network tab shows failed requests to `/assets/...`

**Cause**: Frontend app built without correct base path.

**Solutions**:

#### For Vite Apps:
```javascript
// vite.config.js
export default {
  base: '/consult/',  // Must match your URL path!
}
```

Then rebuild:
```bash
cd /home/munaim/apps/consult/frontend
npm run build
cd /home/munaim/apps/consult
docker compose up -d --build
```

#### For Create React App:
```json
// package.json
{
  "homepage": "/consult"
}
```

Then rebuild:
```bash
cd /home/munaim/apps/consult/frontend
npm run build
cd /home/munaim/apps/consult
docker compose up -d --build
```

#### Use Rebuild Script:
```bash
cd /home/munaim/docker-infrastructure
./scripts/rebuild-app.sh /home/munaim/apps/consult /consult
```

---

### 9. Traefik Won't Start

**Symptoms**:
```bash
docker compose ps
# Shows: Exit 1
```

**Check Logs**:
```bash
cd /home/munaim/docker-infrastructure/traefik
docker compose logs
```

**Common Causes**:

#### A. Port 80 Already in Use
```bash
sudo netstat -tlnp | grep :80
```

**Fix**: Stop the service using port 80:
```bash
# If Apache is running:
sudo systemctl stop apache2

# If Nginx is running:
sudo systemctl stop nginx
```

#### B. Invalid Configuration
Syntax error in traefik.yml or docker-compose.yml

**Fix**: Validate YAML syntax:
```bash
# Check docker-compose.yml
docker compose config

# Should show the parsed config without errors
```

#### C. Docker Socket Permission
Traefik needs access to Docker socket.

**Fix**: Ensure docker.sock has correct permissions:
```bash
ls -la /var/run/docker.sock
# Should be readable

# Add user to docker group if needed:
sudo usermod -aG docker munaim
# Then log out and back in
```

#### D. acme.json Wrong Permissions
```bash
cd /home/munaim/docker-infrastructure/traefik
chmod 600 acme.json
```

---

### 10. Apps Showing Old Content

**Symptoms**:
- Updated app code but seeing old version
- Docker container shows new code but browser shows old

**Solutions**:

#### A. Browser Cache
Hard refresh: `Ctrl+Shift+R` (or `Cmd+Shift+R` on Mac)

#### B. Docker Image Cache
Rebuild without cache:
```bash
cd /home/munaim/apps/YOUR_APP
docker compose down
docker compose build --no-cache
docker compose up -d
```

#### C. Volume Mounts
If using volumes, ensure new files are mounted:
```bash
docker compose down -v  # Remove volumes
docker compose up -d
```

---

### 11. SSL/HTTPS Not Working

**Note**: SSL is currently disabled by default.

**To enable SSL** (requires domain name):

1. **Get a domain** and point it to your VPS IP
2. **Update scripts** to use domain:
   ```bash
   export SERVER_HOST=yourdomain.com
   ```

3. **Enable Let's Encrypt** in `traefik/traefik.yml`:
   ```yaml
   certificatesResolvers:
     letsencrypt:
       acme:
         email: your-email@example.com
         storage: /acme.json
         httpChallenge:
           entryPoint: web
   ```

4. **Update routers** to use websecure entrypoint
5. **Add HTTPS redirect** middleware
6. **Restart Traefik**

---

## Quick Diagnostic Commands

### Check Everything is Running
```bash
# Traefik status
cd /home/munaim/docker-infrastructure/traefik
docker compose ps

# All apps
cd /home/munaim/docker-infrastructure
./scripts/list-apps.sh
```

### Check Networks
```bash
# Web network details
docker network inspect web

# All networks
docker network ls
```

### Check Routing Rules
```bash
# Traefik logs (last 50 lines)
cd /home/munaim/docker-infrastructure/traefik
docker compose logs --tail=50

# Live logs (follow)
docker compose logs -f
```

### Test Connectivity
```bash
# From the server itself
curl -I http://localhost/dashboard/

# Should return: HTTP/1.1 401 Unauthorized (auth required - this is good!)

# Test app
curl -I http://localhost/consult

# With authentication for dashboard
curl -u admin:admin123 http://localhost/dashboard/
```

### Check Open Ports
```bash
# Listening ports
sudo netstat -tlnp

# Firewall status
sudo ufw status verbose
```

---

## Getting Help

If you're still stuck after trying these solutions:

1. **Collect Information**:
   ```bash
   # System info
   uname -a
   docker --version
   docker compose version
   
   # Traefik logs
   cd /home/munaim/docker-infrastructure/traefik
   docker compose logs > /tmp/traefik-logs.txt
   
   # App logs
   cd /home/munaim/apps/YOUR_APP
   docker compose logs > /tmp/app-logs.txt
   
   # Network info
   docker network inspect web > /tmp/network-info.txt
   
   # Apps registry
   cat /home/munaim/docker-infrastructure/config/apps.json
   ```

2. **Share Details**:
   - Your VPS provider (Google Cloud, AWS, DigitalOcean, etc.)
   - Public IP address
   - Which app is having issues
   - Error messages from logs
   - What you've already tried

3. **Test URLs**:
   - Dashboard: http://YOUR_IP/dashboard/
   - Apps: http://YOUR_IP/YOUR_PATH

---

## Security Checklist

After getting everything working, remember to:

- [ ] Change default Traefik dashboard password
- [ ] Review firewall rules
- [ ] Set up SSL/HTTPS if using domain
- [ ] Restrict dashboard access if needed
- [ ] Review app security
- [ ] Set up regular backups
- [ ] Enable Traefik access logs for monitoring
- [ ] Review Docker security best practices

---

## Performance Tips

1. **Monitor resource usage**:
   ```bash
   docker stats
   ```

2. **Clean up old images**:
   ```bash
   docker system prune -a
   ```

3. **Check disk space**:
   ```bash
   df -h
   ```

4. **Optimize Traefik**:
   - Enable access log only when debugging
   - Use production log level (ERROR or WARN)
   - Consider using Traefik metrics for monitoring
