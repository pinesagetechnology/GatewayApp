# Kiosk Mode - Command Reference

Quick reference for managing your kiosk mode on Raspberry Pi.

## 🚀 Setup Commands

```bash
# Interactive setup wizard (recommended)
bash scripts/setup-kiosk.sh

# Chromium kiosk (direct)
sudo bash scripts/kiosk-chromium-setup.sh

# Electron kiosk (direct)
bash scripts/kiosk-electron-setup.sh
```

## 🎮 Control Commands

### Start/Stop/Restart

```bash
# Chromium Kiosk
sudo systemctl start kiosk.service
sudo systemctl stop kiosk.service
sudo systemctl restart kiosk.service
sudo systemctl status kiosk.service

# Electron Kiosk
sudo systemctl start electron-kiosk.service
sudo systemctl stop electron-kiosk.service
sudo systemctl restart electron-kiosk.service
sudo systemctl status electron-kiosk.service
```

### Enable/Disable Auto-Start

```bash
# Disable auto-start on boot (but keep configuration)
sudo systemctl disable kiosk.service
sudo systemctl stop kiosk.service

# Re-enable auto-start
sudo systemctl enable kiosk.service
sudo systemctl start kiosk.service
```

## 📊 Monitoring Commands

```bash
# View live logs (Chromium)
sudo journalctl -u kiosk.service -f

# View live logs (Electron)
sudo journalctl -u electron-kiosk.service -f

# View last 50 log entries
sudo journalctl -u kiosk.service -n 50

# View logs from today
sudo journalctl -u kiosk.service --since today

# Check if kiosk is running
ps aux | grep chromium
ps aux | grep electron

# Check system resources
htop
free -h
df -h
```

## 🔧 Maintenance Commands

```bash
# Emergency exit kiosk (Chromium)
sudo /usr/local/bin/exit-kiosk

# Update application (Chromium)
sudo /usr/local/bin/update-kiosk-app

# Manual app update
sudo systemctl stop kiosk.service
cd /opt/react-ui-app
# Copy new build files
sudo cp -r /path/to/new/dist/* ./dist/
sudo systemctl start kiosk.service

# Check nginx status
sudo systemctl status nginx

# Restart nginx
sudo systemctl restart nginx

# Test nginx configuration
sudo nginx -t
```

## 🔙 Exit Kiosk Mode

### Option 1: Temporary Stop
```bash
# Stop temporarily (configuration remains)
sudo systemctl stop kiosk.service

# Restart when ready
sudo systemctl start kiosk.service
```

### Option 2: Disable Auto-Start
```bash
# Disable but keep configuration
sudo systemctl disable kiosk.service
sudo systemctl stop kiosk.service
```

### Option 3: Complete Removal
```bash
# Remove all kiosk configuration
sudo bash scripts/remove-kiosk.sh
sudo reboot
```

## 🆘 Emergency Access

### If You're Locked in Kiosk Mode

**Method 1: Virtual Terminal**
- Press `Ctrl+Alt+F2` → Switch to terminal
- Login with your credentials
- Run commands (stop kiosk, etc.)
- Press `Ctrl+Alt+F7` → Return to GUI

**Method 2: SSH from Another Computer**
```bash
# From your laptop/desktop
ssh pi@<raspberry-pi-ip-address>

# Then run maintenance commands
sudo systemctl stop kiosk.service
```

**Method 3: Emergency Exit Script**
```bash
# If you can access terminal
sudo /usr/local/bin/exit-kiosk
```

## 🔄 Update Commands

### Update React App

```bash
# For Chromium kiosk
sudo systemctl stop kiosk.service
cd /opt/react-ui-app
git pull  # if using git
npm install
npm run build
sudo cp -r dist/* /opt/react-ui-app/dist/
sudo systemctl start kiosk.service

# For Electron kiosk
cd ~/AzureGateway.UI
git pull
npm install
npm run build
npm run electron:build
sudo systemctl restart electron-kiosk.service
```

### Update Kiosk Configuration

```bash
# Edit Chromium kiosk startup
sudo nano /home/pi/start-kiosk.sh

# Edit Electron kiosk config
nano ~/AzureGateway.UI/electron.js

# Restart after changes
sudo systemctl restart kiosk.service
```

