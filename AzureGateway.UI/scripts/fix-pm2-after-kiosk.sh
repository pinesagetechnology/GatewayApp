#!/bin/bash

# Fix PM2 Service After Kiosk Setup
# Description: Repairs PM2 service if it fails after kiosk installation
# Usage: bash fix-pm2-after-kiosk.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}$1${NC}"
}

# Detect the service user
SERVICE_USER="${USER}"
if [ "$SERVICE_USER" = "root" ]; then
    SERVICE_USER="${SUDO_USER:-pi}"
fi

log "Fixing PM2 service for user: $SERVICE_USER"
echo ""

# Check if PM2 is installed
if ! command -v pm2 &> /dev/null; then
    error "PM2 is not installed!"
    echo "Run: sudo npm install -g pm2"
    exit 1
fi

log "✓ PM2 is installed"

# Check current PM2 status
log "Current PM2 status:"
pm2 list || true
echo ""

# Remove old PM2 systemd service
log "Removing old PM2 systemd service..."
sudo pm2 unstartup systemd 2>/dev/null || true
sudo systemctl stop pm2-${SERVICE_USER}.service 2>/dev/null || true
sudo systemctl disable pm2-${SERVICE_USER}.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/pm2-${SERVICE_USER}.service 2>/dev/null || true
sudo systemctl daemon-reload

log "✓ Old service removed"
echo ""

# Set up PM2 startup correctly
log "Setting up PM2 startup for user: $SERVICE_USER"
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $SERVICE_USER --hp /home/$SERVICE_USER

log "✓ PM2 startup configured"
echo ""

# Check if apps are running
log "Checking PM2 applications..."
APP_RUNNING=$(pm2 list | grep -c "online" || echo "0")

if [ "$APP_RUNNING" = "0" ]; then
    warn "No apps are currently running in PM2"
    echo ""
    info "Starting your application..."
    
    # Try to start from the app directory
    if [ -d "/opt/react-ui-app" ]; then
        cd /opt/react-ui-app
        if [ -f "ecosystem.config.js" ]; then
            pm2 start ecosystem.config.js
            log "✓ Application started"
        else
            warn "ecosystem.config.js not found. Starting manually..."
            pm2 start "npx serve -s dist -l 3001" --name ui-app
        fi
    else
        warn "App directory not found at /opt/react-ui-app"
        echo "You may need to start your app manually"
    fi
else
    log "✓ PM2 apps are running"
fi

echo ""
pm2 list
echo ""

# Save PM2 process list
log "Saving PM2 process list..."
pm2 save

log "✓ PM2 configuration saved"
echo ""

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable pm2-${SERVICE_USER}.service

log "✓ PM2 service enabled"
echo ""

# Check service status
log "Checking PM2 service status..."
if sudo systemctl is-active --quiet pm2-${SERVICE_USER}.service; then
    log "✓ PM2 service is active"
else
    warn "PM2 service is not active yet. Starting it..."
    sudo systemctl start pm2-${SERVICE_USER}.service
    sleep 2
    if sudo systemctl is-active --quiet pm2-${SERVICE_USER}.service; then
        log "✓ PM2 service started successfully"
    else
        error "PM2 service failed to start"
        echo ""
        echo "View logs with: sudo journalctl -u pm2-${SERVICE_USER}.service -n 50"
        exit 1
    fi
fi

echo ""
log "════════════════════════════════════════════"
log "✓ PM2 Fix Complete!"
log "════════════════════════════════════════════"
echo ""
info "Current PM2 Status:"
pm2 list
echo ""
info "Service Status:"
sudo systemctl status pm2-${SERVICE_USER}.service --no-pager | head -15
echo ""
log "PM2 will now start automatically on boot"
echo ""

