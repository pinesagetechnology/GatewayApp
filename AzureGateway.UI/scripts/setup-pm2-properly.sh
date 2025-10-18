#!/bin/bash

# Proper PM2 Setup Script
# Description: Sets up PM2 correctly with systemd for automatic startup
# Usage: bash setup-pm2-properly.sh

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
    exit 1
}

info() {
    echo -e "${BLUE}$1${NC}"
}

# Detect current user
CURRENT_USER="${USER}"
USER_HOME="${HOME}"

log "Setting up PM2 for user: ${CURRENT_USER}"
echo ""

# Check if PM2 is installed
if ! command -v pm2 &> /dev/null; then
    error "PM2 is not installed! Run: sudo npm install -g pm2"
fi

# Check if app directory exists
APP_DIR="/opt/react-ui-app"
if [ ! -d "$APP_DIR" ]; then
    error "Application directory not found: $APP_DIR"
fi

# 1. Start PM2 daemon
log "Starting PM2 daemon..."
pm2 ping || pm2 update

# 2. Start the application
log "Starting application..."
cd "$APP_DIR"

# Check if ecosystem file exists
if [ -f "ecosystem.config.js" ]; then
    log "Using ecosystem.config.js..."
    pm2 delete all 2>/dev/null || true
    pm2 start ecosystem.config.js
else
    warn "ecosystem.config.js not found, using direct command..."
    pm2 delete ui-app 2>/dev/null || true
    pm2 start "npx serve -s dist -l 3001" --name ui-app
fi

# 3. Save PM2 process list
log "Saving PM2 process list..."
pm2 save --force

# 4. Verify dump file exists
if [ ! -f "${USER_HOME}/.pm2/dump.pm2.bak" ]; then
    error "PM2 dump file not created! Something went wrong."
fi

log "✓ PM2 dump file created successfully"

# 5. Create proper systemd service using PM2's built-in method
log "Setting up PM2 systemd startup..."

# Remove any existing startup
sudo env PATH=$PATH:/usr/bin pm2 unstartup systemd 2>/dev/null || true

# Create new startup
log "Creating systemd service..."
sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u ${CURRENT_USER} --hp ${USER_HOME}

# The above command creates the service, now we need to save our process list again
pm2 save --force

# 6. Enable and start the service
SERVICE_NAME="pm2-${CURRENT_USER}.service"
log "Enabling ${SERVICE_NAME}..."

sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}

# Test if the service can start
log "Testing service startup..."
sudo systemctl restart ${SERVICE_NAME}

sleep 3

# 7. Verify everything is working
log "Verifying setup..."
echo ""

if sudo systemctl is-active --quiet ${SERVICE_NAME}; then
    log "✓ PM2 service is active"
else
    error "PM2 service failed to start. Check: sudo journalctl -u ${SERVICE_NAME} -n 50"
fi

if pm2 list | grep -q "online"; then
    log "✓ PM2 apps are running"
else
    error "PM2 apps are not running"
fi

echo ""
log "════════════════════════════════════════════"
log "✓ PM2 Setup Complete!"
log "════════════════════════════════════════════"
echo ""

info "PM2 Status:"
pm2 list
echo ""

info "Systemd Service Status:"
sudo systemctl status ${SERVICE_NAME} --no-pager | head -15
echo ""

log "PM2 will now start automatically on boot"
log "Service name: ${SERVICE_NAME}"
echo ""

