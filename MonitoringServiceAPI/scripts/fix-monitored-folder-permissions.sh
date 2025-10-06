#!/usr/bin/env bash

# Fix Monitored Folder Permissions for Monitoring Services
# This script sets up proper permissions for a monitored folder so that
# FileMonitorWorkerService and APIMonitorWorkerService can access it.

set -e  # Exit on any error

# Configuration
SHARED_GROUP="monitor-services"
MONITORED_FOLDER=""
OWNER_USER=""
VERBOSE=false

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

verbose_log() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    log_info "Running as root"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --folder)
            MONITORED_FOLDER="$2"
            shift 2
            ;;
        --owner)
            OWNER_USER="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Fix Monitored Folder Permissions for Monitoring Services"
            echo ""
            echo "Usage: sudo $0 [options]"
            echo ""
            echo "Options:"
            echo "  --folder PATH          Path to the monitored folder (required)"
            echo "  --owner USER           Owner of the folder (default: auto-detect)"
            echo "  --verbose              Enable verbose output"
            echo "  -h, --help             Show this help"
            echo ""
            echo "This script:"
            echo "  1. Ensures the monitored folder exists"
            echo "  2. Sets proper group ownership (monitor-services)"
            echo "  3. Sets appropriate permissions for read/write access"
            echo "  4. Ensures service users can access the folder"
            echo ""
            echo "Example:"
            echo "  sudo $0 --folder /home/username/workspace/monitored"
            echo "  sudo $0 --folder /home/username/workspace/monitored --owner username"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$MONITORED_FOLDER" ]; then
    log_error "Monitored folder path is required"
    echo "Use --folder PATH or --help for usage information"
    exit 1
fi

# Expand tilde and resolve relative paths
MONITORED_FOLDER=$(eval echo "$MONITORED_FOLDER")
if command -v realpath >/dev/null 2>&1; then
    MONITORED_FOLDER=$(realpath -m "$MONITORED_FOLDER")
fi

# Validate absolute path
if [[ ! "$MONITORED_FOLDER" =~ ^/ ]]; then
    log_error "Please provide an absolute path (starting with /)"
    exit 1
fi

# Auto-detect owner if not specified
if [ -z "$OWNER_USER" ]; then
    if [ -d "$MONITORED_FOLDER" ]; then
        OWNER_USER=$(stat -c '%U' "$MONITORED_FOLDER" 2>/dev/null || echo "")
        if [ -n "$OWNER_USER" ]; then
            log_info "Auto-detected owner: $OWNER_USER"
        fi
    fi
    
    # If still no owner, try to detect from path
    if [ -z "$OWNER_USER" ] && [[ "$MONITORED_FOLDER" =~ ^/home/([^/]+) ]]; then
        OWNER_USER="${BASH_REMATCH[1]}"
        log_info "Detected owner from path: $OWNER_USER"
    fi
fi

