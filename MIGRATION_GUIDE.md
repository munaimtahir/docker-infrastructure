# Migration Guide - Applying the Public IP Access Fix

## 🎯 What Changed?

The December 2025 update fixed the critical issue where Traefik dashboard and apps were not accessible via public IP addresses.

**The Problem**: Apps were configured with `Host()` rules that required exact Host header matches, which failed when accessing via IP addresses.

**The Fix**: Host rules are now only used for domain names, not IP addresses. This allows apps to be accessible from any IP.

---

## 📋 Who Needs to Migrate?

You need to follow this guide if:
- ✅ You have an existing installation with apps already added
- ✅ You're using IP address access (not a domain name)
- ✅ Your apps are not accessible via public IP
- ✅ You want to update to the latest configuration

You **DON'T** need to migrate if:
- ❌ This is a fresh installation (the fix is already included)
- ❌ Everything is working fine for you
- ❌ You're using a domain name (migration won't hurt, but not critical)

---

## 🚀 Quick Migration (Recommended)

This is the fastest way to apply the fix to all your apps.

### Step 1: Update the Infrastructure Files

SSH to your server and pull the latest changes:

```bash
# SSH to your server
ssh munaim@YOUR_SERVER_IP

# Navigate to infrastructure directory
cd /home/munaim/docker-infrastructure

# Backup current configuration
cp -r /home/munaim/docker-infrastructure /home/munaim/docker-infrastructure.backup.$(date +%Y%m%d_%H%M%S)

# Pull latest changes (if using git)
git pull

# Or manually update add_app_logic.py from the repository
```

### Step 2: Test the Infrastructure

```bash
# Run the new test script
cd /home/munaim/docker-infrastructure
chmod +x scripts/test-connectivity.sh
./scripts/test-connectivity.sh
```

This will show you:
- ✅ Which services are running
- ✅ Which apps are accessible
- ✅ Any configuration issues

### Step 3: Update Each App

For **each app** you have registered, re-run the add-app script:

```bash
cd /home/munaim/docker-infrastructure

# List your current apps
./scripts/list-apps.sh

# Re-add each app (example)
./scripts/add-app.sh /home/munaim/apps/consult /consult
./scripts/add-app.sh /home/munaim/apps/lab /lab
./scripts/add-app.sh /home/munaim/apps/test-app /test-app
```

**What this does**:
- Creates a new backup of your docker-compose.yml
- Updates Traefik labels with the new routing configuration
- Restarts the app container

### Step 4: Restart Traefik

```bash
cd /home/munaim/docker-infrastructure
./scripts/restart-proxy.sh
```

### Step 5: Test Access

Try accessing your services:

```bash
# Dashboard (use trailing slash!)
curl -I http://YOUR_SERVER_IP/dashboard/

# Should return: HTTP/1.1 401 Unauthorized (this is good - auth is working)

# With authentication
curl -u admin:admin123 http://YOUR_SERVER_IP/dashboard/

# Test your apps
curl -I http://YOUR_SERVER_IP/consult
curl -I http://YOUR_SERVER_IP/lab
```

**From your browser**:
- Dashboard: `http://YOUR_SERVER_IP/dashboard/` (note the trailing slash!)
- Apps: `http://YOUR_SERVER_IP/consult`

---

## 🔍 Detailed Migration (Manual Verification)

If you want to understand what's changing or need to troubleshoot, follow this detailed guide.

### Understanding the Change

**Before (Old Configuration)**:
```yaml
# In docker-compose.yml of your app
labels:
  - "traefik.http.routers.consult.rule=Host(`34.93.19.177`) && PathPrefix(`/consult`)"
```

**After (New Configuration)**:
```yaml
# In docker-compose.yml of your app
labels:
  - "traefik.http.routers.consult.rule=PathPrefix(`/consult`)"
```

The `Host()` rule is removed for IP addresses.

### Manual Steps

#### 1. Update add_app_logic.py

Replace your `/home/munaim/docker-infrastructure/scripts/add_app_logic.py` with the new version that includes:

```python
import re

def _is_ip_address(host):
    """Check if the host is an IP address (IPv4 or IPv6)"""
    ipv4_pattern = r'^(\d{1,3}\.){3}\d{1,3}$'
    ipv6_pattern = r'^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$'
    return bool(re.match(ipv4_pattern, host) or re.match(ipv6_pattern, host))
```

And updated routing logic:
```python
use_host_rule = server_host and not _is_ip_address(server_host)
host_rule_prefix = f"Host(`{server_host}`) && " if use_host_rule else ""
```

#### 2. Verify App Configurations

For each app, check the current configuration:

```bash
cd /home/munaim/apps/consult
cat docker-compose.yml | grep "traefik.http.routers"
```

Look for lines with `Host()` rules. These need to be updated.

#### 3. Manual Update (Alternative to re-running add-app.sh)

If you prefer to manually edit:

```bash
cd /home/munaim/apps/YOUR_APP
nano docker-compose.yml
```

Find the line:
```yaml
- "traefik.http.routers.APPNAME.rule=Host(`IP.ADD.RE.SS`) && PathPrefix(`/path`)"
```

Change to:
```yaml
- "traefik.http.routers.APPNAME.rule=PathPrefix(`/path`)"
```

Save and restart:
```bash
docker compose restart
```

#### 4. Verify Changes

```bash
# Check Traefik sees the new configuration
cd /home/munaim/docker-infrastructure/traefik
docker compose logs | grep "router.*YOUR_APP"

# Should see something like:
# "Router YOUR_APP created with rule: PathPrefix(`/your-path`)"
```

---

