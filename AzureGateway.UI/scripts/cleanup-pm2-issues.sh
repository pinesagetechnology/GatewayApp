#!/bin/bash

# Complete PM2 Cleanup Script
# Description: Removes all broken PM2 configurations and prepares for clean reinstall
# Usage: bash cleanup-pm2-issues.sh

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

log "Starting complete PM2 cleanup..."
echo ""

# 1. Stop all PM2 systemd services
log "Stopping all PM2 systemd services..."
for service in pm2-*.service; do
    sudo systemctl stop "$service" 2>/dev/null || true
    sudo systemctl disable "$service" 2>/dev/null || true
done

# 2. Remove all PM2 systemd service files
log "Removing all PM2 systemd service files..."
sudo rm -f /etc/systemd/system/pm2-*.service
sudo rm -f /etc/systemd/system/pm2-*.service.bak
sudo systemctl daemon-reload

# 3. Kill PM2 daemon
log "Stopping PM2 daemon..."
pm2 kill 2>/dev/null || true

# 4. Save current app list before cleanup
log "Backing up current PM2 configuration..."
if pm2 list 2>/dev/null | grep -q "online"; then
    pm2 save --force 2>/dev/null || true
fi

# 5. Clean PM2 files (but keep dump)
log "Cleaning PM2 files..."
if [ -f ~/.pm2/dump.pm2.bak ]; then
    cp ~/.pm2/dump.pm2.bak ~/pm2-backup-$(date +%Y%m%d).json
    log "✓ Backup saved to ~/pm2-backup-$(date +%Y%m%d).json"
fi

# Remove logs and temp files but keep dump
rm -rf ~/.pm2/logs/*
rm -rf ~/.pm2/pids/*
rm -rf ~/.pm2/pm2.pid
rm -rf ~/.pm2/rpc.sock
rm -rf ~/.pm2/pub.sock

log "✓ PM2 cleanup completed"
echo ""
log "PM2 is now clean and ready for fresh setup"
echo ""

