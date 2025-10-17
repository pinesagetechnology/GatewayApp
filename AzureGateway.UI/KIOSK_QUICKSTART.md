# Kiosk Mode - Quick Start Guide

Transform your React app into a locked-down kiosk display for Raspberry Pi in minutes!

## 🚀 Quick Decision Guide

**I want the fastest, lightest setup** → Use Chromium Kiosk ⬇️

**I want a desktop app with full control** → Use Electron Kiosk ⬇️

---

## Option 1: Chromium Kiosk (5 minutes setup)

### Prerequisites
✅ Raspberry Pi running Raspberry Pi OS  
✅ App already deployed (run `rpi5-deploy.sh` first)  
✅ Monitor connected  

### Installation

```bash
# 1. Deploy your app (if not already done)
cd AzureGateway.UI
bash scripts/rpi5-deploy.sh

# 2. Set up kiosk mode
sudo bash scripts/kiosk-chromium-setup.sh

# 3. Reboot
sudo reboot
```

**That's it!** Your app will now auto-start in full-screen kiosk mode on boot.

### What It Does
- ✅ Auto-login on boot
- ✅ Launches Chromium in full-screen
- ✅ Disables screen saver & power management
- ✅ Blocks keyboard shortcuts (Alt+F4, etc.)
- ✅ Auto-restarts if crashed
- ✅ Hides mouse cursor when idle

### Quick Commands

```bash
# Stop kiosk (for maintenance)
sudo systemctl stop kiosk.service

# View logs
sudo journalctl -u kiosk.service -f

# Update app
sudo /usr/local/bin/update-kiosk-app

# Emergency exit
sudo /usr/local/bin/exit-kiosk
```

### Access Terminal During Kiosk
- **Option A**: SSH from another computer: `ssh pi@<raspberry-pi-ip>`
- **Option B**: Press `Ctrl+Alt+F2` (terminal), `Ctrl+Alt+F7` (back to GUI)

---

## Option 2: Electron Kiosk (15 minutes setup)

### Prerequisites
✅ Raspberry Pi running Raspberry Pi OS  
✅ Node.js 18+ installed  
✅ 2GB+ RAM  

### Installation

```bash
# 1. Go to project directory
cd AzureGateway.UI

# 2. Run Electron setup
bash scripts/kiosk-electron-setup.sh

# 3. Test in development mode (optional)
npm run electron:dev

# 4. Build production version
npm run electron:build

# 5. Set up autologin (one-time)
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin pi --noclear %I \$TERM
EOF

echo 'if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then' >> ~/.bashrc
echo '  startx -- :0 vt1' >> ~/.bashrc
echo 'fi' >> ~/.bashrc

echo 'cd ~/AzureGateway.UI && npm run electron:start' > ~/.xinitrc
chmod +x ~/.xinitrc

# 6. Reboot
sudo reboot
```

### What It Does
- ✅ Packages app as native desktop application
- ✅ Full control over window behavior
- ✅ Offline support built-in
- ✅ Better performance for complex UIs
- ✅ Custom keyboard shortcut blocking
- ✅ Integrated crash recovery

### Quick Commands

```bash
# Start kiosk
./start-electron-kiosk.sh

# Stop kiosk
./exit-electron-kiosk.sh

# View logs
sudo journalctl -u electron-kiosk.service -f

# Update app
npm run build && sudo systemctl restart electron-kiosk.service
```

---

## 🔒 Security Hardening (Optional but Recommended)

After setting up kiosk mode, run these commands for extra security:

```bash
# Disable unused services
sudo systemctl disable bluetooth.service
sudo systemctl disable avahi-daemon.service

# Set up firewall
sudo apt install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 192.168.1.0/24 to any port 22  # SSH from local network only
sudo ufw enable

# Disable USB auto-mount
sudo systemctl mask udisks2.service
```

---

## 📊 Feature Comparison

