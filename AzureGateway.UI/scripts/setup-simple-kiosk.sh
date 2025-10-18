#!/bin/bash

# Simple Kiosk Mode Setup - One Script Solution
# Description: Sets up Chromium kiosk mode the SIMPLE way
# Usage: sudo bash setup-simple-kiosk.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[✓] $1${NC}"
}

error() {
    echo -e "${RED}[✗] $1${NC}"
    exit 1
}

step() {
    echo -e "${BOLD}${BLUE}▶ $1${NC}"
}

header() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Check running as root
if [ "$EUID" -ne 0 ]; then
    error "Run this script with sudo"
fi

# Detect the real user
if [ -n "$SUDO_USER" ]; then
    KIOSK_USER="$SUDO_USER"
else
    read -p "Enter username for kiosk: " KIOSK_USER
fi

# Validate user exists
if ! id "$KIOSK_USER" &>/dev/null; then
    error "User '$KIOSK_USER' does not exist!"
fi

KIOSK_HOME="/home/${KIOSK_USER}"

header "Simple Kiosk Setup for ${KIOSK_USER}"

# ============================================================================
step "1. Installing required packages..."
# ============================================================================

apt update
apt install -y unclutter xdotool

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
    err "Chromium not found after installation"
    exit 1
fi

log "Packages installed (using $CHROMIUM_CMD)"

# ============================================================================
step "2. Removing old kiosk configurations..."
# ============================================================================

# Stop and remove old kiosk service if exists
systemctl stop kiosk.service 2>/dev/null || true
systemctl disable kiosk.service 2>/dev/null || true
rm -f /etc/systemd/system/kiosk.service
systemctl daemon-reload

log "Old configurations removed"

# ============================================================================
step "3. Ensuring desktop environment is enabled..."
# ============================================================================

systemctl set-default graphical.target

log "Desktop environment enabled"

# ============================================================================
step "4. Setting up auto-login..."
# ============================================================================

mkdir -p /etc/systemd/system/getty@tty1.service.d

cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${KIOSK_USER} --noclear %I \$TERM
EOF

log "Auto-login configured for ${KIOSK_USER}"

# ============================================================================
step "5. Disabling screen blanking..."
# ============================================================================

# Create X11 profile script
cat > /etc/X11/Xsession.d/90-disable-dpms <<'EOF'
#!/bin/sh
xset s off
xset s noblank
xset -dpms
EOF

chmod +x /etc/X11/Xsession.d/90-disable-dpms

log "Screen blanking disabled"

# ============================================================================
step "6. Creating kiosk autostart..."
# ============================================================================

# Create autostart directory
mkdir -p "${KIOSK_HOME}/.config/autostart"
mkdir -p "${KIOSK_HOME}/.config/lxsession/LXDE-pi"

# Hide desktop icons and panels
cat > "${KIOSK_HOME}/.config/lxsession/LXDE-pi/desktop.conf" <<'EOF'
[Session]
window_manager=openbox-lxde
windows_manager/command=openbox
windows_manager/session=LXDE
disable_autostart=no
polkit/command=lxpolkit
clipboard/command=lxclipboard
xsettings_manager/command=build-in
proxy_manager/command=build-in
keyring/command=ssh-agent
quit_manager/command=lxsession-logout
lock_manager/command=lxlock
terminal_manager/command=lxterminal
launcher_manager/command=lxpanelctl

[GTK]
sNet/ThemeName=PiX
sNet/IconThemeName=PiX
sGtk/FontName=PibotoLt 12
iGtk/ToolbarStyle=3
iGtk/ButtonImages=1
iGtk/MenuImages=1
iGtk/CursorThemeSize=24
iXft/Antialias=1
iXft/Hinting=1
sXft/HintStyle=hintslight
sXft/RGBA=rgb

[Mouse]
AccFactor=20
AccThreshold=10
LeftHanded=0

[Keyboard]
Delay=500
Interval=30
Beep=1

[State]
guess_default=true

[Dbus]
lxde=true

