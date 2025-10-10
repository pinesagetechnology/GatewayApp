#!/usr/bin/env bash

################################################################################
# Fix Sudo Permissions for MonitoringServiceAPI - PRODUCTION VERSION
# 
# This script configures passwordless sudo access for the monitoringapi service
# to execute permission scripts and system commands.
#
# SAFE FEATURES:
# - Validates syntax BEFORE installing
# - Creates automatic backups
# - Rolls back on any error
# - Cannot break existing sudo configuration
#
# Usage: sudo ./fix-sudo-permissions.sh
################################################################################

set -e

# Colors
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

# Validate sudoers file syntax
validate_sudoers() {
    local file=$1
    if visudo -c -f "$file" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

main() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Fix Sudo Permissions - MonitoringAPI${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    check_root
    
    local service_user="monitoringapi"
    local install_path="/opt/monitoringapi"
    local sudoers_file="/etc/sudoers.d/monitoringapi"
    local temp_file="/tmp/monitoringapi_sudoers.tmp"
    
    # Step 1: Check if service user exists
    log_step "Checking if monitoringapi user exists..."
    if ! id "$service_user" &>/dev/null; then
        log_error "User $service_user does not exist"
        log_error "Please install MonitoringServiceAPI first"
        exit 1
    fi
    log_info "User $service_user exists"
    echo ""
    
    # Step 2: Backup existing configuration
    log_step "Backing up existing sudoers configuration..."
    if [ -f "$sudoers_file" ]; then
        backup_file="${sudoers_file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$sudoers_file" "$backup_file"
        log_info "Backup created: $backup_file"
    else
        log_warn "No existing sudoers file found (this is OK for first install)"
    fi
    echo ""
    
    # Step 3: Create new configuration in temp file
    log_step "Creating sudoers configuration..."
    
    # CRITICAL: Each command on ONE line - NO line continuations
    cat > "$temp_file" << 'EOF'
# Limited sudo access for monitoringapi
# Production configuration - each command on separate line for reliability

monitoringapi ALL=(ALL) NOPASSWD: /bin/bash /opt/monitoringapi/scripts/fix-monitored-folder-permissions.sh
monitoringapi ALL=(ALL) NOPASSWD: /bin/bash /opt/monitoringapi/scripts/fix-monitored-folder-permissions.sh *
monitoringapi ALL=(ALL) NOPASSWD: /usr/bin/bash /opt/monitoringapi/scripts/fix-monitored-folder-permissions.sh
monitoringapi ALL=(ALL) NOPASSWD: /usr/bin/bash /opt/monitoringapi/scripts/fix-monitored-folder-permissions.sh *
monitoringapi ALL=(ALL) NOPASSWD: /bin/bash scripts/fix-monitored-folder-permissions.sh
monitoringapi ALL=(ALL) NOPASSWD: /bin/bash scripts/fix-monitored-folder-permissions.sh *
monitoringapi ALL=(ALL) NOPASSWD: /usr/bin/bash scripts/fix-monitored-folder-permissions.sh
monitoringapi ALL=(ALL) NOPASSWD: /usr/bin/bash scripts/fix-monitored-folder-permissions.sh *
monitoringapi ALL=(ALL) NOPASSWD: /bin/mkdir, /bin/rm, /bin/rmdir, /bin/chmod, /bin/chown, /bin/chgrp
monitoringapi ALL=(ALL) NOPASSWD: /bin/systemctl restart monitoringapi
monitoringapi ALL=(ALL) NOPASSWD: /bin/systemctl restart apimonitor
monitoringapi ALL=(ALL) NOPASSWD: /bin/systemctl restart filemonitor
monitoringapi ALL=(ALL) NOPASSWD: /bin/systemctl status monitoringapi
monitoringapi ALL=(ALL) NOPASSWD: /bin/systemctl status apimonitor
monitoringapi ALL=(ALL) NOPASSWD: /bin/systemctl status filemonitor
monitoringapi ALL=(ALL) NOPASSWD: /usr/sbin/usermod -a -G monitor-services *
EOF
    
    log_info "Configuration created in temporary file"
    echo ""
    
    # Step 4: Validate syntax BEFORE installing
    log_step "Validating sudoers syntax..."
    if validate_sudoers "$temp_file"; then
        log_info "✓ Syntax validation PASSED"
    else
        log_error "✗ Syntax validation FAILED"
        log_error "Configuration has errors and will NOT be installed"
        rm -f "$temp_file"
        exit 1
    fi
    echo ""
    
    # Step 5: Install validated configuration
    log_step "Installing sudoers configuration..."
    cp "$temp_file" "$sudoers_file"
    chmod 440 "$sudoers_file"
    rm -f "$temp_file"
    log_info "Installed to: $sudoers_file"
    echo ""
    
    # Step 6: Final validation of installed file
    log_step "Final validation of installed configuration..."
    if validate_sudoers "$sudoers_file"; then
        log_info "✓ Installation successful"
    else
        log_error "✗ Installed file validation failed"
        
        # Rollback to backup
        if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
            log_warn "Rolling back to backup..."
            cp "$backup_file" "$sudoers_file"
            log_info "Backup restored"
        else
            log_warn "Removing broken configuration..."
            rm -f "$sudoers_file"
            log_info "Broken file removed"
        fi
        
        exit 1
    fi
    echo ""
    
    # Step 7: Test sudo access (optional)
    log_step "Testing sudo access..."
    if [ -f "$install_path/scripts/fix-monitored-folder-permissions.sh" ]; then
        if sudo -u "$service_user" sudo -n /bin/mkdir --help &>/dev/null 2>&1; then
            log_info "✓ Service user can execute sudo commands"
        else
            log_warn "Cannot test sudo execution (service may need restart)"
        fi
    else
        log_warn "Permission script not found - cannot test (this is OK)"
    fi
    echo ""
    
    # Step 8: Restart service if running
    log_step "Restarting monitoringapi service..."
    if systemctl is-active --quiet monitoringapi 2>/dev/null; then
        if systemctl restart monitoringapi; then
            sleep 2
            if systemctl is-active --quiet monitoringapi; then
                log_info "✓ Service restarted successfully"
            else
                log_error "Service failed to start after restart"
                log_warn "Check logs: sudo journalctl -u monitoringapi -n 50"
            fi
        else
            log_error "Failed to restart service"
        fi
    else
        log_warn "Service not running - start it with: sudo systemctl start monitoringapi"
    fi
    echo ""
    
    # Success message
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Configuration Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "✓ Sudoers file validated and installed"
    echo "✓ Service can now execute permission scripts with sudo"
    echo "✓ Backup available at: $backup_file"
    echo ""
    echo "Next steps:"
    echo "  1. Create a data source from the UI"
    echo "  2. Monitor logs: sudo journalctl -u monitoringapi -f"
    echo ""
    
    if [ -n "$backup_file" ]; then
        echo "To rollback if needed:"
        echo "  sudo cp $backup_file $sudoers_file"
        echo ""
    fi
}

# Run main function
main "$@"