| Feature | Chromium Kiosk | Electron Kiosk |
|---------|----------------|----------------|
| Setup Time | 5 mins | 15 mins |
| RAM Usage | ~200MB | ~350MB |
| CPU Usage | Low | Medium |
| Boot Time | Fast | Moderate |
| Offline Mode | ❌ (requires nginx) | ✅ Native |
| DevTools | ✅ (browser) | ✅ (electron) |
| Updates | Simple rebuild | Rebuild + repackage |
| Custom UI | Limited | Full control |
| Touch Support | ✅ Via browser | ✅ Native |
| Best For | Web apps, tight resources | Desktop apps, rich features |

---

## 🐛 Common Issues & Fixes

### Screen Goes Black After a While
```bash
# Edit start-kiosk.sh, add these lines before chromium-browser
xset s off
xset s noblank
xset -dpms
```

### App Shows "Cannot Connect"
```bash
# Check if nginx/app is running
sudo systemctl status nginx
curl http://localhost

# Restart services
sudo systemctl restart nginx
```

### Keyboard Shortcuts Still Work
```bash
# The kiosk script disables most shortcuts, but for extra security:
sudo apt install -y matchbox-window-manager
# Edit start-kiosk.sh and add before chromium-browser:
matchbox-window-manager &
```

### Want to Temporarily Exit Kiosk
```bash
# Press Ctrl+Alt+F2 to switch to terminal
# Login with your credentials
# Stop kiosk: sudo systemctl stop kiosk.service
# Press Ctrl+Alt+F7 to return to GUI (if you start kiosk again)
```

---

## 📝 Configuration Examples

### Change the URL
Edit `/home/pi/start-kiosk.sh`:
```bash
# Change this line:
chromium-browser --kiosk http://localhost
# To:
chromium-browser --kiosk http://your-url-here.com
```

### Adjust Zoom Level
```bash
chromium-browser --kiosk --force-device-scale-factor=1.5 http://localhost
```

### Enable Touch Screen
```bash
chromium-browser --kiosk --touch-events=enabled http://localhost
```

### Rotate Screen
Edit `/boot/config.txt`:
```bash
display_rotate=1  # 0=normal, 1=90°, 2=180°, 3=270°
```

---

## 📚 Need More Help?

- **Full Documentation**: See `KIOSK_SETUP_GUIDE.md` for comprehensive details
- **Troubleshooting**: Check the troubleshooting section in the full guide
- **Advanced Config**: See advanced configuration examples in the full guide

---

## 🎯 Best Practices

1. **Test First**: Always test your app works at `http://localhost` before enabling kiosk mode
2. **SSH Access**: Set up SSH before enabling kiosk for remote maintenance
3. **Static IP**: Configure a static IP for easier remote access
4. **Backups**: Keep backups of your kiosk configuration
5. **Updates**: Plan a maintenance window for app updates
6. **Monitoring**: Check logs regularly for any issues

---

## 🔄 Updating Your App

### Chromium Kiosk
```bash
# Quick update
sudo /usr/local/bin/update-kiosk-app

# Manual update
sudo systemctl stop kiosk.service
cd /opt/react-ui-app
# Copy your new build
sudo cp -r /path/to/new/dist/* ./dist/
sudo systemctl start kiosk.service
```

### Electron Kiosk
```bash
cd AzureGateway.UI
git pull  # If using git
npm install
npm run build
npm run electron:build
sudo systemctl restart electron-kiosk.service
```

---

## ✅ Verification Checklist

After setup, verify:
- [ ] App loads automatically on boot
- [ ] Display is full-screen with no browser UI
- [ ] Keyboard shortcuts (Alt+F4, Ctrl+W) are blocked
- [ ] Screen doesn't blank after idle time
- [ ] Mouse cursor hides when idle
- [ ] App restarts automatically after crash
- [ ] SSH access works from another machine
- [ ] Logs are accessible via journalctl

---

## 🎉 You're Done!

Your Raspberry Pi is now a dedicated kiosk display for your React app!

**Pro Tip**: Label the device with the SSH IP address for easy maintenance access.

---

**Questions or Issues?** Check the full `KIOSK_SETUP_GUIDE.md` for detailed troubleshooting and advanced configurations.

