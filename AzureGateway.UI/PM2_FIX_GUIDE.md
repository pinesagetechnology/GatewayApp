# PM2 Fix Guide - Permanent Solution

## 🎯 The Problem

You're getting `Failed to start pm2-pi.service` because the PM2 systemd service was configured incorrectly during initial deployment.

## ✅ The Solution (One Script Fixes Everything)

I've created a comprehensive fix script that will:
- Clean up all broken PM2 configurations
- Remove faulty systemd services
- Set up PM2 correctly
- Configure automatic startup properly
- Verify everything works

## 🚀 How to Fix (3 Easy Steps)

### Step 1: Run the Fix Script

```bash
cd AzureGateway.UI
bash scripts/fix-all-pm2-issues.sh
```

**Important**: Run as your regular user (alirk), NOT with sudo. The script will ask for sudo when needed.

### Step 2: Verify Everything Works

After the script completes, you should see:

```
✓ PM2 is now properly configured!

Current Status:
┌────┬───────────┬─────────┬─────────┬──────────┬────────┐
│ id │ name      │ status  │ restart │ uptime   │ cpu    │
├────┼───────────┼─────────┼─────────┼──────────┼────────┤
│ 0  │ ui-app    │ online  │ 0       │ 2s       │ 0%     │
└────┴───────────┴─────────┴─────────┴──────────┴────────┘

Service: active (running)
```

### Step 3: Test Automatic Startup

```bash
# Reboot to verify everything starts automatically
sudo reboot
```

After reboot:
- PM2 should start automatically
- Your app should be running
- Kiosk mode should launch

## 🔍 Manual Verification (Optional)

If you want to check each component:

```bash
# Check PM2 service
sudo systemctl status pm2-alirk.service

# Check PM2 apps
pm2 list

# Check web app
curl http://localhost

# Check nginx
sudo systemctl status nginx

# Check kiosk (after reboot)
sudo systemctl status kiosk.service
```

## ❓ What If Something Goes Wrong?

### If the fix script fails:

1. **Share the error message** - The script shows exactly what went wrong
2. **Check the logs**:
   ```bash
   sudo journalctl -u pm2-alirk.service -n 50
   ```

### If PM2 apps won't start:

```bash
# Check if ecosystem file exists
ls -la /opt/react-ui-app/ecosystem.config.js

# Try starting manually
cd /opt/react-ui-app
pm2 start ecosystem.config.js
pm2 logs
```

### If the service still fails:

```bash
# Run the detailed setup script
bash scripts/setup-pm2-properly.sh
```

## 📚 What Was Fixed?

### In the Scripts:

1. **`fix-all-pm2-issues.sh`** (NEW)
   - One-script solution that fixes everything
   - Cleans up broken configurations
   - Sets up PM2 correctly
   - Verifies everything works

2. **`rpi5-deploy.sh`** (UPDATED)
   - Fixed PM2 startup command (was using wrong syntax)
   - Now runs PM2 as the correct user
   - Properly saves PM2 configuration
   - Enables and starts the systemd service

3. **`kiosk-chromium-setup.sh`** (UPDATED)
   - Now properly detects your username (alirk, not pi)
   - Validates user exists before proceeding
   - No more hardcoded 'pi' user

### Technical Details:

**Before (Broken)**:
```bash
sudo pm2 startup systemd -u alirk --hp /home/alirk  # Wrong!
```

**After (Fixed)**:
```bash
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u alirk --hp /home/alirk  # Correct!
pm2 save  # Must save after starting apps
```

The fix also ensures:
- PM2 runs as `alirk` user, not root
- Process list is saved before creating systemd service
- Systemd service is properly enabled and started
- Service file uses correct paths and environment

## 🎉 Future Deployments

For future deployments or new devices, the updated `rpi5-deploy.sh` script will now work correctly from the start. No more PM2 issues!

---

**Ready to fix it? Run:**
```bash
cd AzureGateway.UI
bash scripts/fix-all-pm2-issues.sh
```