# Main fix process
main() {
    echo -e "${GREEN}=== Fix Monitored Folder Permissions ===${NC}"
    echo ""
    
    check_root
    
    log_step "Configuring monitored folder: $MONITORED_FOLDER"
    if [ -n "$OWNER_USER" ]; then
        echo "Owner user: $OWNER_USER"
    else
        echo "Owner user: (will use current owner)"
    fi
    echo "Shared group: $SHARED_GROUP"
    echo ""
    
    # Step 1: Ensure shared group exists
    log_step "Ensuring shared group exists..."
    if ! getent group "$SHARED_GROUP" &>/dev/null; then
        groupadd "$SHARED_GROUP"
        log_info "Created shared group: $SHARED_GROUP"
    else
        log_info "Shared group already exists"
    fi
    echo ""
    
    # Step 2: Add owner to shared group (if owner is specified and exists)
    if [ -n "$OWNER_USER" ] && id "$OWNER_USER" &>/dev/null; then
        log_step "Adding owner to shared group..."
        usermod -a -G "$SHARED_GROUP" "$OWNER_USER"
        log_info "Added $OWNER_USER to $SHARED_GROUP"
        echo ""
    elif [ -n "$OWNER_USER" ]; then
        log_warn "Owner user $OWNER_USER does not exist"
        echo ""
    fi
    
    # Step 3: Ensure parent directories exist and are accessible
    log_step "Ensuring parent directories exist and are accessible..."
    parent_dir=$(dirname "$MONITORED_FOLDER")
    if [ ! -d "$parent_dir" ]; then
        log_warn "Parent directory does not exist: $parent_dir"
        log_info "Creating parent directories..."
        
        # Create parent directories with appropriate permissions
        if [ -n "$OWNER_USER" ] && id "$OWNER_USER" &>/dev/null; then
            mkdir -p "$parent_dir"
            chown "$OWNER_USER:$SHARED_GROUP" "$parent_dir"
            chmod 775 "$parent_dir"
            log_info "Created parent directory: $parent_dir"
        else
            mkdir -p "$parent_dir"
            chgrp "$SHARED_GROUP" "$parent_dir"
            chmod 775 "$parent_dir"
            log_info "Created parent directory: $parent_dir"
        fi
    else
        log_info "Parent directory exists: $parent_dir"
    fi
    
    # Step 4: Create monitored folder if it doesn't exist
    log_step "Ensuring monitored folder exists..."
    if [ ! -d "$MONITORED_FOLDER" ]; then
        mkdir -p "$MONITORED_FOLDER"
        log_info "Created monitored folder: $MONITORED_FOLDER"
    else
        log_info "Monitored folder already exists"
    fi
    echo ""
    
    # Step 5: Set proper ownership and permissions
    log_step "Setting ownership and permissions..."
    
    # Set ownership (owner:monitor-services)
    if [ -n "$OWNER_USER" ] && id "$OWNER_USER" &>/dev/null; then
        chown -R "$OWNER_USER:$SHARED_GROUP" "$MONITORED_FOLDER"
        log_info "Set ownership to $OWNER_USER:$SHARED_GROUP"
    else
        # Keep current owner, but change group to monitor-services
        chgrp -R "$SHARED_GROUP" "$MONITORED_FOLDER"
        log_info "Set group ownership to $SHARED_GROUP"
    fi
    
    # Set directory permissions (775 = rwxrwxr-x)
    find "$MONITORED_FOLDER" -type d -exec chmod 775 {} \;
    log_info "Set directory permissions to 775"
    
    # Set file permissions (664 = rw-rw-r--)
    find "$MONITORED_FOLDER" -type f -exec chmod 664 {} \;
    log_info "Set file permissions to 664"
    
    # Set special permissions for executable files if any
    find "$MONITORED_FOLDER" -type f -name "*.sh" -exec chmod 775 {} \; 2>/dev/null || true
    find "$MONITORED_FOLDER" -type f -name "*.exe" -exec chmod 775 {} \; 2>/dev/null || true
    find "$MONITORED_FOLDER" -type f -name "*.bin" -exec chmod 775 {} \; 2>/dev/null || true
    log_info "Set executable permissions for script files"
    
    echo ""
    
    # Step 6: Ensure parent directories are accessible
    log_step "Checking parent directory permissions..."
    current_dir="$MONITORED_FOLDER"
    while [ "$current_dir" != "/" ]; do
        parent_dir=$(dirname "$current_dir")
        
        # Check if the parent directory allows group access
        if [ -d "$parent_dir" ]; then
            parent_perms=$(stat -c '%a' "$parent_dir" 2>/dev/null || echo "000")
            verbose_log "Checking $parent_dir (permissions: $parent_perms)"
            
            # Check if others have execute permission (needed to traverse directory)
            # Extract the last digit (others permissions)
            others_perm="${parent_perms: -1}"
            
            # If others don't have execute permission (last digit is 0,2,4,6), we need to fix it
            if [[ "$others_perm" =~ ^[0246]$ ]]; then
                log_warn "Parent directory $parent_dir lacks execute permission for others ($parent_perms)"
                
                # Add execute permission for others (add +1 to last digit)
                first_two="${parent_perms:0:2}"
                case "$others_perm" in
                    0) new_perms="${first_two}1" ;;
                    2) new_perms="${first_two}3" ;;
                    4) new_perms="${first_two}5" ;;
                    6) new_perms="${first_two}7" ;;
                esac
                
                chmod "$new_perms" "$parent_dir"
                log_info "Updated $parent_dir permissions from $parent_perms to $new_perms (added execute for others)"
            fi
        fi
        
        current_dir="$parent_dir"
        
        # Stop at /home to avoid changing system directories
        if [ "$current_dir" = "/home" ]; then
            break
        fi
    done
    echo ""
    
    # Step 7: Verify and add service users to shared group
    log_step "Ensuring service users are in shared group..."
    
    for service_user in apimonitor filemonitor; do
        if id "$service_user" &>/dev/null; then
            if groups "$service_user" | grep -q "$SHARED_GROUP"; then
                log_info "$service_user is already in $SHARED_GROUP"
            else
                usermod -a -G "$SHARED_GROUP" "$service_user"
                log_info "Added $service_user to $SHARED_GROUP"
            fi
        else
            log_warn "Service user $service_user does not exist"
        fi
    done
    echo ""
    
    # Step 8: Restart services to apply group membership
    log_step "Restarting monitoring services..."
    
    for service in apimonitor filemonitor; do
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
    
    # Step 9: Verify access
    log_step "Verifying access..."
    
    # Test if services can access the folder
    if [ -d "$MONITORED_FOLDER" ]; then
        # Test read access
        if sudo -u filemonitor test -r "$MONITORED_FOLDER"; then
            log_info "FileMonitor service can read the folder"
        else
            log_warn "FileMonitor service cannot read the folder"
        fi
        
        # Test write access
        if sudo -u filemonitor test -w "$MONITORED_FOLDER"; then
            log_info "FileMonitor service can write to the folder"
        else
            log_warn "FileMonitor service cannot write to the folder"
        fi
        
        # Test read access for APIMonitor
        if sudo -u apimonitor test -r "$MONITORED_FOLDER"; then
            log_info "APIMonitor service can read the folder"
        else
            log_warn "APIMonitor service cannot read the folder"
        fi
        
        # Test write access for APIMonitor
        if sudo -u apimonitor test -w "$MONITORED_FOLDER"; then
            log_info "APIMonitor service can write to the folder"
        else
            log_warn "APIMonitor service cannot write to the folder"
        fi
    else
        log_error "Monitored folder does not exist: $MONITORED_FOLDER"
    fi
    echo ""
    
    # Summary
    echo -e "${GREEN}=== Fix Complete ===${NC}"
    echo ""
    echo "Monitored folder: $MONITORED_FOLDER"
    echo "Owner: ${OWNER_USER:-$(stat -c '%U' "$MONITORED_FOLDER" 2>/dev/null || echo "unknown")}"
    echo "Group: $SHARED_GROUP"
    echo "Permissions: 775 (directories), 664 (files)"
    echo ""
    
    # Show actual permissions
    if [ -d "$MONITORED_FOLDER" ]; then
        echo "Actual folder permissions:"
        ls -ld "$MONITORED_FOLDER"
        echo ""
    fi
    
    # Show group memberships
    echo "Service user group memberships:"
    for service_user in apimonitor filemonitor; do
        if id "$service_user" &>/dev/null; then
            echo "  $service_user: $(groups $service_user 2>/dev/null || echo 'unknown')"
        fi
    done
    echo ""
    
    echo "Services should now be able to:"
    echo "  - Read files from the monitored folder"
    echo "  - Write API responses to the monitored folder"
    echo "  - Create subdirectories as needed"
    echo ""
    echo "To verify:"
    echo "  sudo systemctl status filemonitor"
    echo "  sudo systemctl status apimonitor"
    echo "  sudo journalctl -u filemonitor -n 20"
    echo "  sudo journalctl -u apimonitor -n 20"
}

# Run main function with all arguments
main "$@"
