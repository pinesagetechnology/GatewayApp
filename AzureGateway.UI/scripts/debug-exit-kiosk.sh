#!/usr/bin/env bash

################################################################################
# Kiosk Mode Debug and Exit Script
# For Raspberry Pi / Jetson Orin / Ubuntu systems
# 
# This script helps debug why kiosk mode won't exit and provides multiple
# methods to forcefully exit kiosk mode.
################################################################################

set +e  # Don't exit on errors, we want to try everything

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${CYAN}ℹ${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
err() { echo -e "${RED}✗${NC} $1"; }
section() { echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}\n"; }

################################################################################
# Step 1: Diagnose Current State
################################################################################

section "Step 1: Diagnosing Current Kiosk Setup"

echo "Hostname: $(hostname)"
echo "User: $(whoami)"
echo "Display: $DISPLAY"
echo ""

# Check for running browser processes
info "Checking for browser processes..."
CHROMIUM_PID=$(pgrep -x chromium)
CHROMIUM_BROWSER_PID=$(pgrep -x chromium-browser)
FIREFOX_PID=$(pgrep -x firefox)
ELECTRON_PID=$(pgrep -x electron)

if [ -n "$CHROMIUM_PID" ]; then
    log "Found chromium process: PID $CHROMIUM_PID"
    ps aux | grep chromium | grep -v grep
fi

if [ -n "$CHROMIUM_BROWSER_PID" ]; then
    log "Found chromium-browser process: PID $CHROMIUM_BROWSER_PID"
    ps aux | grep chromium-browser | grep -v grep
fi

if [ -n "$FIREFOX_PID" ]; then
    log "Found firefox process: PID $FIREFOX_PID"
fi

if [ -n "$ELECTRON_PID" ]; then
    log "Found electron process: PID $ELECTRON_PID"
fi

if [ -z "$CHROMIUM_PID" ] && [ -z "$CHROMIUM_BROWSER_PID" ] && [ -z "$FIREFOX_PID" ] && [ -z "$ELECTRON_PID" ]; then
    warn "No browser processes found"
fi

echo ""

# Check for kiosk systemd services
info "Checking for kiosk systemd services..."
KIOSK_SERVICES=$(systemctl list-units --all --no-pager | grep -i kiosk | awk '{print $1}')

if [ -n "$KIOSK_SERVICES" ]; then
    log "Found kiosk services:"
    echo "$KIOSK_SERVICES"
    echo ""
    
    for service in $KIOSK_SERVICES; do
        echo "Service: $service"
        systemctl status "$service" --no-pager -l || true
        echo ""
    done
else
    warn "No kiosk systemd services found"
fi

# Check for autostart entries
info "Checking for autostart entries..."
AUTOSTART_DIRS=(
    "/home/$USER/.config/autostart"
    "/etc/xdg/autostart"
    "/home/$(logname 2>/dev/null || echo $USER)/.config/autostart"
)

for dir in "${AUTOSTART_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        KIOSK_FILES=$(ls -la "$dir" 2>/dev/null | grep -i kiosk)
        if [ -n "$KIOSK_FILES" ]; then
            log "Found autostart files in $dir:"
            ls -la "$dir" | grep -i "kiosk\|chromium\|browser"
            echo ""
        fi
    fi
done

# Check for X server and display manager
info "Checking X server and display manager..."
X_PID=$(pgrep -x X)
XORG_PID=$(pgrep -x Xorg)
LIGHTDM_PID=$(pgrep -x lightdm)
GDM_PID=$(pgrep -x gdm)

[ -n "$X_PID" ] && log "X server running: PID $X_PID"
[ -n "$XORG_PID" ] && log "Xorg running: PID $XORG_PID"
[ -n "$LIGHTDM_PID" ] && log "LightDM running: PID $LIGHTDM_PID"
[ -n "$GDM_PID" ] && log "GDM running: PID $GDM_PID"

echo ""

# Check watchdog services
info "Checking for watchdog services..."
WATCHDOG_SERVICES=$(systemctl list-units --all --no-pager | grep -i watchdog | grep kiosk | awk '{print $1}')
if [ -n "$WATCHDOG_SERVICES" ]; then
    warn "Found watchdog services (these will restart kiosk!):"
    echo "$WATCHDOG_SERVICES"
fi

echo ""

################################################################################
# Step 2: Provide Exit Options
################################################################################

section "Step 2: Exit Kiosk Mode"

if [ "$(id -u)" -ne 0 ]; then
    warn "Not running as root. Some operations may fail."
    warn "For best results, run: sudo bash $0"
    echo ""
fi

# Function to kill browser processes
kill_browsers() {
    section "Killing Browser Processes"
    
    killall -9 chromium 2>/dev/null && log "Killed chromium" || info "No chromium process"
    killall -9 chromium-browser 2>/dev/null && log "Killed chromium-browser" || info "No chromium-browser process"
    killall -9 firefox 2>/dev/null && log "Killed firefox" || info "No firefox process"
    killall -9 electron 2>/dev/null && log "Killed electron" || info "No electron process"
    
    sleep 1
}

# Function to stop systemd services
stop_services() {
    section "Stopping Kiosk Services"
    
    # Common kiosk service names
    SERVICES=(
        "kiosk.service"
        "kiosk-watchdog.service"
        "electron-kiosk.service"
        "chromium-kiosk.service"
    )
    
    for service in "${SERVICES[@]}"; do
        if systemctl list-units --all --no-pager | grep -q "$service"; then
            systemctl stop "$service" 2>/dev/null && log "Stopped $service" || warn "Failed to stop $service"
        fi
    done
    
    # Stop any service with 'kiosk' in the name
    KIOSK_SERVICES=$(systemctl list-units --all --no-pager | grep -i kiosk | awk '{print $1}')
    for service in $KIOSK_SERVICES; do
        systemctl stop "$service" 2>/dev/null && log "Stopped $service" || warn "Failed to stop $service"
    done
}

# Function to disable autostart
disable_autostart() {
    section "Disabling Kiosk Autostart"
    
    for dir in "${AUTOSTART_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            find "$dir" -name "*kiosk*.desktop" -o -name "*chromium*.desktop" | while read file; do
                if [ -f "$file" ]; then
                    mv "$file" "$file.disabled" 2>/dev/null && log "Disabled: $file" || warn "Could not disable: $file"
                fi
            done
        fi
    done
}

# Interactive menu
echo "Choose an option:"
echo ""
echo "  ${BOLD}1${NC}) Kill browser processes only (quick, temporary)"
echo "  ${BOLD}2${NC}) Stop kiosk services (persistent until reboot)"
echo "  ${BOLD}3${NC}) Stop services + kill browsers (recommended)"
echo "  ${BOLD}4${NC}) Nuclear option (stop everything + disable autostart)"
echo "  ${BOLD}5${NC}) Just show info (no changes)"
echo "  ${BOLD}6${NC}) Exit script"
echo ""

read -p "Enter choice [1-6]: " choice

case $choice in
    1)
        kill_browsers
        ;;
    2)
        stop_services
        ;;
    3)
        stop_services
        kill_browsers
        ;;
    4)
        stop_services
        kill_browsers
        disable_autostart
        log "Kiosk mode should be completely disabled"
        ;;
    5)
        info "No changes made"
        ;;
    6)
        info "Exiting"
        exit 0
        ;;
    *)
        err "Invalid choice"
        exit 1
        ;;
