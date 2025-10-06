#!/usr/bin/env bash

# Fix SQLite Database Permissions for Shared Access
# This script fixes permission issues for existing installations where
# MonitoringServiceAPI cannot access the databases of APIMonitorWorkerService
# and FileMonitorWorkerService.

set -e  # Exit on any error

# Configuration
SHARED_GROUP="monitor-services"
APIMONITOR_DATA_PATH="/var/apimonitor"
FILEMONITOR_DATA_PATH="/var/filemonitor"
MONITORINGAPI_DATA_PATH="/var/monitoringapi"

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
    log_info "Running as root"
}

# Parse command line arguments for custom paths
while [[ $# -gt 0 ]]; do
    case $1 in
        --apimonitor-data)
            APIMONITOR_DATA_PATH="$2"
            shift 2
            ;;
        --filemonitor-data)
            FILEMONITOR_DATA_PATH="$2"
            shift 2
            ;;
        --monitoringapi-data)
            MONITORINGAPI_DATA_PATH="$2"
            shift 2
            ;;
        -h|--help)
            echo "Fix SQLite Database Permissions for Shared Access"
            echo ""
            echo "Usage: sudo $0 [options]"
            echo ""
            echo "Options:"
            echo "  --apimonitor-data PATH       APIMonitor data directory (default: /var/apimonitor)"
            echo "  --filemonitor-data PATH      FileMonitor data directory (default: /var/filemonitor)"
            echo "  --monitoringapi-data PATH    MonitoringAPI data directory (default: /var/monitoringapi)"
            echo "  -h, --help                   Show this help"
            echo ""
            echo "This script fixes permission issues by:"
            echo "  1. Creating a shared group (monitor-services)"
            echo "  2. Adding all service users to the shared group"
            echo "  3. Setting proper group ownership on database directories"
            echo "  4. Setting proper permissions (775 for dirs, 664 for db files)"
            echo "  5. Restarting services to apply changes"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Main fix process
main() {
    echo -e "${GREEN}=== Fix Database Permissions ===${NC}"
    echo ""
    
    check_root
    
    # Step 1: Create shared group
    log_step "Creating shared group '$SHARED_GROUP'..."
    if ! getent group "$SHARED_GROUP" &>/dev/null; then
        groupadd "$SHARED_GROUP"
        log_info "Created shared group: $SHARED_GROUP"
    else
        log_info "Shared group already exists"
    fi
    echo ""
    
    # Step 2: Add users to shared group
    log_step "Adding service users to shared group..."
    
    for user in monitoringapi apimonitor filemonitor; do
        if id "$user" &>/dev/null; then
            usermod -a -G "$SHARED_GROUP" "$user"
            log_info "Added $user to $SHARED_GROUP"
        else
            log_warn "User $user does not exist (service may not be installed)"
        fi
    done
    echo ""
    
    # Step 3: Fix permissions for each service
    fix_permissions() {
        local data_path=$1
        local service_user=$2
        local service_name=$3
        
        if [ ! -d "$data_path" ]; then
            log_warn "$service_name data directory not found: $data_path"
            return 0
        fi
        
        log_step "Fixing permissions for $service_name..."
        
        # Create database directory if it doesn't exist
        mkdir -p "$data_path/database"
        
        # Set group ownership
        chgrp -R "$SHARED_GROUP" "$data_path"
        log_info "Set group ownership to $SHARED_GROUP"
        
        # Set directory permissions (775 = rwxrwxr-x)
        chmod 775 "$data_path/database"
        log_info "Set database directory permissions to 775"
        
        # Set database file permissions (664 = rw-rw-r--)
        if ls "$data_path/database/"*.db 1> /dev/null 2>&1; then
            chmod 664 "$data_path/database/"*.db
            log_info "Set database file permissions to 664"
            
            # Also fix WAL and SHM files if they exist
            if ls "$data_path/database/"*.db-wal 1> /dev/null 2>&1; then
                chmod 664 "$data_path/database/"*.db-wal
                log_info "Fixed WAL file permissions"
            fi
            if ls "$data_path/database/"*.db-shm 1> /dev/null 2>&1; then
                chmod 664 "$data_path/database/"*.db-shm
                log_info "Fixed SHM file permissions"
            fi
        else
            log_warn "No database files found (will be created with correct permissions)"
        fi
        
        echo ""
    }
    
    # Fix permissions for each service
    fix_permissions "$APIMONITOR_DATA_PATH" "apimonitor" "APIMonitorWorkerService"
    fix_permissions "$FILEMONITOR_DATA_PATH" "filemonitor" "FileMonitorWorkerService"
    
    # MonitoringServiceAPI has no database directory - just fix general permissions
    if [ -d "$MONITORINGAPI_DATA_PATH" ]; then
        log_step "Fixing permissions for MonitoringServiceAPI (no database directory)..."
        chgrp -R "$SHARED_GROUP" "$MONITORINGAPI_DATA_PATH"
        chmod 755 "$MONITORINGAPI_DATA_PATH"
        log_info "Set MonitoringServiceAPI directory permissions"
    else
        log_warn "MonitoringServiceAPI data directory not found: $MONITORINGAPI_DATA_PATH"
    fi
    
    # Step 4: Restart services
    log_step "Restarting services to apply group membership..."
    
    for service in apimonitor filemonitor monitoringapi; do
        if systemctl is-enabled "$service" &>/dev/null; then
            if systemctl restart "$service"; then
                log_info "Restarted $service"
            else
                log_warn "Failed to restart $service (check service status)"
            fi
        else
            log_warn "Service $service not found or not enabled"
        fi
    done
    echo ""
    
    # Summary
    echo -e "${GREEN}=== Fix Complete ===${NC}"
    echo ""
    echo "Database directories:"
    echo "  APIMonitor:     $APIMONITOR_DATA_PATH/database"
    echo "  FileMonitor:    $FILEMONITOR_DATA_PATH/database"
    echo "  MonitoringAPI:  NO DATABASE (accesses other services' databases)"
    echo ""
    echo "All services should now be able to access each other's databases."
    echo ""
    echo "To verify:"
    echo "  sudo systemctl status apimonitor"
    echo "  sudo systemctl status filemonitor"
    echo "  sudo systemctl status monitoringapi"
    echo ""
    echo "Check logs for any remaining errors:"
    echo "  sudo journalctl -u monitoringapi -n 50"
}

main "$@"

