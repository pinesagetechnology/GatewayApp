#!/bin/bash

# Chromium Kiosk Mode Setup for Raspberry Pi
# Description: Sets up the React web app to run in full-screen kiosk mode using Chromium
# Author: Senior Software Engineer
# Usage: sudo bash kiosk-chromium-setup.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_URL="http://localhost"

# Detect the actual user (not root)
if [ -n "$SUDO_USER" ]; then
    KIOSK_USER="$SUDO_USER"
elif [ "$USER" != "root" ]; then
    KIOSK_USER="$USER"
else
    # Prompt for username if running directly as root
    read -p "Enter the username for kiosk mode: " KIOSK_USER
fi

KIOSK_HOME="/home/${KIOSK_USER}"

# Validate user exists
if ! id "$KIOSK_USER" &>/dev/null; then
    error "User '$KIOSK_USER' does not exist!"
fi

log "Configuring kiosk for user: ${KIOSK_USER}"

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Install required packages
install_packages() {
    log "Installing required packages..."
    
    apt update
    apt install -y \
        xorg \
        x11-xserver-utils \
        xinit \
        unclutter \
        sed \
        matchbox-window-manager
    
    # Install Chromium - try both package names (modern Raspberry Pi uses 'chromium', older versions use 'chromium-browser')
    if ! command -v chromium &>/dev/null && ! command -v chromium-browser &>/dev/null; then
        if apt-cache show chromium &>/dev/null; then
            apt install -y chromium || warn "Failed to install chromium, trying chromium-browser"
        fi
        if ! command -v chromium &>/dev/null; then
            apt install -y chromium-browser || warn "Failed to install chromium-browser"
        fi
    else
        log "Chromium already installed"
    fi
    
    # Detect which chromium command is available
    if command -v chromium &>/dev/null; then
        CHROMIUM_CMD="chromium"
    elif command -v chromium-browser &>/dev/null; then
        CHROMIUM_CMD="chromium-browser"
    else
        error "Chromium not found after installation"
    fi
    
    log "Packages installed successfully (using $CHROMIUM_CMD)"
}

# Disable screen blanking and power management
disable_screen_blanking() {
    log "Disabling screen blanking and power management..."
    
    # Create or update lightdm configuration to disable screen blanking
    mkdir -p /etc/lightdm/lightdm.conf.d
    cat > /etc/lightdm/lightdm.conf.d/90-kiosk.conf <<EOF
[Seat:*]
xserver-command=X -s 0 -dpms
EOF
    
    # Disable DPMS and screen saver in user's X session
    mkdir -p "${KIOSK_HOME}/.config"
    cat > "${KIOSK_HOME}/.xserverrc" <<EOF
#!/bin/sh
exec /usr/bin/X -s 0 dpms -nolisten tcp "\$@"
EOF
    chmod +x "${KIOSK_HOME}/.xserverrc"
    
    log "Screen blanking disabled"
}

# Create kiosk startup script
create_kiosk_script() {
    log "Creating kiosk startup script..."
    
    # Detect which chromium command to use in the script
    local SCRIPT_CHROMIUM_CMD
    if command -v chromium &>/dev/null; then
        SCRIPT_CHROMIUM_CMD="chromium"
    elif command -v chromium-browser &>/dev/null; then
        SCRIPT_CHROMIUM_CMD="chromium-browser"
    else
        SCRIPT_CHROMIUM_CMD="$CHROMIUM_CMD"  # Use the one we detected earlier
    fi
    
    cat > "${KIOSK_HOME}/start-kiosk.sh" <<EOF
#!/bin/bash

# Disable screen blanking
xset s off
xset s noblank
xset -dpms

# Hide mouse cursor when idle
unclutter -idle 0.1 -root &

# Remove any crash recovery dialogs
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "\${HOME}/.config/chromium/Default/Preferences" 2>/dev/null || true
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "\${HOME}/.config/chromium/Default/Preferences" 2>/dev/null || true

# Start Chromium in kiosk mode
$SCRIPT_CHROMIUM_CMD \\
    --kiosk \\
    --noerrdialogs \\
    --disable-infobars \\
    --disable-session-crashed-bubble \\
    --disable-translate \\
    --no-first-run \\
    --fast \\
    --fast-start \\
    --disable-features=TranslateUI \\
    --disk-cache-dir=/tmp/cache \\
    --overscroll-history-navigation=0 \\
    --disable-pinch \\
    --check-for-update-interval=31536000 \\
    --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT' \\
    http://localhost
EOF
    
    chmod +x "${KIOSK_HOME}/start-kiosk.sh"
    chown ${KIOSK_USER}:${KIOSK_USER} "${KIOSK_HOME}/start-kiosk.sh"
    
    log "Kiosk startup script created at ${KIOSK_HOME}/start-kiosk.sh"
}