esac

################################################################################
# Step 3: Verify Exit
################################################################################

section "Step 3: Verifying Exit Status"

sleep 2

REMAINING_BROWSERS=$(pgrep -x chromium)$(pgrep -x chromium-browser)$(pgrep -x firefox)$(pgrep -x electron)

if [ -z "$REMAINING_BROWSERS" ]; then
    log "✓ No browser processes running"
else
    warn "Some browser processes still running:"
    ps aux | grep -E "chromium|firefox|electron" | grep -v grep
fi

ACTIVE_KIOSK_SERVICES=$(systemctl list-units --no-pager | grep -i kiosk | grep active)
if [ -z "$ACTIVE_KIOSK_SERVICES" ]; then
    log "✓ No active kiosk services"
else
    warn "Some kiosk services still active:"
    echo "$ACTIVE_KIOSK_SERVICES"
fi

################################################################################
# Step 4: Manual Commands
################################################################################

section "Step 4: Manual Commands (if above didn't work)"

cat <<'EOF'
If kiosk mode is still running, try these commands manually:

1. Kill all browser processes:
   sudo killall -9 chromium chromium-browser firefox electron

2. Stop all kiosk services:
   sudo systemctl stop kiosk.service
   sudo systemctl stop kiosk-watchdog.service

3. Disable services from auto-starting:
   sudo systemctl disable kiosk.service
   sudo systemctl disable kiosk-watchdog.service

4. Switch to another TTY (virtual terminal):
   Press: Ctrl + Alt + F2
   (Switch back with: Ctrl + Alt + F7)

5. Kill X server (last resort):
   sudo killall X
   sudo killall Xorg

6. Reboot into multi-user mode (no GUI):
   sudo systemctl set-default multi-user.target
   sudo reboot

7. Check for cron jobs or scripts that restart kiosk:
   crontab -l
   sudo crontab -l

8. Check user profile autostart:
   ls -la ~/.config/autostart/
   cat ~/.bashrc | grep -i kiosk
   cat ~/.profile | grep -i kiosk

9. Look for systemd user services:
   systemctl --user list-units --all | grep kiosk

10. Nuclear option - kill lightdm/gdm (will log you out):
    sudo systemctl stop lightdm
    sudo systemctl stop gdm

EOF

################################################################################
# Step 5: Prevention
################################################################################

section "Step 5: Preventing Auto-Restart"

echo "To prevent kiosk from restarting on next boot:"
echo ""
echo "  sudo systemctl disable kiosk.service"
echo "  sudo systemctl disable kiosk-watchdog.service"
echo ""
echo "To completely remove kiosk setup, look for these scripts:"
echo "  /usr/local/bin/exit-kiosk"
echo "  ./remove-kiosk.sh (if exists)"
echo ""

################################################################################
# Step 6: Logs
################################################################################

section "Step 6: Recent Logs"

info "Recent kiosk-related logs:"
journalctl -u kiosk --no-pager -n 20 2>/dev/null || warn "No kiosk service logs"
journalctl -u kiosk-watchdog --no-pager -n 20 2>/dev/null || warn "No watchdog logs"

echo ""
log "Script completed. Check the output above for any issues."
echo ""