[Environment]
menu_prefix=lxde-pi-
EOF

# Create autostart script to hide desktop
cat > "${KIOSK_HOME}/.config/autostart/hide-desktop.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Hide Desktop
Exec=pcmanfm --desktop-off
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Hide cursor when idle
cat > "${KIOSK_HOME}/.config/autostart/unclutter.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Unclutter
Exec=unclutter -idle 0.1 -root
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Create kiosk startup script
cat > "${KIOSK_HOME}/.config/autostart/kiosk.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Kiosk Browser
Exec=/bin/bash -c "sleep 5 && $CHROMIUM_CMD --kiosk --noerrdialogs --disable-infobars --disable-session-crashed-bubble --disable-restore-session-state --no-first-run --disable-translate --disable-features=TranslateUI --check-for-update-interval=31536000 http://localhost"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Set ownership
chown -R ${KIOSK_USER}:${KIOSK_USER} "${KIOSK_HOME}/.config"

log "Kiosk autostart configured"

# ============================================================================
step "7. Configuring Openbox (window manager)..."
# ============================================================================

mkdir -p "${KIOSK_HOME}/.config/openbox"

cat > "${KIOSK_HOME}/.config/openbox/lxde-pi-rc.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <applications>
    <application class="Chromium-browser">
      <decor>no</decor>
      <maximized>yes</maximized>
      <fullscreen>yes</fullscreen>
    </application>
  </applications>
  <keyboard>
    <!-- Disable Alt+F4 -->
    <keybind key="A-F4">
      <action name="Execute"><command>true</command></action>
    </keybind>
    <!-- Disable other shortcuts -->
    <keybind key="C-A-Delete">
      <action name="Execute"><command>true</command></action>
    </keybind>
  </keyboard>
</openbox_config>
EOF

chown -R ${KIOSK_USER}:${KIOSK_USER} "${KIOSK_HOME}/.config/openbox"

log "Window manager configured"

# ============================================================================
step "8. Creating helper scripts..."
# ============================================================================

# Exit kiosk script
cat > /usr/local/bin/exit-kiosk <<'EOF'
#!/bin/bash
killall chromium-browser 2>/dev/null || true
echo "Kiosk browser closed. Desktop is now accessible."
echo "To restart kiosk: reboot or run 'chromium-browser --kiosk http://localhost'"
EOF

chmod +x /usr/local/bin/exit-kiosk

log "Helper scripts created"

# ============================================================================
step "9. Reload systemd..."
# ============================================================================

systemctl daemon-reload

log "Systemd reloaded"

# ============================================================================
header "Setup Complete!"
# ============================================================================

echo ""
echo -e "${GREEN}${BOLD}✓ Kiosk mode configured successfully!${NC}"
echo ""
echo -e "${BLUE}Configuration Summary:${NC}"
echo "  • User: ${KIOSK_USER}"
echo "  • Auto-login: Enabled"
echo "  • Kiosk URL: http://localhost"
echo "  • Desktop: Hidden"
echo "  • Cursor: Auto-hide when idle"
echo "  • Screen blanking: Disabled"
echo ""
echo -e "${BLUE}How it works:${NC}"
echo "  1. System boots and auto-logs in as ${KIOSK_USER}"
echo "  2. Desktop environment starts"
echo "  3. Chromium launches in kiosk mode automatically"
echo "  4. Your app displays in full-screen"
echo ""
echo -e "${BLUE}Emergency Access:${NC}"
echo "  • SSH: ssh ${KIOSK_USER}@<raspberry-pi-ip>"
echo "  • Exit kiosk: ${BOLD}exit-kiosk${NC} (closes browser, shows desktop)"
echo "  • Terminal: Press Ctrl+Alt+T or Ctrl+Alt+F2"
echo ""
echo -e "${YELLOW}Next Step:${NC}"
echo -e "${BOLD}sudo reboot${NC}"
echo ""
echo "After reboot, your app will display in full-screen kiosk mode."
echo ""

