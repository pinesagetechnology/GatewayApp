#!/usr/bin/env bash

################################################################################
# Deploy Sudo Fix to IoT Device
# 
# This script copies the fix-sudo-permissions.sh script to an IoT device
# and executes it to fix the sudoers configuration.
#
# Usage: ./deploy-sudo-fix.sh <user@host>
#
# Example:
#   ./deploy-sudo-fix.sh pi@192.168.1.100
#   ./deploy-sudo-fix.sh pi@nanopi.local
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
err() { echo -e "${RED}✗${NC} $1"; }
step() { echo -e "${BLUE}==>${NC} $1"; }

# Check arguments
if [ $# -lt 1 ]; then
    err "Missing required argument"
    echo ""
    echo "Usage: $0 <user@host>"
    echo ""
    echo "Example:"
    echo "  $0 pi@192.168.1.100"
    echo "  $0 pi@nanopi.local"
    echo ""
    exit 1
fi

TARGET="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIX_SCRIPT="$SCRIPT_DIR/MonitoringServiceAPI/scripts/fix-sudo-permissions.sh"

# Verify fix script exists
if [ ! -f "$FIX_SCRIPT" ]; then
    err "Fix script not found: $FIX_SCRIPT"
    exit 1
fi

echo ""
echo -e "${GREEN}==========================================================${NC}"
echo -e "${GREEN}  Deploy Sudo Fix to IoT Device${NC}"
echo -e "${GREEN}==========================================================${NC}"
echo ""
echo "Target: $TARGET"
echo "Script: $FIX_SCRIPT"
echo ""

# Step 1: Copy script to device
step "Copying fix script to device..."
if scp "$FIX_SCRIPT" "$TARGET:~/fix-sudo-permissions.sh"; then
    log "Script copied successfully"
else
    err "Failed to copy script"
    exit 1
fi
echo ""

# Step 2: Make script executable
step "Making script executable..."
if ssh "$TARGET" "chmod +x ~/fix-sudo-permissions.sh"; then
    log "Script is now executable"
else
    err "Failed to make script executable"
    exit 1
fi
echo ""

# Step 3: Execute script with sudo
step "Executing fix script on device..."
echo ""
echo -e "${YELLOW}Note: You may be prompted for the sudo password${NC}"
echo ""

if ssh -t "$TARGET" "sudo ~/fix-sudo-permissions.sh"; then
    echo ""
    log "Fix script executed successfully!"
else
    err "Fix script execution failed"
    exit 1
fi
echo ""

# Step 4: Cleanup
step "Cleaning up..."
ssh "$TARGET" "rm -f ~/fix-sudo-permissions.sh" || true
log "Cleanup complete"
echo ""

echo -e "${GREEN}==========================================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}==========================================================${NC}"
echo ""
echo "The sudoers configuration has been updated on $TARGET"
echo ""
echo "Next steps:"
echo "  1. Try creating a data source from the UI"
echo "  2. Monitor logs: ssh $TARGET \"sudo journalctl -u monitoringapi -f\""
echo ""

