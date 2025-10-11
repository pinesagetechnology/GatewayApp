# IoT Monitoring System - Installation Guide

## What This Installs

- **3 Services:**
  1. FileMonitorWorkerService - Monitors folders for file changes
  2. APIMonitorWorkerService - Polls APIs and saves responses
  3. MonitoringServiceAPI - Web API to manage the services

- **1 React App:**
  - AzureGateway.UI - Web interface to control everything

## Simple Installation

### On Your IoT Device (Linux):

```bash
# 1. Transfer files to IoT device
scp -r ApiGateway pi@your-iot-device:/home/pi/workspace/GatewayApp/

# 2. SSH to device
ssh pi@your-iot-device

# 3. Go to folder
cd /home/pi/workspace/GatewayApp

# 4. Run installer (ONE command!)
sudo bash unified_installer.sh
```

That's it! ✅

---

## What the Installer Does

```
Step 1: Make all scripts executable
Step 2: Install .NET and SQLite (if needed)
Step 3: Install FileMonitorWorkerService → /opt/filemonitor
Step 4: Install APIMonitorWorkerService → /opt/apimonitor
Step 5: Install MonitoringServiceAPI → /opt/monitoringapi
Step 6: Configure sudo (so API can create folders)
Step 7: Fix database permissions
Step 8: Deploy React app
```

---

## After Installation

### Start the Services:
```bash
sudo systemctl start filemonitor
sudo systemctl start apimonitor
sudo systemctl start monitoringapi
```

### Check Status:
```bash
sudo systemctl status monitoringapi
sudo systemctl status filemonitor
sudo systemctl status apimonitor
```

### View Logs:
```bash
sudo journalctl -u monitoringapi -f
```

### Access the Web Interface:
```
http://your-iot-device/
```

### Use the API:
```
http://your-iot-device/api/
http://your-iot-device/swagger
```

---

## Creating Data Sources (Folders)

When you create a data source via API, it automatically:
1. ✅ Creates the folder
2. ✅ Sets **full access (777)** - everyone can read/write
3. ✅ No restrictions - all users can use the folder

**Example:**
```bash
curl -X POST http://localhost:5000/api/datasource \
  -H "Content-Type: application/json" \
  -d '{
    "name": "MyDataSource",
    "folderPath": "/home/pi/workspace/mydata",
    "isEnabled": true
  }'
```

**Result:**
- Folder created at `/home/pi/workspace/mydata`
- Permissions: `drwxrwxrwx` (777)
- All services and users can create/delete files

---

## Scripts Explained

### Main Scripts (You Need These):

| Script | What It Does |
|--------|--------------|
| **`unified_installer.sh`** | Main installer - runs everything |
| **`grant_limited_sudo_access.sh`** | Gives API permission to create folders |
| **`fix-monitored-folder-permissions.sh`** | Sets folder permissions to 777 |

### Other Scripts (Used Automatically):
- `dotnet_install_script.sh` - Installs .NET
- `git_sqlite_installer.sh` - Installs SQLite
- `shared_folder_setup.sh` - Old script (not used)

---

## Folder Permissions Explained

**What "Full Access (777)" Means:**
```
drwxrwxrwx
│││││││└── Others can read/write/execute
││││││└─── Others can read/write
│││││└──── Others can read
││││└───── Group can read/write/execute
│││└────── Group can read/write
││└─────── Group can read
│└──────── Owner can read/write/execute
└───────── Owner can read/write
```

**Result:**
- Owner (pi): Can do everything
- Group: Can do everything
- Others: Can do everything
- **Everyone has full access!**

---

## Reinstallation

Want to reinstall? Just run it again:
```bash
cd /home/pi/workspace/GatewayApp
sudo bash unified_installer.sh
```

The installer handles:
- ✅ Overwriting old files
- ✅ Restarting services
- ✅ Preserving databases
- ✅ Safe to run multiple times

---

## Troubleshooting

### If installation fails:
```bash
# Check logs
sudo journalctl -xe

# Try individual service installers
cd FileMonitorWorkerService
sudo bash scripts/FileMonitorWorkerService_MainInstaller.sh
```

### If services won't start:
```bash
# Check status
sudo systemctl status monitoringapi

# View full logs
sudo journalctl -u monitoringapi -n 100

# Restart service
sudo systemctl restart monitoringapi
```

### If folder creation fails:
```bash
# Check sudo permissions
sudo -u monitoringapi sudo -l

# Re-run sudo setup
sudo bash grant_limited_sudo_access.sh

# Restart API
sudo systemctl restart monitoringapi
```

---

## File Locations

### Services:
- FileMonitor: `/opt/filemonitor/`
- APIMonitor: `/opt/apimonitor/`
- MonitoringAPI: `/opt/monitoringapi/`

### Databases:
- FileMonitor DB: `/var/filemonitor/filemonitor.db`
- APIMonitor DB: `/var/apimonitor/apimonitor.db`

### Configuration:
- Sudoers: `/etc/sudoers.d/monitoringapi`
- Service files: `/etc/systemd/system/*.service`

---

## Quick Reference

```bash
# Install everything
sudo bash unified_installer.sh

# Start services
sudo systemctl start filemonitor apimonitor monitoringapi

# Stop services
sudo systemctl stop filemonitor apimonitor monitoringapi

# View logs
sudo journalctl -u monitoringapi -f

# Create data source
curl -X POST http://localhost:5000/api/datasource \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","folderPath":"/home/pi/workspace/test","isEnabled":true}'
```

---

## That's It!

Simple installation, full access folders, no complicated permissions.

Just run `unified_installer.sh` and you're done! 🎉

