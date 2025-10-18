# Raspberry Pi Kiosk - Production Deployment Guide

## 🎯 For Deploying to Multiple Devices

This guide shows how to deploy your React app as a kiosk on 50+ Raspberry Pis with **ONE script, no manual steps**.

---

## 📋 Prerequisites (Per Device)

- Raspberry Pi (3, 4, or 5) with Raspberry Pi OS installed
- 2GB+ RAM
- 16GB+ SD card
- Network connectivity (WiFi or Ethernet)
- SSH enabled

---

## 🚀 Quick Deployment (3 Commands)

### Step 1: Copy Project to Raspberry Pi

From your Windows machine:

```bash
# Option A: Using git
ssh pi@<raspberry-pi-ip>
git clone <your-repo-url>
cd AzureGateway.UI

# Option B: Using SCP (if you have the files locally)
scp -r AzureGateway.UI pi@<raspberry-pi-ip>:~/
ssh pi@<raspberry-pi-ip>
cd AzureGateway.UI
```

### Step 2: Run Deployment Script

```bash
# Make executable
chmod +x scripts/deploy-kiosk-complete.sh

# Run (will ask for sudo password once)
sudo bash scripts/deploy-kiosk-complete.sh
```

**The script will:**
- ✅ Install all dependencies
- ✅ Deploy your React app
- ✅ Configure PM2 properly
- ✅ Set up Nginx
- ✅ Configure kiosk mode
- ✅ Enable auto-start on boot

**Time:** ~10-15 minutes per device

### Step 3: Reboot

```bash
sudo reboot
```

**That's it!** Your app will display in full-screen kiosk mode after reboot.

---

## 🔧 What Gets Configured

| Component | Configuration |
|-----------|--------------|
| **Node.js** | v18.x installed globally |
| **PM2** | Auto-starts on boot with correct service type |
| **Nginx** | Serves static files at port 80 |
| **Chromium** | Launches in kiosk mode with GPU disabled (tested flags) |
| **Auto-login** | Configured for your user |
| **Screen** | Blanking disabled, cursor hidden |

---

## 📦 Bulk Deployment (For 50+ Devices)

### Option 1: Pre-configured SD Card Image

1. **Set up ONE Raspberry Pi** using the script above
2. **After successful deployment**, create an image:
   ```bash
   # From Windows with Win32DiskImager or similar
   # Read the SD card to create master.img
   ```
3. **Flash master.img** to all other SD cards
4. **Boot each Pi** - they'll work immediately
5. **Change hostname** on each Pi to avoid conflicts:
   ```bash
   sudo hostnamectl set-hostname rpi-kiosk-01
   sudo reboot
   ```

### Option 2: Ansible Playbook (Advanced)

Create `deploy-all.yml`:

```yaml
---
- hosts: raspberry_pis
  become: yes
  vars:
    repo_url: "https://github.com/your-org/your-repo.git"
  
  tasks:
    - name: Clone repository
      git:
        repo: "{{ repo_url }}"
        dest: /home/pi/AzureGateway.UI
        force: yes
      become_user: pi
    
    - name: Run deployment script
      shell: bash /home/pi/AzureGateway.UI/scripts/deploy-kiosk-complete.sh
      args:
        creates: /opt/react-ui-app/dist
    
    - name: Reboot
      reboot:
```

Run on all devices:
```bash
ansible-playbook -i inventory.ini deploy-all.yml
```

### Option 3: Bash Script for Multiple IPs

```bash
#!/bin/bash
# deploy-all-pis.sh

RPI_IPS=(
  "192.168.1.10"
  "192.168.1.11"
  "192.168.1.12"
  # Add all your Pi IPs
)

for IP in "${RPI_IPS[@]}"; do
  echo "Deploying to $IP..."
  
  # Copy project
  scp -r AzureGateway.UI pi@$IP:~/
  
  # Run deployment
  ssh pi@$IP "cd AzureGateway.UI && chmod +x scripts/deploy-kiosk-complete.sh && sudo bash scripts/deploy-kiosk-complete.sh"
  
  # Reboot
  ssh pi@$IP "sudo reboot"
  
  echo "Deployed to $IP"
  sleep 5
done

echo "All deployments complete!"
```