## ✅ Verification Checklist

After migration, verify everything works:

- [ ] Dashboard accessible at `http://YOUR_IP/dashboard/` (with trailing slash)
- [ ] Dashboard login works (admin/admin123 by default)
- [ ] All apps accessible at `http://YOUR_IP/<app-path>`
- [ ] Apps load correctly (no 404 on assets)
- [ ] Traefik shows all routers in dashboard
- [ ] Test from external network (not just localhost)
- [ ] Run `./scripts/test-connectivity.sh` - all tests pass

---

## 🐛 Troubleshooting Migration Issues

### Apps Still Not Accessible

**Check the routing rule**:
```bash
cd /home/munaim/apps/YOUR_APP
cat docker-compose.yml | grep "rule="
```

Should NOT have `Host()` if using IP address.

**Fix**: Re-run add-app.sh:
```bash
cd /home/munaim/docker-infrastructure
./scripts/add-app.sh /home/munaim/apps/YOUR_APP /your-path
```

### Dashboard Shows 404

Make sure you're using the **trailing slash**:
- ❌ `http://IP/dashboard`
- ✅ `http://IP/dashboard/`

### "Service Unavailable" (503)

App container might not be running:
```bash
cd /home/munaim/apps/YOUR_APP
docker compose ps

# If not running:
docker compose up -d
docker compose logs
```

### Apps Work Locally But Not Externally

Check your VPS provider's firewall:

**Google Cloud**:
```bash
# Check firewall rules in GCP Console
# VPC Network → Firewall → Ensure port 80 is allowed
```

**AWS**:
```bash
# Check Security Groups
# Ensure inbound rule for port 80 from 0.0.0.0/0
```

**DigitalOcean**:
```bash
# Check Cloud Firewalls
# Ensure HTTP (80) and HTTPS (443) are allowed
```

### Old Configuration Still Active

Clear Docker's cache and restart:
```bash
cd /home/munaim/apps/YOUR_APP
docker compose down
docker compose up -d --force-recreate
```

---

## 🔄 Rollback Plan

If something goes wrong, you can rollback:

### Option 1: Restore from Backup

```bash
# Each add-app.sh creates a backup
cd /home/munaim/apps/YOUR_APP
ls -la docker-compose.yml.backup.*

# Restore from most recent backup
cp docker-compose.yml.backup.YYYYMMDD_HHMMSS docker-compose.yml

# Restart app
docker compose restart
```

### Option 2: Full Infrastructure Restore

```bash
# Restore from the backup we made at the start
sudo rm -rf /home/munaim/docker-infrastructure
sudo mv /home/munaim/docker-infrastructure.backup.YYYYMMDD_HHMMSS /home/munaim/docker-infrastructure

# Restart Traefik
cd /home/munaim/docker-infrastructure/traefik
docker compose restart
```

---

## 📊 Migration Timeline

Expected time to complete:

- **Step 1** (Update files): 2-5 minutes
- **Step 2** (Test): 1 minute
- **Step 3** (Update apps): 1-2 minutes per app
- **Step 4** (Restart Traefik): 30 seconds
- **Step 5** (Verification): 2-5 minutes

**Total**: ~10-20 minutes for a typical installation with 3-5 apps

---

## 🎓 Understanding the Technical Details

### Why Host Rules Don't Work with IPs

When you access a service via IP address (e.g., `http://34.93.19.177/consult`), the HTTP request includes a `Host` header set to that IP.

**The Problem**: Traefik's `Host()` rule does exact string matching. Any variation causes routing to fail:
- Different IP (internal vs external)
- Port included (e.g., `34.93.19.177:80`)
- Localhost access
- DNS vs direct IP

**The Solution**: For IP-based access, we use **PathPrefix-only routing**, which matches based on the URL path, not the Host header. This is more flexible and works with any IP/hostname.

### When to Use Host Rules

Host rules are **still useful** for:
- **Domain names**: `Host(`example.com`)`
- **Multiple domains**: Different apps on different domains
- **Subdomains**: `Host(`app1.example.com`)`
- **Security**: Restricting access to specific domains

**New behavior**:
- IP address → No Host rule (flexible access)
- Domain name → Host rule (strict matching)

---

## 📚 Additional Resources

- **Complete troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Feature documentation**: See [FEATURE_ANALYSIS.md](FEATURE_ANALYSIS.md)
- **Main README**: See [README.md](README.md)

---

## 💬 Need Help?

If you encounter issues during migration:

1. **Run the diagnostic script**:
   ```bash
   ./scripts/test-connectivity.sh
   ```

2. **Check Traefik logs**:
   ```bash
   cd /home/munaim/docker-infrastructure/traefik
   docker compose logs --tail=100
   ```

3. **Verify network**:
   ```bash
   docker network inspect web
   ```

4. **Review routing rules**:
   - Go to `http://YOUR_IP/dashboard/`
   - Check HTTP → Routers section
   - Verify each app has a router with correct rule

---

## 🎉 Success!

Once everything is working:

1. **Change default password**:
   ```bash
   # Generate new password hash
   htpasswd -nb admin YOUR_NEW_PASSWORD
   
   # Update in traefik/docker-compose.yml
   ```

2. **Document your setup**:
   - List of apps and their paths
   - Any custom configurations
   - Backup procedures

3. **Set up monitoring** (optional):
   - Review Traefik dashboard regularly
   - Monitor container health
   - Set up log rotation

4. **Consider SSL** (when you have a domain):
   - Get a domain name
   - Point it to your server IP
   - Enable Let's Encrypt in Traefik configuration
   - Update app URLs to use domain

Happy deploying! 🚀
