# Kiosk Mode Setup Guide for Raspberry Pi

This guide provides comprehensive instructions for setting up your React web application as a kiosk on Raspberry Pi or similar IoT devices.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Option 1: Chromium Kiosk Mode (Recommended)](#option-1-chromium-kiosk-mode-recommended)
4. [Option 2: Electron Kiosk Mode](#option-2-electron-kiosk-mode)
5. [Security & Hardening](#security--hardening)
6. [Troubleshooting](#troubleshooting)
7. [Maintenance](#maintenance)

---

## Overview

### Comparison of Approaches

| Feature | Chromium Kiosk | Electron Kiosk |
|---------|----------------|----------------|
| **Resource Usage** | Lightweight (~200MB RAM) | Moderate (~300-400MB RAM) |
| **Setup Complexity** | Simple | Moderate |
| **Control Level** | Basic | Advanced |
| **Offline Support** | Requires nginx | Native |
| **Custom Branding** | Limited | Full |
| **Update Process** | Simple (just rebuild) | Rebuild + repackage |
| **Development Tools** | Browser DevTools | Electron DevTools |
| **Best For** | Web-first apps, minimal resources | Desktop-like experience, custom features |

### Which One to Choose?

- **Choose Chromium** if:
  - You want the lightest setup
  - Your app is purely web-based
  - You're already using Nginx
  - Quick updates are important

- **Choose Electron** if:
  - You need offline capabilities
  - You want full control over the environment
  - You need system-level integrations
  - You want a true desktop app experience

---

## Prerequisites

### Hardware Requirements
- Raspberry Pi 3, 4, or 5 (or similar ARM device)
- 2GB+ RAM recommended
- 16GB+ SD card
- Monitor/display with HDMI connection
- Keyboard (for initial setup)

### Software Requirements
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y git curl wget
```

### Deploy Your App First
Before setting up kiosk mode, ensure your React app is deployed and accessible at `http://localhost`:

```bash
cd AzureGateway.UI
bash scripts/rpi5-deploy.sh
```

Verify it's working by visiting `http://localhost` from a browser on the Raspberry Pi.

---

## Option 1: Chromium Kiosk Mode (Recommended)

### Step 1: Run the Setup Script

```bash
cd AzureGateway.UI
sudo bash scripts/kiosk-chromium-setup.sh
```

This script will:
- ✅ Install Chromium browser and X11 dependencies
- ✅ Disable screen blanking and power management
- ✅ Create a kiosk startup script
- ✅ Set up systemd service for auto-start
- ✅ Configure autologin
- ✅ Create watchdog for automatic recovery
- ✅ Install emergency exit tools

### Step 2: Reboot

```bash
sudo reboot
```

After reboot, the system will:
1. Auto-login as the configured user
2. Start X server
3. Launch Chromium in full-screen kiosk mode
4. Load your app at `http://localhost`

### Step 3: Verify

The screen should show your React app in full-screen mode with:
- ❌ No address bar
- ❌ No browser UI
- ❌ No ability to exit (by design)

### Configuration Options

To customize the kiosk, edit `/home/pi/start-kiosk.sh`:

```bash
# Change the URL
# Replace http://localhost with your desired URL
chromium-browser --kiosk http://YOUR_URL_HERE

# Adjust zoom level (useful for different screen resolutions)
chromium-browser --kiosk --force-device-scale-factor=1.2 http://localhost

# Enable touch screen support
chromium-browser --kiosk --touch-events=enabled http://localhost
```

### Management Commands

```bash
# View kiosk status
sudo systemctl status kiosk.service

# View logs
sudo journalctl -u kiosk.service -f

# Stop kiosk (for maintenance)
sudo systemctl stop kiosk.service

# Emergency exit (kills everything)
sudo /usr/local/bin/exit-kiosk

# Update your app
sudo /usr/local/bin/update-kiosk-app

# Restart kiosk
sudo systemctl restart kiosk.service
```

### Accessing Terminal for Maintenance

Since the GUI is locked, use these methods:

**Method 1: SSH from another computer**
```bash
ssh pi@<raspberry-pi-ip>
```

**Method 2: Virtual terminal (from the Pi itself)**
- Press `Ctrl+Alt+F2` to switch to terminal
- Login with your credentials
- Press `Ctrl+Alt+F7` to return to GUI

---

## Option 2: Electron Kiosk Mode

### Step 1: Run Electron Setup

```bash
cd AzureGateway.UI
bash scripts/kiosk-electron-setup.sh
```

This will:
- ✅ Install Electron and dependencies
- ✅ Create Electron main process
- ✅ Update package.json with Electron scripts
- ✅ Create helper scripts
- ✅ Set up systemd service

### Step 2: Test in Development Mode

Before deploying, test the Electron app:

```bash
npm run electron:dev
```

This will:
1. Start the webpack dev server
2. Launch Electron with your app
3. Open DevTools for debugging

Press `Ctrl+C` in terminal to exit.

### Step 3: Build Production Version

```bash
npm run electron:build
```

This creates a production build in `electron-dist/` directory.

### Step 4: Set Up Autostart

If not running as root during setup, manually create the systemd service:

```bash
sudo bash scripts/kiosk-chromium-setup.sh
# Then follow the autologin steps from that script
```

Or manually configure:

```bash
# Enable autologin
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I \$TERM
EOF

# Reload systemd
sudo systemctl daemon-reload

# Start Electron on login by adding to ~/.bashrc
echo 'if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then startx -- :0 vt1; fi' >> ~/.bashrc

# Create .xinitrc
echo 'cd ~/AzureGateway.UI && npm run electron:start' > ~/.xinitrc
chmod +x ~/.xinitrc
```

### Step 5: Reboot

```bash
sudo reboot
```

### Management Commands

```bash
# Start kiosk
./start-electron-kiosk.sh

# Stop kiosk
./exit-electron-kiosk.sh

# Restart kiosk
./restart-electron-kiosk.sh

# View logs
sudo journalctl -u electron-kiosk.service -f

# Update app
npm run build && sudo systemctl restart electron-kiosk.service
```

### Customizing Electron Kiosk

Edit `electron.js` to customize behavior:

```javascript
// Enable touch screen
mainWindow = new BrowserWindow({
  fullscreen: true,
  kiosk: true,
  frame: false,
  webPreferences: {
    // ... existing config
  },
  // Add touch support
  touchBar: null,
});

// Change window size (for testing)
mainWindow = new BrowserWindow({
  width: 1920,
  height: 1080,
  fullscreen: false, // Set to false for windowed mode
  // ...
});

// Add custom splash screen
mainWindow.loadURL('file://' + __dirname + '/splash.html');
setTimeout(() => {
  mainWindow.loadURL(startUrl);
}, 3000);
```

---

## Security & Hardening

### Disable Unused Services

```bash
# Disable Bluetooth (if not needed)
sudo systemctl disable bluetooth.service

# Disable WiFi (if using ethernet)
sudo systemctl disable wpa_supplicant.service

# Disable sound (if not needed)
sudo systemctl disable alsa-state.service
```

### Firewall Configuration

```bash
# Install UFW
sudo apt install -y ufw

# Configure firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 192.168.1.0/24 to any port 22  # SSH from local network only
sudo ufw allow 80/tcp  # HTTP (if needed from outside)
sudo ufw enable
```

### Prevent Physical Access Exploits

```bash
# Disable USB storage auto-mount
sudo systemctl mask udisks2.service

# Lock down sudo access
# Edit /etc/sudoers.d/kiosk-user
sudo visudo -f /etc/sudoers.d/kiosk-user
# Add: pi ALL=(ALL) NOPASSWD: /bin/systemctl restart kiosk.service
# This allows only specific sudo commands without password
```

### Screen Rotation (if needed)

```bash
# Rotate screen 90 degrees
sudo nano /boot/config.txt
# Add: display_rotate=1  # 0=normal, 1=90°, 2=180°, 3=270°

# Or for X11 only
xrandr --output HDMI-1 --rotate left
```

---

## Troubleshooting

### Blank Screen on Boot

**Problem**: Screen stays black after reboot

**Solutions**:
```bash
# SSH into the device and check logs
sudo journalctl -u kiosk.service -n 50

# Check if X server is running
ps aux | grep X

# Check if Chromium is running
ps aux | grep chromium

# Restart the service
sudo systemctl restart kiosk.service
```

### App Not Loading

**Problem**: Chromium starts but shows "Cannot connect"

**Check**:
```bash
# Verify nginx is running
sudo systemctl status nginx

# Check if app is accessible
curl http://localhost

# Check nginx logs
sudo tail -f /var/log/nginx/error.log

# Restart nginx
sudo systemctl restart nginx
```

### Screen Goes Black (Screen Saver)

**Problem**: Screen blanks after inactivity

**Fix**:
```bash
# Add to /home/pi/start-kiosk.sh (before chromium-browser line)
xset s off
xset s noblank
xset -dpms

# Restart kiosk
sudo systemctl restart kiosk.service
```

### Mouse Cursor Visible

**Problem**: Mouse cursor appears on screen

**Fix**:
```bash
# Install unclutter if not already installed
sudo apt install -y unclutter

# Verify it's in start-kiosk.sh
grep unclutter /home/pi/start-kiosk.sh

# Should see: unclutter -idle 0.1 -root &
```

### Keyboard Shortcuts Still Work

**Problem**: User can press Alt+F4 or other shortcuts

**Additional Hardening**:
```bash
# Install matchbox window manager (more restrictive)
sudo apt install -y matchbox-window-manager

# Edit start-kiosk.sh
nano /home/pi/start-kiosk.sh

# Add before chromium-browser:
matchbox-window-manager &
```

### Electron Won't Start

**Problem**: Electron kiosk service fails

**Check**:
```bash
# View detailed error
sudo journalctl -u electron-kiosk.service -n 100

# Common issues:
# 1. Missing dependencies
cd AzureGateway.UI
npm install

# 2. Build not created
npm run build

# 3. Permission issues
sudo chown -R pi:pi /home/pi/AzureGateway.UI
```

### App Crashes Frequently

**Problem**: Kiosk keeps restarting

**Solutions**:
```bash
# Increase memory
# Edit /etc/dphys-swapfile
sudo nano /etc/dphys-swapfile
# Set: CONF_SWAPSIZE=2048
sudo dphys-swapfile setup
sudo dphys-swapfile swapon

# Check for memory leaks in app
npm run build  # Rebuild with production optimizations

# Reduce resource usage in Chromium
# Edit start-kiosk.sh, add flags:
chromium-browser --kiosk \
  --disable-gpu \
  --disable-software-rasterizer \
  --disable-dev-shm-usage \
  http://localhost
```

---

## Maintenance

### Updating Your App

**For Chromium Kiosk**:
```bash
# Method 1: Use update script
sudo /usr/local/bin/update-kiosk-app

# Method 2: Manual update
sudo systemctl stop kiosk.service
cd /opt/react-ui-app
# Copy your new build files
sudo cp -r /path/to/new/dist/* ./dist/
sudo systemctl start kiosk.service
```

**For Electron Kiosk**:
```bash
cd AzureGateway.UI
npm run build
npm run electron:build
sudo systemctl restart electron-kiosk.service
```

### Remote Updates

Set up automatic updates from a git repository:

```bash
# Create update script
sudo tee /usr/local/bin/remote-update-kiosk <<'EOF'
#!/bin/bash
cd /opt/react-ui-app
git pull origin main
npm install
npm run build
systemctl restart kiosk.service
logger "Kiosk app updated from remote"
EOF

sudo chmod +x /usr/local/bin/remote-update-kiosk

# Create cron job for automatic updates (optional)
sudo crontab -e
# Add: 0 2 * * * /usr/local/bin/remote-update-kiosk
# This updates daily at 2 AM
```

### Monitoring & Logging

```bash
# View all kiosk-related logs
sudo journalctl -u kiosk.service --since today

# Watch logs in real-time
sudo journalctl -u kiosk.service -f

# Check system resources
htop

# Monitor temperature (Raspberry Pi)
vcgencmd measure_temp

# Check disk space
df -h
```

### Backup & Restore

```bash
# Backup kiosk configuration
sudo tar -czf kiosk-backup-$(date +%Y%m%d).tar.gz \
  /home/pi/start-kiosk.sh \
  /etc/systemd/system/kiosk.service \
  /usr/local/bin/kiosk-watchdog.sh \
  /opt/react-ui-app

# Restore
sudo tar -xzf kiosk-backup-20240101.tar.gz -C /
sudo systemctl daemon-reload
```

### Factory Reset

```bash
# Remove all kiosk components
sudo systemctl stop kiosk.service
sudo systemctl disable kiosk.service
sudo rm /etc/systemd/system/kiosk.service
sudo rm /home/pi/start-kiosk.sh
sudo rm -rf /opt/react-ui-app
sudo systemctl daemon-reload

# Remove autologin
sudo rm -rf /etc/systemd/system/getty@tty1.service.d/
sudo systemctl daemon-reload

# Reboot to normal desktop
sudo reboot
```

---

## Advanced Configuration

### Multiple Displays

If you have multiple monitors:

```bash
# Edit start-kiosk.sh
nano /home/pi/start-kiosk.sh

# Add display configuration
xrandr --output HDMI-1 --primary --mode 1920x1080
xrandr --output HDMI-2 --right-of HDMI-1 --mode 1920x1080

# Start Chromium with specific window position
chromium-browser --kiosk --window-position=0,0 http://localhost
```

### Touch Screen Calibration

```bash
# Install calibration tool
sudo apt install -y xinput-calibrator

# Stop kiosk temporarily
sudo systemctl stop kiosk.service

# Run calibration
DISPLAY=:0 xinput_calibrator

# Save the output to /etc/X11/xorg.conf.d/99-calibration.conf
# Then restart kiosk
sudo systemctl start kiosk.service
```

### Custom Splash Screen

**For Chromium**:
```bash
# Create a simple loading page
sudo mkdir -p /opt/react-ui-app/splash
sudo tee /opt/react-ui-app/splash/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <style>
    body {
      margin: 0;
      background: #000;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      color: white;
      font-family: Arial, sans-serif;
    }
    .loader { font-size: 2em; }
  </style>
</head>
<body>
  <div class="loader">Loading Application...</div>
  <script>
    setTimeout(() => {
      window.location.href = 'http://localhost';
    }, 3000);
  </script>
</body>
</html>
EOF

# Update start-kiosk.sh to load splash first
chromium-browser --kiosk file:///opt/react-ui-app/splash/index.html
```

---

## Support & Resources

### Useful Links
- [Chromium Command Line Flags](https://peter.sh/experiments/chromium-command-line-switches/)
- [Electron Documentation](https://www.electronjs.org/docs/latest)
- [Raspberry Pi Documentation](https://www.raspberrypi.org/documentation/)

### Common Questions

**Q: Can users exit the kiosk mode?**
A: By design, no. Users cannot exit using keyboard shortcuts or UI elements. For maintenance, use SSH or virtual terminals (Ctrl+Alt+F2).

**Q: What happens if the app crashes?**
A: The watchdog service automatically restarts the kiosk within 30 seconds.

**Q: Can I use this on other devices besides Raspberry Pi?**
A: Yes! These scripts work on any Debian/Ubuntu-based system (x86 or ARM).

**Q: How do I change the URL?**
A: Edit `/home/pi/start-kiosk.sh` and change the URL in the chromium-browser command.

**Q: Can I run multiple apps in kiosk mode?**
A: Yes, but you'd need to create a simple web page that embeds or links to multiple apps, then point the kiosk to that page.

---

## License

This guide and associated scripts are provided as-is for use with the React TypeScript application.

## Author

Senior Software Engineer
PineSage Projects - ApiGateway

