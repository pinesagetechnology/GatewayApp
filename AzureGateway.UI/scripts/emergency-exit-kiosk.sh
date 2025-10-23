#!/usr/bin/env bash

################################################################################
# Emergency Kiosk Exit Script - NUCLEAR OPTION
# Use this when nothing else works
################################################################################

echo "=========================================="
echo "EMERGENCY KIOSK EXIT - NUCLEAR OPTION"
echo "=========================================="
echo ""

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Must run as root"
    echo "Run: sudo bash $0"
    exit 1
fi

echo "This will forcefully stop all kiosk-related processes and services."
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted"
    exit 0
fi

echo ""
echo "Step 1: Stopping all kiosk services..."
systemctl stop kiosk.service 2>/dev/null
systemctl stop kiosk-watchdog.service 2>/dev/null
systemctl stop electron-kiosk.service 2>/dev/null
systemctl stop chromium-kiosk.service 2>/dev/null

# Find and stop any service with 'kiosk' in name
for service in $(systemctl list-units --all --no-pager | grep -i kiosk | awk '{print $1}'); do
    echo "  Stopping $service..."
    systemctl stop "$service" 2>/dev/null
done

echo ""
echo "Step 2: Killing browser processes..."
killall -9 chromium 2>/dev/null
killall -9 chromium-browser 2>/dev/null
killall -9 firefox 2>/dev/null
killall -9 electron 2>/dev/null
sleep 1

# Try again in case they respawned
killall -9 chromium 2>/dev/null
killall -9 chromium-browser 2>/dev/null

echo ""
echo "Step 3: Disabling auto-restart..."
systemctl disable kiosk.service 2>/dev/null
systemctl disable kiosk-watchdog.service 2>/dev/null

echo ""
echo "Step 4: Disabling autostart files..."
for dir in /home/*/.config/autostart /etc/xdg/autostart; do
    if [ -d "$dir" ]; then
        find "$dir" -name "*kiosk*.desktop" -type f -exec mv {} {}.disabled \; 2>/dev/null
        find "$dir" -name "*chromium*.desktop" -type f -exec mv {} {}.disabled \; 2>/dev/null
    fi
done

echo ""
echo "Step 5: Checking remaining processes..."
if pgrep -x chromium >/dev/null || pgrep -x chromium-browser >/dev/null; then
    echo "WARNING: Browser still running!"
    echo "Trying one more time..."
    pkill -9 -f chromium
else
    echo "✓ No browser processes running"
fi

if systemctl list-units --no-pager | grep -i kiosk | grep active >/dev/null; then
    echo "WARNING: Some kiosk services still active"
    systemctl list-units --no-pager | grep -i kiosk
else
    echo "✓ No active kiosk services"
fi

echo ""
echo "=========================================="
echo "Emergency exit complete!"
echo "=========================================="
echo ""
echo "If kiosk mode is still running, try:"
echo "  1. Press Ctrl+Alt+F2 to switch to terminal"
echo "  2. Run: sudo systemctl stop lightdm (or gdm)"
echo "  3. Reboot: sudo reboot"
echo ""