## 🔍 Troubleshooting Commands

### Check What's Wrong

```bash
# View detailed service status
sudo systemctl status kiosk.service -l

# Check if app is accessible
curl http://localhost

# Check X server
echo $DISPLAY
ps aux | grep X

# Check chromium/electron process
ps aux | grep chromium
ps aux | grep electron

# View nginx logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log

# Check disk space
df -h

# Check memory
free -h

# Check temperature (Raspberry Pi)
vcgencmd measure_temp
```

### Reset Chromium Profile

```bash
# If Chromium has issues, reset its profile
sudo systemctl stop kiosk.service
rm -rf /home/pi/.config/chromium
sudo systemctl start kiosk.service
```

## 🔐 Security Commands

### Firewall Management

```bash
# Check firewall status
sudo ufw status

# Enable SSH from specific network
sudo ufw allow from 192.168.1.0/24 to any port 22

# Allow HTTP
sudo ufw allow 80/tcp

# Enable firewall
sudo ufw enable
```

### View Active Connections

```bash
# See who's connected
w
who

# View SSH connections
netstat -tnpa | grep 'ESTABLISHED.*sshd'
```

## 📸 Screen/Display Commands

### Adjust Display

```bash
# Rotate screen
xrandr --output HDMI-1 --rotate left    # 90° left
xrandr --output HDMI-1 --rotate right   # 90° right
xrandr --output HDMI-1 --rotate normal  # 0°

# Change resolution
xrandr --output HDMI-1 --mode 1920x1080

# List available displays and resolutions
xrandr
```

### Screen Blanking Control

```bash
# Disable screen blanking (temporary)
xset s off
xset s noblank
xset -dpms

# Check current settings
xset q
```

## 📦 Backup Commands

```bash
# Backup kiosk configuration
sudo tar -czf kiosk-backup-$(date +%Y%m%d).tar.gz \
  /home/pi/start-kiosk.sh \
  /etc/systemd/system/kiosk.service \
  /usr/local/bin/kiosk-watchdog.sh \
  /opt/react-ui-app

# Backup application only
cd /opt/react-ui-app
sudo tar -czf app-backup-$(date +%Y%m%d).tar.gz dist/

# Restore from backup
sudo tar -xzf kiosk-backup-20240101.tar.gz -C /
sudo systemctl daemon-reload
```

## 🔄 Reboot/Shutdown Commands

```bash
# Reboot
sudo reboot

# Shutdown
sudo shutdown now

# Scheduled reboot (e.g., at 3 AM daily)
sudo crontab -e
# Add: 0 3 * * * /sbin/shutdown -r now
```

## 📚 Information Commands

```bash
# System info
uname -a
lsb_release -a

# Raspberry Pi model
cat /proc/cpuinfo | grep Model

# IP address
hostname -I

# Uptime
uptime

# Running services
systemctl list-units --type=service --state=running

# Node.js version
node --version

# npm version
npm --version
```

## 💡 Pro Tips

### Auto-Update Script (Run Daily)
```bash
# Create cron job for automatic updates
sudo crontab -e

# Add this line to update app daily at 2 AM:
0 2 * * * cd /opt/react-ui-app && git pull && npm run build && systemctl restart kiosk.service
```

### Remote Monitoring
```bash
# Check kiosk remotely
ssh pi@<raspberry-pi-ip> "systemctl status kiosk.service"

# View logs remotely
ssh pi@<raspberry-pi-ip> "journalctl -u kiosk.service -n 20"
```

### Quick Health Check
```bash
# One-liner to check everything
systemctl is-active kiosk.service && \
systemctl is-active nginx && \
curl -s http://localhost > /dev/null && \
echo "✓ All services healthy" || echo "✗ Something is wrong"
```

---

## 📖 More Help

- **Quick Start**: `KIOSK_QUICKSTART.md`
- **Full Guide**: `KIOSK_SETUP_GUIDE.md`
- **Main README**: `README.md`

---

**Keep this handy!** Bookmark this page or print it for quick reference during maintenance.

