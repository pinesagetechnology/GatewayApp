#!/bin/bash

# Kiosk Mode Removal Script
# Description: Completely removes kiosk mode and returns system to normal
# Author: Senior Software Engineer
# Usage: sudo bash remove-kiosk.sh

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KIOSK_USER="${SUDO_USER:-pi}"

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

# Display warning
show_warning() {
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  WARNING: This will remove kiosk mode completely      ║${NC}"
    echo -e "${YELLOW}║  and restore your system to normal desktop operation  ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "This will:"
    echo "  • Stop all kiosk services"
    echo "  • Remove kiosk configuration files"
    echo "  • Disable automatic login (optional)"
    echo "  • Remove watchdog services"
    echo "  • Clean up helper scripts"
    echo ""
    echo -e "${RED}Note: Your application files will NOT be removed${NC}"
    echo ""
}

# Remove Chromium kiosk
remove_chromium_kiosk() {
    log "Removing Chromium kiosk configuration..."
    
    # Stop and disable services
    systemctl stop kiosk.service 2>/dev/null || true
    systemctl disable kiosk.service 2>/dev/null || true
    systemctl stop kiosk-watchdog.service 2>/dev/null || true
    systemctl disable kiosk-watchdog.service 2>/dev/null || true
    
    # Remove systemd service files
    rm -f /etc/systemd/system/kiosk.service
    rm -f /etc/systemd/system/kiosk-watchdog.service
    
    # Remove startup scripts
    rm -f /home/${KIOSK_USER}/start-kiosk.sh
    rm -f /home/${KIOSK_USER}/.xserverrc
    
    # Remove helper scripts
    rm -f /usr/local/bin/exit-kiosk
    rm -f /usr/local/bin/update-kiosk-app
    rm -f /usr/local/bin/kiosk-watchdog.sh
    
    # Remove lightdm kiosk configuration
    rm -f /etc/lightdm/lightdm.conf.d/90-kiosk.conf
    
    # Remove keyboard configuration
    rm -rf /home/${KIOSK_USER}/.config/openbox
    
    systemctl daemon-reload
    
    log "✓ Chromium kiosk removed"
}

# Remove Electron kiosk
remove_electron_kiosk() {
    log "Removing Electron kiosk configuration..."
    
    # Stop and disable service
    systemctl stop electron-kiosk.service 2>/dev/null || true
    systemctl disable electron-kiosk.service 2>/dev/null || true
    
    # Remove systemd service file
    rm -f /etc/systemd/system/electron-kiosk.service
    
    # Remove helper scripts (but keep electron files in project)
    # We don't remove electron.js or electron-dist as user might want to keep them
    
    systemctl daemon-reload
    
    log "✓ Electron kiosk service removed"
    info "Note: Electron app files are kept in your project directory"
}

# Remove autologin
remove_autologin() {
    log "Removing automatic login..."
    
    # Remove getty autologin override
    rm -rf /etc/systemd/system/getty@tty1.service.d
    
    # Remove xinitrc if it contains our kiosk startup
    if [ -f /home/${KIOSK_USER}/.xinitrc ]; then
        if grep -q "kiosk\|electron" /home/${KIOSK_USER}/.xinitrc 2>/dev/null; then
            rm -f /home/${KIOSK_USER}/.xinitrc
            log "✓ Removed .xinitrc"
        fi
    fi
    
    # Remove startx from bashrc if present
    if [ -f /home/${KIOSK_USER}/.bashrc ]; then
        if grep -q "startx.*vt" /home/${KIOSK_USER}/.bashrc 2>/dev/null; then
            # Create backup
            cp /home/${KIOSK_USER}/.bashrc /home/${KIOSK_USER}/.bashrc.backup
            # Remove the startx lines
            sed -i '/startx.*vt/d' /home/${KIOSK_USER}/.bashrc
            sed -i '/DISPLAY.*tty/d' /home/${KIOSK_USER}/.bashrc
            log "✓ Removed startx from .bashrc"
        fi
    fi
    
    systemctl daemon-reload
    
    log "✓ Automatic login disabled"
}

# Restore normal PM2 if needed
check_pm2() {
    log "Checking PM2 services..."
    
    if command -v pm2 &> /dev/null; then
        su - ${KIOSK_USER} -c "pm2 list" 2>/dev/null || true
        log "PM2 is still installed (this is normal if you're running the web app)"
    fi
}

# Clean up display configuration
cleanup_display() {
    log "Cleaning up display configuration..."
    
    # Remove screen blanking configurations from user profile
    if [ -f /home/${KIOSK_USER}/.profile ]; then
        sed -i '/xset s off/d' /home/${KIOSK_USER}/.profile 2>/dev/null || true
        sed -i '/xset -dpms/d' /home/${KIOSK_USER}/.profile 2>/dev/null || true
        sed -i '/xset s noblank/d' /home/${KIOSK_USER}/.profile 2>/dev/null || true
    fi
    
    log "✓ Display configuration cleaned"
}

# Show final status
show_status() {
    echo ""
    log "Kiosk mode removal completed!"
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ System restored to normal desktop mode${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo ""
    echo "What's been done:"
    echo "  ✓ Kiosk services stopped and removed"
    echo "  ✓ Auto-start disabled"
    echo "  ✓ Configuration files removed"
    echo "  ✓ Helper scripts removed"
    
    if [ "$KEEP_AUTOLOGIN" = "yes" ]; then
        echo "  • Automatic login kept (as requested)"
    else
        echo "  ✓ Automatic login disabled"
    fi
    
    echo ""
    echo -e "${YELLOW}Note: Your web application is still running${NC}"
    echo "  • Access at: http://localhost"
    echo "  • Nginx status: $(systemctl is-active nginx 2>/dev/null || echo 'not running')"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Reboot to see normal desktop: sudo reboot"
    echo "  2. Or just logout and login normally"
    echo ""
    echo -e "${GREEN}To reinstall kiosk mode in the future:${NC}"
    echo "  bash scripts/setup-kiosk.sh"
    echo ""
}

# Main function
main() {
    check_root
    show_warning
    
    read -p "Do you want to proceed with removal? (yes/no): " -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
        log "Removal cancelled by user"
        exit 0
    fi
    
    echo ""
    read -p "Keep automatic login enabled? (yes/no): " -r
    echo
    KEEP_AUTOLOGIN="$REPLY"
    
    log "Starting kiosk removal process..."
    echo ""
    
    # Remove both types (safe to run even if only one is installed)
    remove_chromium_kiosk
    remove_electron_kiosk
    
    if [[ ! $KEEP_AUTOLOGIN =~ ^[Yy]es$ ]]; then
        remove_autologin
    fi
    
    cleanup_display
    check_pm2
    show_status
    
    echo ""
    read -p "Would you like to reboot now? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Rebooting system..."
        sleep 2
        reboot
    else
        log "Please reboot manually when convenient: sudo reboot"
    fi
}

# Handle script interruption
trap 'error "Removal interrupted"' INT TERM

# Run main function
main "$@"