---

## 🔍 Verification Checklist

After deployment, verify on each device:

```bash
# SSH into the Pi
ssh pi@<raspberry-pi-ip>

# Check all services
systemctl is-active nginx && echo "✓ Nginx running"
systemctl is-active pm2-pi.service && echo "✓ PM2 running"
pm2 list | grep -q "online" && echo "✓ App online"
curl -I http://localhost | grep -q "200 OK" && echo "✓ Web accessible"

# Check kiosk autostart
ls -la ~/.config/autostart/kiosk.desktop && echo "✓ Kiosk configured"
```

**On the screen:**
- App should be in full-screen
- No browser UI visible
- No desktop icons

---

## 🛠️ Management Commands

### Remote Management (via SSH)

```bash
# View app status
pm2 list

# View logs
pm2 logs

# Restart app
pm2 restart ui-app

# Exit kiosk mode (shows desktop)
exit-kiosk

# Restart kiosk
restart-kiosk

# Update app (copy new dist/ files, then:)
sudo systemctl restart nginx
```

### Update All Devices

```bash
# Script: update-all-pis.sh
for IP in "${RPI_IPS[@]}"; do
  echo "Updating $IP..."
  
  # Build app locally first
  npm run build
  
  # Copy new build
  scp -r dist/* pi@$IP:/opt/react-ui-app/dist/
  
  # Restart nginx
  ssh pi@$IP "sudo systemctl restart nginx"
  
  echo "Updated $IP"
done
```

---

## 🐛 Troubleshooting

### Issue: White screen in kiosk

**Solution:** Already fixed in the script with `--disable-gpu` flag

### Issue: PM2 fails to start on boot

**Solution:** Script uses `oneshot` service type (already fixed)

### Issue: App not loading

```bash
# Check nginx
sudo systemctl status nginx

# Check if files exist
ls -la /opt/react-ui-app/dist/

# Test manually
curl http://localhost
```

### Issue: Kiosk doesn't start

```bash
# Check autostart file
cat ~/.config/autostart/kiosk.desktop

# Check if desktop is enabled
systemctl get-default  # Should show: graphical.target

# Manually test
DISPLAY=:0 chromium-browser --kiosk --disable-gpu http://localhost &
```

---

## 📊 Performance Optimization

For large deployments:

1. **Use static IP addresses** - Easier management
2. **Set unique hostnames** - `rpi-kiosk-01`, `rpi-kiosk-02`, etc.
3. **Monitor centrally** - Use monitoring tools
4. **Auto-update** - Set up cron jobs for updates
5. **Backup config** - Keep master SD card image

---

## 🔐 Security Best Practices

```bash
# Change default password
passwd

# Disable SSH password, use keys only
ssh-copy-id pi@<raspberry-pi-ip>
# Then disable password auth in /etc/ssh/sshd_config

# Firewall (optional, if needed)
sudo ufw allow from 192.168.1.0/24 to any port 22
sudo ufw allow 80/tcp
sudo ufw enable

# Update regularly
sudo apt update && sudo apt upgrade -y
```

---

## 📝 Deployment Checklist

- [ ] Flash Raspberry Pi OS to SD card
- [ ] Enable SSH (create `ssh` file in boot partition)
- [ ] Boot Pi and set static IP (optional)
- [ ] Copy project to Pi
- [ ] Run `deploy-kiosk-complete.sh`
- [ ] Reboot
- [ ] Verify app loads in kiosk mode
- [ ] Label device with hostname/IP
- [ ] Document in inventory

---

## 🎉 Success Criteria

Your deployment is successful when:

✅ App displays in full-screen on boot  
✅ No browser UI visible  
✅ PM2 service active  
✅ Nginx serving files  
✅ Can manage remotely via SSH  
✅ App accessible from network  

---

## 📞 Support

If you encounter issues:

1. Check logs: `pm2 logs`, `sudo journalctl -u nginx`
2. Verify services: `systemctl status pm2-pi nginx`
3. Test manually: `curl http://localhost`
4. Review this guide's troubleshooting section

---

**That's it! You now have a repeatable, automated deployment process for 50+ Raspberry Pi kiosks.** 🚀