# Setup autostart using systemd
setup_systemd_service() {
    log "Setting up systemd service for kiosk mode..."
    
    cat > /etc/systemd/system/kiosk.service <<EOF
[Unit]
Description=Chromium Kiosk Mode
After=network-online.target nginx.service
Wants=network-online.target

[Service]
Type=simple
User=${KIOSK_USER}
Environment=DISPLAY=:0
Environment=XAUTHORITY=${KIOSK_HOME}/.Xauthority
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/startx ${KIOSK_HOME}/start-kiosk.sh -- :0 vt7
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable the service
    systemctl daemon-reload
    systemctl enable kiosk.service
    
    log "Systemd service configured and enabled"
}

# Setup autologin
setup_autologin() {
    log "Setting up automatic login..."
    
    # For systems using getty (most modern systems)
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${KIOSK_USER} --noclear %I \$TERM
EOF
    
    systemctl daemon-reload
    
    log "Automatic login configured for user: ${KIOSK_USER}"
}

# Disable unnecessary services to improve boot time
optimize_boot() {
    log "Optimizing boot time..."
    
    # Disable unnecessary services
    systemctl disable bluetooth.service 2>/dev/null || true
    systemctl disable avahi-daemon.service 2>/dev/null || true
    systemctl disable triggerhappy.service 2>/dev/null || true
    
    log "Boot optimization completed"
}

# Create keyboard shortcuts config to prevent user from exiting
create_keyboard_config() {
    log "Creating keyboard shortcut configuration..."
    
    mkdir -p "${KIOSK_HOME}/.config/openbox"
    cat > "${KIOSK_HOME}/.config/openbox/rc.xml" <<'EOF'
<?xml version="1.0"?>
<openbox_config>
  <keyboard>
    <!-- Disable Alt+F4 -->
    <keybind key="A-F4">
      <action name="Execute">
        <command>true</command>
      </action>
    </keybind>
    <!-- Disable Ctrl+Alt+Delete -->
    <keybind key="C-A-Delete">
      <action name="Execute">
        <command>true</command>
      </action>
    </keybind>
    <!-- Disable other common shortcuts -->
    <keybind key="A-Tab"><action name="Execute"><command>true</command></action></keybind>
    <keybind key="C-A-Backspace"><action name="Execute"><command>true</command></action></keybind>
  </keyboard>
</openbox_config>
EOF
    
    chown -R ${KIOSK_USER}:${KIOSK_USER} "${KIOSK_HOME}/.config"
    
    log "Keyboard configuration created"
}

# Create emergency exit script (for maintenance)
create_emergency_exit() {
    log "Creating emergency exit script..."
    
    cat > /usr/local/bin/exit-kiosk <<'EOF'
#!/bin/bash
# Emergency script to exit kiosk mode
# Usage: sudo systemctl stop kiosk.service

systemctl stop kiosk.service
killall chromium 2>/dev/null || true
killall chromium-browser 2>/dev/null || true
killall X 2>/dev/null || true

echo "Kiosk mode stopped. To restart: sudo systemctl start kiosk.service"
EOF
    
    chmod +x /usr/local/bin/exit-kiosk
    
    log "Emergency exit script created at /usr/local/bin/exit-kiosk"
}

