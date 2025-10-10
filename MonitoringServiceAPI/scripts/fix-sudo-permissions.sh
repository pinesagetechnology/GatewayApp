#!/usr/bin/env bash

################################################################################
# Fix Sudo Permissions for MonitoringServiceAPI
# 
# This script fixes the sudoers configuration to allow the monitoringapi
# service to execute permission scripts with relative paths.
#
# Usage: sudo ./fix-sudo-permissions.sh
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_step() {
    echo -e "${BLUE}==>${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Validate sudoers syntax
validate_sudoers() {
    local file=$1
    if ! visudo -c -f "$file" &>/dev/null; then
        log_error "Invalid sudoers syntax in $file"
        return 1
    fi
    return 0
}

main() {
    echo ""
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${GREEN}  Fix Sudo Permissions for MonitoringServiceAPI${NC}"
    echo -e "${GREEN}==========================================================${NC}"
    echo ""
    
    check_root
    
    local service_user="monitoringapi"
    local install_path="/opt/monitoringapi"
    local sudoers_file="/etc/sudoers.d/monitoringapi"
    
    log_step "Checking if monitoringapi user exists..."
    if ! id "$service_user" &>/dev/null; then
        log_error "User $service_user does not exist"
        log_error "Please install MonitoringServiceAPI first"
        exit 1
    fi
    log_info "User $service_user exists"
    echo ""
    
    log_step "Backing up existing sudoers configuration..."
    if [ -f "$sudoers_file" ]; then
        cp "$sudoers_file" "${sudoers_file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backup created: ${sudoers_file}.backup.$(date +%Y%m%d_%H%M%S)"
    else
        log_warn "No existing sudoers file found"
    fi
    echo ""
    
    log_step "Creating new sudoers configuration..."
    
    # Create sudoers configuration with support for both absolute and relative paths
    cat > "$sudoers_file" << 'EOF'
# Limited sudo access for monitoringapi
# Updated to support both absolute and relative paths from WorkingDirectory

Cmnd_Alias MONITORING_FILE_OPS = /bin/mkdir, /bin/rm, /bin/rmdir, /bin/mv, /bin/cp, /bin/chmod, /bin/chown, /bin/chgrp, /bin/touch

# Script execution patterns:
# - Absolute paths: /bin/bash /opt/monitoringapi/scripts/*
# - Relative paths: bash scripts/* (from WorkingDirectory=/opt/monitoringapi)
# - With/without .sh extension
Cmnd_Alias MONITORING_SCRIPTS = \
    /bin/bash /opt/monitoringapi/scripts/*, \
    /usr/bin/bash /opt/monitoringapi/scripts/*, \
    /bin/bash /opt/monitoringapi/scripts/*.sh, \
    /usr/bin/bash /opt/monitoringapi/scripts/*.sh, \
    /bin/bash scripts/*, \
    /usr/bin/bash scripts/*, \
    /bin/bash scripts/*.sh, \
    /usr/bin/bash scripts/*.sh, \
    bash /opt/monitoringapi/scripts/*, \
    bash /opt/monitoringapi/scripts/*.sh, \
    bash scripts/*, \
    bash scripts/*.sh

Cmnd_Alias MONITORING_USER_MGT = /usr/sbin/usermod -a -G monitor-services *

Cmnd_Alias MONITORING_SERVICES = \
    /bin/systemctl restart apimonitor, \
    /bin/systemctl restart filemonitor, \
    /bin/systemctl restart monitoringapi, \
    /bin/systemctl status *

monitoringapi ALL=(ALL) NOPASSWD: MONITORING_FILE_OPS
monitoringapi ALL=(ALL) NOPASSWD: MONITORING_SCRIPTS
monitoringapi ALL=(ALL) NOPASSWD: MONITORING_USER_MGT
monitoringapi ALL=(ALL) NOPASSWD: MONITORING_SERVICES
EOF
    
    # Set correct permissions (CRITICAL for sudoers files)
    chmod 440 "$sudoers_file"
    log_info "Created sudoers file with correct permissions (440)"
    echo ""
    
    log_step "Validating sudoers syntax..."
    if validate_sudoers "$sudoers_file"; then
        log_info "Sudoers configuration is valid"
    else
        log_error "Sudoers configuration validation failed!"
        log_error "Restoring backup..."
        if [ -f "${sudoers_file}.backup."* ]; then
            mv "${sudoers_file}.backup."* "$sudoers_file"
            log_info "Backup restored"
        fi
        exit 1
    fi
    echo ""
    
    log_step "Testing sudo access..."
    if sudo -u "$service_user" sudo -n bash "$install_path/scripts/fix-monitored-folder-permissions.sh" --help &>/dev/null; then
        log_info "✓ Service can execute permission script with sudo (absolute path)"
    else
        log_error "Service cannot execute permission script with sudo (absolute path)"
    fi
    
    # Test with relative path (this is what the C# code uses)
    if sudo -u "$service_user" bash -c "cd $install_path && sudo -n bash scripts/fix-monitored-folder-permissions.sh --help" &>/dev/null; then
        log_info "✓ Service can execute permission script with sudo (relative path)"
    else
        log_warn "Service cannot execute permission script with sudo (relative path)"
    fi
    echo ""
    
    log_step "Restarting monitoringapi service to apply changes..."
    if systemctl is-active monitoringapi &>/dev/null; then
        systemctl restart monitoringapi
        log_info "Service restarted"
        
        # Wait a moment for service to start
        sleep 2
        
        if systemctl is-active monitoringapi &>/dev/null; then
            log_info "Service is running"
        else
            log_error "Service failed to start"
            echo ""
            echo "Check service status with:"
            echo "  sudo systemctl status monitoringapi"
            echo "  sudo journalctl -u monitoringapi -n 50"
        fi
    else
        log_warn "Service is not running - start it with: sudo systemctl start monitoringapi"
    fi
    echo ""
    
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${GREEN}  Fix Complete!${NC}"
    echo -e "${GREEN}==========================================================${NC}"
    echo ""
    echo "The monitoringapi service can now execute permission scripts"
    echo "using sudo without password prompts."
    echo ""
    echo "Supported command patterns:"
    echo "  • sudo bash /opt/monitoringapi/scripts/*.sh"
    echo "  • sudo bash scripts/*.sh (from /opt/monitoringapi)"
    echo ""
    echo "Try creating a data source again from the UI."
    echo ""
    
    # Show how to verify
    echo -e "${BLUE}To verify:${NC}"
    echo "  1. Check service logs:"
    echo "     sudo journalctl -u monitoringapi -f"
    echo ""
    echo "  2. Try creating a data source from the UI"
    echo ""
    echo "  3. Manual test:"
    echo "     sudo -u monitoringapi sudo -n bash scripts/fix-monitored-folder-permissions.sh --help"
    echo ""
}

# Run main function
main "$@"

