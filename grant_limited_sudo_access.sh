#!/usr/bin/env bash

################################################################################
# Grant Limited Sudo Access to Monitoring Services
# 
# This script grants specific sudo permissions to service users for:
# - File and folder operations (create, delete, move, copy)
# - Permission management (chmod, chown)
# - Running specific monitoring scripts
#
# Usage: sudo ./grant_limited_sudo_access.sh
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

# Create sudoers configuration for a service
create_sudoers_config() {
    local service_name=$1
    local service_user=$2
    local install_path=$3
    local sudoers_file="/etc/sudoers.d/${service_name}"
    
    log_step "Configuring limited sudo access for ${service_user}..."
    
    # Check if user exists
    if ! id "$service_user" &>/dev/null; then
        log_warn "User $service_user does not exist (service may not be installed yet)"
        log_warn "Skipping sudo configuration for $service_user"
        return 0
    fi
    
    # Create sudoers configuration
    cat > "$sudoers_file" << EOF
# Limited sudo access for ${service_name}
# Allows ${service_user} to perform file/folder operations and run monitoring scripts

# File and directory operations
${service_user} ALL=(ALL) NOPASSWD: /bin/mkdir, /bin/mkdir *
${service_user} ALL=(ALL) NOPASSWD: /bin/rm, /bin/rm *
${service_user} ALL=(ALL) NOPASSWD: /bin/rmdir, /bin/rmdir *
${service_user} ALL=(ALL) NOPASSWD: /bin/mv, /bin/mv *
${service_user} ALL=(ALL) NOPASSWD: /bin/cp, /bin/cp *

# Permission management (restricted to monitoring paths)
${service_user} ALL=(ALL) NOPASSWD: /bin/chmod *
${service_user} ALL=(ALL) NOPASSWD: /bin/chown *
${service_user} ALL=(ALL) NOPASSWD: /bin/chgrp *

# Touch files (for creating empty files)
${service_user} ALL=(ALL) NOPASSWD: /bin/touch, /bin/touch *

# Run shell scripts (restricted to specific paths)
${service_user} ALL=(ALL) NOPASSWD: /bin/bash ${install_path}/scripts/*.sh
${service_user} ALL=(ALL) NOPASSWD: /usr/bin/bash ${install_path}/scripts/*.sh
${service_user} ALL=(ALL) NOPASSWD: /bin/sh ${install_path}/scripts/*.sh

# Allow running scripts from monitored folders (for processing)
${service_user} ALL=(ALL) NOPASSWD: /bin/bash /var/${service_name}/*
${service_user} ALL=(ALL) NOPASSWD: /bin/bash /home/*/workspace/*
${service_user} ALL=(ALL) NOPASSWD: /bin/bash /home/*/monitored/*

# Service management (only for restarting own service)
${service_user} ALL=(ALL) NOPASSWD: /bin/systemctl restart ${service_name}
${service_user} ALL=(ALL) NOPASSWD: /bin/systemctl status ${service_name}
EOF
    
    # Set correct permissions (CRITICAL)
    chmod 440 "$sudoers_file"
    
    # Validate syntax
    if validate_sudoers "$sudoers_file"; then
        log_info "Created sudoers configuration: $sudoers_file"
    else
        log_error "Failed to create valid sudoers configuration"
        rm -f "$sudoers_file"
        return 1
    fi
    
    return 0
}

# Create special sudoers for MonitoringServiceAPI (needs broader script access)
create_monitoringapi_sudoers() {
    local service_user="monitoringapi"
    local install_path="/opt/monitoringapi"
    local sudoers_file="/etc/sudoers.d/monitoringapi"
    
    log_step "Configuring limited sudo access for ${service_user}..."
    
    # Check if user exists
    if ! id "$service_user" &>/dev/null; then
        log_warn "User $service_user does not exist (service may not be installed yet)"
        log_warn "Skipping sudo configuration for $service_user"
        return 0
    fi
    
    # Create sudoers configuration (MonitoringAPI needs access to permission scripts)
    cat > "$sudoers_file" << EOF
# Limited sudo access for monitoringapi
# Allows monitoringapi to perform file/folder operations, run scripts, and manage permissions

# File and directory operations
${service_user} ALL=(ALL) NOPASSWD: /bin/mkdir, /bin/mkdir *
${service_user} ALL=(ALL) NOPASSWD: /bin/rm, /bin/rm *
${service_user} ALL=(ALL) NOPASSWD: /bin/rmdir, /bin/rmdir *
${service_user} ALL=(ALL) NOPASSWD: /bin/mv, /bin/mv *
${service_user} ALL=(ALL) NOPASSWD: /bin/cp, /bin/cp *

# Permission management (for fixing monitored folder permissions)
${service_user} ALL=(ALL) NOPASSWD: /bin/chmod *
${service_user} ALL=(ALL) NOPASSWD: /bin/chown *
${service_user} ALL=(ALL) NOPASSWD: /bin/chgrp *

# Touch files
${service_user} ALL=(ALL) NOPASSWD: /bin/touch, /bin/touch *

# Run shell scripts (own scripts + permission fix scripts)
${service_user} ALL=(ALL) NOPASSWD: /bin/bash ${install_path}/scripts/*.sh
${service_user} ALL=(ALL) NOPASSWD: /usr/bin/bash ${install_path}/scripts/*.sh
${service_user} ALL=(ALL) NOPASSWD: /bin/sh ${install_path}/scripts/*.sh

# User management (for adding users to monitor-services group)
${service_user} ALL=(ALL) NOPASSWD: /usr/sbin/usermod -a -G monitor-services *

# Service management (can restart all monitoring services)
${service_user} ALL=(ALL) NOPASSWD: /bin/systemctl restart apimonitor
${service_user} ALL=(ALL) NOPASSWD: /bin/systemctl restart filemonitor
${service_user} ALL=(ALL) NOPASSWD: /bin/systemctl restart monitoringapi
${service_user} ALL=(ALL) NOPASSWD: /bin/systemctl status *
EOF
    
    # Set correct permissions (CRITICAL)
    chmod 440 "$sudoers_file"
    
    # Validate syntax
    if validate_sudoers "$sudoers_file"; then
        log_info "Created sudoers configuration: $sudoers_file"
    else
        log_error "Failed to create valid sudoers configuration"
        rm -f "$sudoers_file"
        return 1
    fi
    
    return 0
}

# Main function
main() {
    echo ""
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${GREEN}  Grant Limited Sudo Access to Monitoring Services${NC}"
    echo -e "${GREEN}==========================================================${NC}"
    echo ""
    
    check_root
    
    log_step "Setting up limited sudo access for monitoring services..."
    echo ""
    
    # Configure sudo access for each service
    create_sudoers_config "apimonitor" "apimonitor" "/opt/apimonitor"
    echo ""
    
    create_sudoers_config "filemonitor" "filemonitor" "/opt/filemonitor"
    echo ""
    
    create_monitoringapi_sudoers
    echo ""
    
    # Validate overall sudoers configuration
    log_step "Validating overall sudoers configuration..."
    if visudo -c &>/dev/null; then
        log_info "All sudoers configurations are valid"
    else
        log_error "Sudoers configuration validation failed!"
        log_error "This should not happen - please check /etc/sudoers.d/ manually"
        exit 1
    fi
    echo ""
    
    # Show what was configured
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${GREEN}  Configuration Complete${NC}"
    echo -e "${GREEN}==========================================================${NC}"
    echo ""
    echo "Service users now have limited sudo access for:"
    echo ""
    echo -e "${BLUE}File/Folder Operations:${NC}"
    echo "  • Create directories (mkdir)"
    echo "  • Delete files and directories (rm, rmdir)"
    echo "  • Move files (mv)"
    echo "  • Copy files (cp)"
    echo "  • Create empty files (touch)"
    echo ""
    echo -e "${BLUE}Permission Management:${NC}"
    echo "  • Change permissions (chmod)"
    echo "  • Change ownership (chown, chgrp)"
    echo ""
    echo -e "${BLUE}Script Execution:${NC}"
    echo "  • Run scripts from /opt/[service]/scripts/"
    echo "  • Run scripts from monitored folders"
    echo ""
    echo -e "${BLUE}Service Management:${NC}"
    echo "  • Restart own service"
    echo "  • Check service status"
    echo ""
    
    # Show configured users
    echo "Configured sudoers files:"
    for sudoers_file in /etc/sudoers.d/apimonitor /etc/sudoers.d/filemonitor /etc/sudoers.d/monitoringapi; do
        if [ -f "$sudoers_file" ]; then
            echo "  ✓ $sudoers_file"
        fi
    done
    echo ""
    
    # Show security note
    echo -e "${YELLOW}Security Note:${NC}"
    echo "  • Users can ONLY run the specific commands listed above"
    echo "  • Users CANNOT run arbitrary sudo commands"
    echo "  • Users CANNOT gain root shell access"
    echo "  • Users CANNOT modify system files outside allowed scope"
    echo ""
    
    # Test sudo access for each user
    log_step "Testing sudo access..."
    echo ""
    
    for user in apimonitor filemonitor monitoringapi; do
        if id "$user" &>/dev/null; then
            if sudo -u "$user" sudo -n -l &>/dev/null; then
                log_info "$user can use sudo (limited commands)"
            else
                log_warn "$user cannot use sudo (may need to logout/login or restart service)"
            fi
        fi
    done
    echo ""
    
    echo -e "${GREEN}✓ Setup complete!${NC}"
    echo ""
    echo "To apply changes to running services, restart them:"
    echo "  sudo systemctl restart apimonitor"
    echo "  sudo systemctl restart filemonitor"
    echo "  sudo systemctl restart monitoringapi"
    echo ""
}

# Run main function
main "$@"