# Create watchdog to restart kiosk if it crashes
create_watchdog() {
    log "Creating kiosk watchdog..."
    
    cat > /usr/local/bin/kiosk-watchdog.sh <<'EOF'
#!/bin/bash
# Watchdog script to monitor and restart kiosk if needed

while true; do
    sleep 30
    
    # Check if Chromium is running (check for both process names)
    if ! pgrep -x chromium > /dev/null && ! pgrep -x chromium-browser > /dev/null; then
        logger "Kiosk watchdog: Chromium not running, restarting kiosk service"
        systemctl restart kiosk.service
    fi
    
    # Check if X server is running
    if ! pgrep -x X > /dev/null && ! pgrep -x Xorg > /dev/null; then
        logger "Kiosk watchdog: X server not running, restarting kiosk service"
        systemctl restart kiosk.service
    fi
done
EOF
    
    chmod +x /usr/local/bin/kiosk-watchdog.sh
    
    # Create systemd service for watchdog
    cat > /etc/systemd/system/kiosk-watchdog.service <<EOF
[Unit]
Description=Kiosk Watchdog
After=kiosk.service

[Service]
Type=simple
ExecStart=/usr/local/bin/kiosk-watchdog.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable kiosk-watchdog.service
    
    log "Watchdog service created and enabled"
}

# Create update script for easy updates
create_update_script() {
    log "Creating update script..."
    
    cat > /usr/local/bin/update-kiosk-app <<'EOF'
#!/bin/bash
# Script to update the kiosk application

echo "Stopping kiosk service..."
systemctl stop kiosk.service

echo "Updating application..."
cd /opt/react-ui-app
git pull || echo "No git repository, skipping git pull"
npm install
npm run build

# Copy new build
rm -rf /opt/react-ui-app/dist.old
mv /opt/react-ui-app/dist /opt/react-ui-app/dist.old 2>/dev/null || true
cp -r ./dist /opt/react-ui-app/

echo "Restarting services..."
systemctl restart nginx
systemctl start kiosk.service

echo "Update completed!"
EOF
    
    chmod +x /usr/local/bin/update-kiosk-app
    
    log "Update script created at /usr/local/bin/update-kiosk-app"
}

# Display final information
show_info() {
    log "Kiosk setup completed successfully!"
    echo ""
    echo -e "${BLUE}=== Kiosk Setup Information ===${NC}"
    echo -e "Kiosk User: ${KIOSK_USER}"
    echo -e "Application URL: ${APP_URL}"
    echo -e "Startup Script: ${KIOSK_HOME}/start-kiosk.sh"
    echo ""
    echo -e "${BLUE}=== Useful Commands ===${NC}"
    echo -e "Start kiosk: sudo systemctl start kiosk.service"
    echo -e "Stop kiosk: sudo systemctl stop kiosk.service"
    echo -e "Restart kiosk: sudo systemctl restart kiosk.service"
    echo -e "View kiosk logs: sudo journalctl -u kiosk.service -f"
    echo -e "Emergency exit: sudo /usr/local/bin/exit-kiosk"
    echo -e "Update app: sudo /usr/local/bin/update-kiosk-app"
    echo ""
    echo -e "${YELLOW}=== Important Notes ===${NC}"
    echo -e "1. The kiosk will start automatically after reboot"
    echo -e "2. To access the terminal, SSH from another machine"
    echo -e "3. To temporarily exit kiosk: Ctrl+Alt+F2 (terminal), Ctrl+Alt+F7 (back to GUI)"
    echo -e "4. For maintenance, stop the service first: sudo systemctl stop kiosk.service"
    echo ""
    echo -e "${GREEN}Reboot now to start kiosk mode: sudo reboot${NC}"
}

# Main function
main() {
    log "Starting Chromium Kiosk Mode setup..."
    
    check_root
    install_packages
    disable_screen_blanking
    create_kiosk_script
    setup_systemd_service
    setup_autologin
    optimize_boot
    create_keyboard_config
    create_emergency_exit
    create_watchdog
    create_update_script
    show_info
    
    log "Setup completed successfully!"
}

# Handle script interruption
trap 'error "Setup interrupted"' INT TERM

# Run main function
main "$@"

