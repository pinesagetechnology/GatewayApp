#!/usr/bin/env bash

# Fix Monitored Folder Permissions for Monitoring Services
# This script sets up full access permissions for a monitored folder so that
# ALL users (FileMonitor, APIMonitor, and any other user) can access it.

set -e  # Exit on any error

# Configuration
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
            echo "Fix Monitored Folder Permissions - Full Access for Everyone"
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
            echo "  2. Sets full access permissions (777) - everyone can read/write/execute"
            echo "  3. No user/group restrictions"
            echo ""
            echo "Example:"
            echo "  sudo $0 --folder /home/pi/workspace/monitored"
            echo "  sudo $0 --folder /home/pi/workspace/monitored --owner pi"
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
    echo -e "${GREEN}=== Setup Monitored Folder - Full Access ===${NC}"
    echo ""
    
    check_root
    
    log_step "Configuring monitored folder: $MONITORED_FOLDER"
    if [ -n "$OWNER_USER" ]; then
        echo "Owner user: $OWNER_USER"
    else
        echo "Owner user: (will use current owner)"
    fi
    echo "Access: Full access for all users (777)"
    echo ""
    
    # Step 1: Ensure parent directories exist and are accessible
    log_step "Ensuring parent directories exist..."
    parent_dir=$(dirname "$MONITORED_FOLDER")
    if [ ! -d "$parent_dir" ]; then
        log_warn "Parent directory does not exist: $parent_dir"
        log_info "Creating parent directories..."
        mkdir -p "$parent_dir"
        chmod 777 "$parent_dir"
        log_info "Created parent directory with full access: $parent_dir"
    else
        log_info "Parent directory exists: $parent_dir"
    fi
    echo ""
    
    # Step 2: Create monitored folder if it doesn't exist
    log_step "Ensuring monitored folder exists..."
    if [ ! -d "$MONITORED_FOLDER" ]; then
        mkdir -p "$MONITORED_FOLDER"
        log_info "Created monitored folder: $MONITORED_FOLDER"
    else
        log_info "Monitored folder already exists"
    fi
    echo ""
    
    # Step 3: Set full access permissions for everyone
    log_step "Setting full access permissions..."
    
    # Set ownership to current user if specified
    if [ -n "$OWNER_USER" ] && id "$OWNER_USER" &>/dev/null; then
        chown -R "$OWNER_USER" "$MONITORED_FOLDER"
        log_info "Set ownership to $OWNER_USER"
    fi
    
    # Set directory permissions (777 = rwxrwxrwx - everyone can read/write/execute)
    find "$MONITORED_FOLDER" -type d -exec chmod 777 {} \;
    log_info "Set directory permissions to 777 (full access for all users)"
    
    # Set file permissions (666 = rw-rw-rw- - everyone can read/write)
    find "$MONITORED_FOLDER" -type f -exec chmod 666 {} \;
    log_info "Set file permissions to 666 (read/write for all users)"
    
    # Set special permissions for executable files if any
    find "$MONITORED_FOLDER" -type f -name "*.sh" -exec chmod 777 {} \; 2>/dev/null || true
    find "$MONITORED_FOLDER" -type f -name "*.exe" -exec chmod 777 {} \; 2>/dev/null || true
    find "$MONITORED_FOLDER" -type f -name "*.bin" -exec chmod 777 {} \; 2>/dev/null || true
    log_info "Set executable permissions for script files"
    
    echo ""
    
    # Step 4: Ensure parent directories are accessible
    log_step "Checking parent directory permissions..."
    current_dir="$MONITORED_FOLDER"
    while [ "$current_dir" != "/" ]; do
        parent_dir=$(dirname "$current_dir")
        
        # Check if the parent directory allows access
        if [ -d "$parent_dir" ]; then
            parent_perms=$(stat -c '%a' "$parent_dir" 2>/dev/null || echo "000")
            verbose_log "Checking $parent_dir (permissions: $parent_perms)"
            
            # Check if others have execute permission (needed to traverse directory)
            # Extract the last digit (others permissions)
            others_perm="${parent_perms: -1}"
            
            # If others don't have execute permission (last digit is 0,2,4,6), add it
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
    
    # Step 5: Verify access
    log_step "Verifying access..."
    
    # Test if services can access the folder
    if [ -d "$MONITORED_FOLDER" ]; then
        # Test as different users if they exist
        for test_user in filemonitor apimonitor; do
            if id "$test_user" &>/dev/null; then
                if sudo -u "$test_user" test -r "$MONITORED_FOLDER" && sudo -u "$test_user" test -w "$MONITORED_FOLDER"; then
                    log_info "User '$test_user' can read and write to the folder"
                else
                    log_warn "User '$test_user' may have access issues"
                fi
            fi
        done
    else
        log_error "Monitored folder does not exist: $MONITORED_FOLDER"
    fi
    echo ""
    
    # Summary
    echo -e "${GREEN}=== Setup Complete ===${NC}"
    echo ""
    echo "Monitored folder: $MONITORED_FOLDER"
    echo "Owner: ${OWNER_USER:-$(stat -c '%U' "$MONITORED_FOLDER" 2>/dev/null || echo "unknown")}"
    echo "Permissions: 777 (directories - full access), 666 (files - read/write for all)"
    echo ""
    
    # Show actual permissions
    if [ -d "$MONITORED_FOLDER" ]; then
        echo "Actual folder permissions:"
        ls -ld "$MONITORED_FOLDER"
        echo ""
    fi
    
    echo "ALL users can now:"
    echo "  ✓ Read files from the monitored folder"
    echo "  ✓ Write files to the monitored folder"
    echo "  ✓ Create/delete subdirectories and files"
    echo "  ✓ Execute scripts in the folder"
    echo ""
    echo "No restrictions - everyone has full access!"
}

# Run main function with all arguments
main "$@"
