#!/bin/bash

# Complete PM2 Fix - One Script Solution
# Description: Fixes all PM2 issues and sets up everything properly
# Usage: bash fix-all-pm2-issues.sh
# Run as: Regular user (not sudo), script will ask for sudo when needed

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

warn() {
    echo -e "${YELLOW}[!] $1${NC}"
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

# Check not running as root
if [ "$EUID" -eq 0 ]; then
    error "Don't run this script as root! Run as your regular user."
fi

CURRENT_USER="${USER}"
USER_HOME="${HOME}"
APP_DIR="/opt/react-ui-app"

header "Complete PM2 Fix for ${CURRENT_USER}"

echo "This script will:"
echo "  1. Clean up all broken PM2 configurations"
echo "  2. Remove faulty systemd services"
echo "  3. Set up PM2 correctly"
echo "  4. Configure automatic startup"
echo "  5. Verify everything works"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# ============================================================================
header "Step 1: Cleanup"
# ============================================================================

step "Stopping all PM2 services..."
sudo systemctl stop pm2-*.service 2>/dev/null || true
sudo systemctl disable pm2-*.service 2>/dev/null || true
log "Stopped PM2 services"

step "Removing broken service files..."
sudo rm -f /etc/systemd/system/pm2-*.service
sudo rm -f /etc/systemd/system/pm2-*.service.bak
sudo systemctl daemon-reload
log "Removed broken service files"

step "Backing up PM2 configuration..."
if pm2 list 2>/dev/null | grep -q "online"; then
    pm2 save --force 2>/dev/null || true
    if [ -f ~/.pm2/dump.pm2.bak ]; then
        cp ~/.pm2/dump.pm2.bak ~/pm2-backup-$(date +%Y%m%d).json
        log "Backup saved to ~/pm2-backup-$(date +%Y%m%d).json"
    fi
fi

step "Cleaning PM2 daemon..."
pm2 kill 2>/dev/null || true
log "PM2 daemon stopped"

step "Cleaning temporary files..."
rm -rf ~/.pm2/logs/* 2>/dev/null || true
rm -rf ~/.pm2/pids/* 2>/dev/null || true
rm -rf ~/.pm2/pm2.pid 2>/dev/null || true
rm -rf ~/.pm2/rpc.sock 2>/dev/null || true
rm -rf ~/.pm2/pub.sock 2>/dev/null || true
log "Temporary files cleaned"

# ============================================================================
header "Step 2: Setup PM2 Properly"
# ============================================================================

step "Checking PM2 installation..."
if ! command -v pm2 &> /dev/null; then
    error "PM2 is not installed! Run: sudo npm install -g pm2"
fi
log "PM2 is installed: $(pm2 --version)"

step "Checking application directory..."
if [ ! -d "$APP_DIR" ]; then
    error "Application directory not found: $APP_DIR"
fi
log "Application directory exists"

step "Starting PM2 daemon..."
pm2 ping
log "PM2 daemon is running"

step "Starting application..."
cd "$APP_DIR"

# Remove any existing processes
pm2 delete all 2>/dev/null || true

# Start the app
if [ -f "ecosystem.config.js" ]; then
    log "Using ecosystem.config.js"
    pm2 start ecosystem.config.js
else
    warn "ecosystem.config.js not found, using direct command"
    pm2 start "npx serve -s dist -l 3001" --name ui-app
fi

log "Application started"

# Verify app is running
if ! pm2 list | grep -q "online"; then
    error "Application failed to start! Check: pm2 logs"
fi

step "Saving PM2 process list..."
pm2 save --force

# Verify dump file was created
if [ ! -f "${USER_HOME}/.pm2/dump.pm2.bak" ]; then
    error "PM2 dump file was not created!"
fi
log "PM2 processes saved"

# ============================================================================
header "Step 3: Configure Systemd Startup"
# ============================================================================

step "Removing old PM2 startup configuration..."
sudo env PATH=$PATH:/usr/bin pm2 unstartup systemd 2>/dev/null || true
log "Old startup removed"

step "Creating new systemd service..."
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ${CURRENT_USER} --hp ${USER_HOME}

step "Saving PM2 configuration again..."
pm2 save --force

SERVICE_NAME="pm2-${CURRENT_USER}.service"
step "Enabling ${SERVICE_NAME}..."
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}

# ============================================================================
header "Step 4: Testing"
# ============================================================================

step "Starting PM2 service..."
sudo systemctl start ${SERVICE_NAME}

sleep 3

step "Verifying service status..."
if sudo systemctl is-active --quiet ${SERVICE_NAME}; then
    log "Service is active"
else
    error "Service failed to start! Check: sudo journalctl -u ${SERVICE_NAME} -n 50"
fi

step "Verifying PM2 apps..."
if pm2 list | grep -q "online"; then
    log "PM2 apps are running"
else
    error "PM2 apps are not running!"
fi

step "Testing web application..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    log "Web application is accessible (HTTP 200)"
else
    warn "Web application returned HTTP $HTTP_CODE"
fi

# ============================================================================
header "Complete! ✓"
# ============================================================================

echo ""
echo -e "${GREEN}${BOLD}┌────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}${BOLD}│  PM2 is now properly configured!          │${NC}"
echo -e "${GREEN}${BOLD}└────────────────────────────────────────────┘${NC}"
echo ""

echo -e "${BLUE}Current Status:${NC}"
pm2 list
echo ""

echo -e "${BLUE}Systemd Service:${NC}"
sudo systemctl status ${SERVICE_NAME} --no-pager | head -10
echo ""

echo -e "${BLUE}Important Information:${NC}"
echo "  • Service name: ${SERVICE_NAME}"
echo "  • User: ${CURRENT_USER}"
echo "  • App directory: ${APP_DIR}"
echo "  • PM2 will start automatically on boot"
echo ""

echo -e "${BLUE}Useful Commands:${NC}"
echo "  • View PM2 apps: ${BOLD}pm2 list${NC}"
echo "  • View PM2 logs: ${BOLD}pm2 logs${NC}"
echo "  • Restart service: ${BOLD}sudo systemctl restart ${SERVICE_NAME}${NC}"
echo "  • View service logs: ${BOLD}sudo journalctl -u ${SERVICE_NAME} -f${NC}"
echo ""

echo -e "${GREEN}${BOLD}You can now reboot to test automatic startup:${NC}"
echo -e "${BOLD}sudo reboot${NC}"
echo ""

