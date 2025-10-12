#!/usr/bin/env bash

################################################################################
# IoT Monitoring System - Complete Installation Orchestrator
# 
# This script executes the complete installation sequence:
# 1. Make all scripts executable
# 2. Install dependencies (.NET and SQLite)
# 3. Install FileMonitorWorkerService
# 4. Install APIMonitorWorkerService
# 5. Install MonitoringServiceAPI
# 6. Fix database permissions
# 7. Deploy React app
#
# Usage: sudo ./install-all.sh [OPTIONS]
################################################################################

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

VERSION="1.0.0"

# Default workspace paths
WORKSPACE_BASE="/home/alirk/workspace"
FILEMONITOR_SOURCE="$WORKSPACE_BASE/FileMonitorWorkerService/FileMonitorWorkerService"
APIMONITOR_SOURCE="$WORKSPACE_BASE/APIMonitorWorkerService/APIMonitorWorkerService"
MONITORINGAPI_SOURCE="$WORKSPACE_BASE/MonitoringServiceAPI/MonitoringServiceAPI"

# Data paths
FILEMONITOR_DATA="/var/filemonitor"
APIMONITOR_DATA="/var/apimonitor"

# Installation control
SKIP_CHMOD=false
SKIP_DEPENDENCIES=false
SKIP_FILEMONITOR=false
SKIP_APIMONITOR=false
SKIP_MONITORING=false
SKIP_SUDO=false
SKIP_PERMISSIONS=false
SKIP_REACT=false

# Options
INTERACTIVE=true
VERBOSE=false
DRY_RUN=false

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# COLORS AND LOGGING
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
err() { echo -e "${RED}✗${NC} $1"; }
step() { echo -e "${BLUE}==>${NC} $1"; }
info() { echo -e "${CYAN}ℹ${NC} $1"; }
header() { 
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC} $1"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[VERBOSE]${NC} $1"
    fi
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat << EOF
${GREEN}IoT Monitoring System - Complete Installation Orchestrator v${VERSION}${NC}

Executes the complete installation sequence:
  1. Make all shell scripts executable (chmod +x *.sh)
  2. Install dependencies (.NET and SQLite)
  3. Install FileMonitorWorkerService
  4. Install APIMonitorWorkerService
  5. Install MonitoringServiceAPI (no DB - uses FileMonitor and APIMonitor DBs)
  6. Configure limited sudo access for services
  7. Fix database permissions
  8. Deploy React app

${YELLOW}USAGE:${NC}
  sudo $0 [OPTIONS]

${YELLOW}OPTIONS:${NC}
  ${CYAN}Source Paths:${NC}
    --workspace PATH           Base workspace path (default: /home/alirk/workspace)
    --filemonitor-source PATH  FileMonitor source (default: \$WORKSPACE/FileMonitorWorkerService/FileMonitorWorkerService)
    --apimonitor-source PATH   APIMonitor source (default: \$WORKSPACE/APIMonitorWorkerService/APIMonitorWorkerService)
    --monitoring-source PATH   MonitoringAPI source (default: \$WORKSPACE/MonitoringServiceAPI)

  ${CYAN}Data Paths:${NC}
    --filemonitor-data PATH    FileMonitor DB path (default: /var/filemonitor)
    --apimonitor-data PATH     APIMonitor DB path (default: /var/apimonitor)

  ${CYAN}Skip Steps:${NC}
    --skip-chmod               Skip making scripts executable
    --skip-dependencies        Skip .NET and SQLite installation
    --skip-filemonitor         Skip FileMonitorWorkerService installation
    --skip-apimonitor          Skip APIMonitorWorkerService installation
    --skip-monitoring          Skip MonitoringServiceAPI installation
    --skip-sudo                Skip sudo access configuration
    --skip-permissions         Skip database permission fixes
    --skip-react               Skip React app deployment

  ${CYAN}General:${NC}
    --non-interactive          No prompts
    --verbose                  Verbose output
    --dry-run                  Show commands without executing
    -h, --help                 Show this help

${YELLOW}EXAMPLES:${NC}
  # Full installation with defaults
  sudo $0

  # Custom workspace path
  sudo $0 --workspace /home/user/projects

  # Skip React deployment
  sudo $0 --skip-react

  # Dry run to see what will be executed
  sudo $0 --dry-run --verbose

  # Non-interactive with custom paths
  sudo $0 --non-interactive \\
    --filemonitor-data /mnt/data/filemonitor \\
    --apimonitor-data /mnt/data/apimonitor

${YELLOW}REQUIREMENTS:${NC}
  - Run as root (sudo)
  - All installation scripts in project directories
  - Source code in workspace directories

EOF
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --workspace)
            WORKSPACE_BASE="$2"
            FILEMONITOR_SOURCE="$WORKSPACE_BASE/FileMonitorWorkerService/FileMonitorWorkerService"
            APIMONITOR_SOURCE="$WORKSPACE_BASE/APIMonitorWorkerService/APIMonitorWorkerService"
            MONITORINGAPI_SOURCE="$WORKSPACE_BASE/MonitoringServiceAPI/MonitoringServiceAPI"
            shift 2
            ;;
        --filemonitor-source)
            FILEMONITOR_SOURCE="$2"
            shift 2
            ;;
        --apimonitor-source)
            APIMONITOR_SOURCE="$2"
            shift 2
            ;;
        --monitoring-source)
            MONITORINGAPI_SOURCE="$2"
            shift 2
            ;;
        --filemonitor-data)
            FILEMONITOR_DATA="$2"
            shift 2
            ;;
        --apimonitor-data)
            APIMONITOR_DATA="$2"
            shift 2
            ;;
        --skip-chmod)
            SKIP_CHMOD=true
            shift
            ;;
        --skip-dependencies)
            SKIP_DEPENDENCIES=true
            shift
            ;;
        --skip-filemonitor)
            SKIP_FILEMONITOR=true
            shift
            ;;
        --skip-apimonitor)
            SKIP_APIMONITOR=true
            shift
            ;;
        --skip-monitoring)
            SKIP_MONITORING=true
            shift
            ;;
        --skip-sudo)
            SKIP_SUDO=true
            shift
            ;;
        --skip-permissions)
            SKIP_PERMISSIONS=true
            shift
            ;;
        --skip-react)
            SKIP_REACT=true
            shift
            ;;
        --non-interactive)
            INTERACTIVE=false
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            err "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# ============================================================================
# VALIDATION
# ============================================================================

check_root() {
    if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" = false ]; then
        err "This script must be run as root"
        echo "Please run with sudo: sudo $0"
        exit 1
    fi
}

check_paths() {
    local failed=false
    
    if [ "$SKIP_FILEMONITOR" = false ] && [ ! -d "$FILEMONITOR_SOURCE" ]; then
        err "FileMonitor source not found: $FILEMONITOR_SOURCE"
        failed=true
    fi
    
    if [ "$SKIP_APIMONITOR" = false ] && [ ! -d "$APIMONITOR_SOURCE" ]; then
        err "APIMonitor source not found: $APIMONITOR_SOURCE"
        failed=true
    fi
    
    if [ "$SKIP_MONITORING" = false ] && [ ! -d "$MONITORINGAPI_SOURCE" ]; then
        err "MonitoringAPI source not found: $MONITORINGAPI_SOURCE"
        failed=true
    fi
    
    if [ "$failed" = true ]; then
        echo ""
        err "One or more source directories not found"
        echo "Use --workspace to specify correct base path, or use --skip-* to skip services"
        exit 1
    fi
    
    log "All source directories found"
}

# ============================================================================
# INSTALLATION PLAN
# ============================================================================

show_installation_plan() {
    header "Installation Plan"
    
    echo -e "${CYAN}Installation Steps:${NC}"
    [ "$SKIP_CHMOD" = false ] && echo -e "  ${GREEN}1.${NC} Make all scripts executable" || echo -e "  ${YELLOW}1.${NC} Make scripts executable (skipped)"
    [ "$SKIP_DEPENDENCIES" = false ] && echo -e "  ${GREEN}2.${NC} Install dependencies (.NET and SQLite)" || echo -e "  ${YELLOW}2.${NC} Install dependencies (skipped)"
    [ "$SKIP_FILEMONITOR" = false ] && echo -e "  ${GREEN}3.${NC} Install FileMonitorWorkerService" || echo -e "  ${YELLOW}3.${NC} Install FileMonitorWorkerService (skipped)"
    [ "$SKIP_APIMONITOR" = false ] && echo -e "  ${GREEN}4.${NC} Install APIMonitorWorkerService" || echo -e "  ${YELLOW}4.${NC} Install APIMonitorWorkerService (skipped)"
    [ "$SKIP_MONITORING" = false ] && echo -e "  ${GREEN}5.${NC} Install MonitoringServiceAPI" || echo -e "  ${YELLOW}5.${NC} Install MonitoringServiceAPI (skipped)"
    [ "$SKIP_SUDO" = false ] && echo -e "  ${GREEN}6.${NC} Configure limited sudo access for services" || echo -e "  ${YELLOW}6.${NC} Configure sudo access (skipped)"
    [ "$SKIP_PERMISSIONS" = false ] && echo -e "  ${GREEN}7.${NC} Fix database permissions" || echo -e "  ${YELLOW}7.${NC} Fix database permissions (skipped)"
    echo -e "  ${GREEN}8.${NC} Create shared archive folder (/var/gateway-archive)"
    [ "$SKIP_REACT" = false ] && echo -e "  ${GREEN}9.${NC} Deploy React app" || echo -e "  ${YELLOW}9.${NC} Deploy React app (skipped)"
    
    echo ""
    echo -e "${CYAN}Source Paths:${NC}"
    [ "$SKIP_FILEMONITOR" = false ] && echo "  FileMonitor:    $FILEMONITOR_SOURCE"
    [ "$SKIP_APIMONITOR" = false ] && echo "  APIMonitor:     $APIMONITOR_SOURCE"
    [ "$SKIP_MONITORING" = false ] && echo "  MonitoringAPI:  $MONITORINGAPI_SOURCE"
    
    echo ""
    echo -e "${CYAN}Data Paths:${NC}"
    [ "$SKIP_FILEMONITOR" = false ] && echo "  FileMonitor DB: $FILEMONITOR_DATA"
    [ "$SKIP_APIMONITOR" = false ] && echo "  APIMonitor DB:  $APIMONITOR_DATA"
    [ "$SKIP_MONITORING" = false ] && echo "  MonitoringAPI:  No database (uses FileMonitor and APIMonitor DBs)"
    
    if [ "$INTERACTIVE" = true ]; then
        echo ""
        read -p "Continue with installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled"
            exit 0
        fi
    fi
}

# ============================================================================
# EXECUTION HELPER
# ============================================================================

execute_command() {
    local cmd="$1"
    local description="$2"
    
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] Would execute: $description"
        verbose "$cmd"
        return 0
    fi
    
    step "$description"
    if [ "$VERBOSE" = true ]; then
        echo "  Command: $cmd"
    fi
    
    if eval "$cmd"; then
        log "Success: $description"
        return 0
    else
        err "Failed: $description"
        return 1
    fi
}

# ============================================================================
# INSTALLATION STEPS
# ============================================================================

# Step 1: Make all scripts executable
make_scripts_executable() {
    if [ "$SKIP_CHMOD" = true ]; then
        return 0
    fi
    
    header "Step 1: Making All Scripts Executable"
    
    local script_dirs=(
        "$SCRIPT_DIR"
        "$FILEMONITOR_SOURCE/../scripts"
        "$APIMONITOR_SOURCE/../scripts"
        "$MONITORINGAPI_SOURCE/scripts"
    )
    
    for dir in "${script_dirs[@]}"; do
        if [ -d "$dir" ]; then
            verbose "Processing directory: $dir"
            if ! execute_command "chmod +x \"$dir\"/*.sh 2>/dev/null || true" "Make scripts executable in $dir"; then
                warn "Some scripts in $dir may not have been made executable"
            fi
        fi
    done
    
    log "All scripts are now executable"
}

# Step 2: Install dependencies
install_dependencies() {
    if [ "$SKIP_DEPENDENCIES" = true ]; then
        return 0
    fi
    
    header "Step 2: Installing Dependencies (.NET and SQLite)"
    
    # Install .NET
    if [ -f "$SCRIPT_DIR/dotnet_install_script.sh" ]; then
        # .NET install script must NOT be run as root - it uses sudo internally
        if [ "$EUID" -eq 0 ]; then
            # Find the original user who invoked sudo
            ORIGINAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo $USER)}"
            if [ -n "$ORIGINAL_USER" ] && [ "$ORIGINAL_USER" != "root" ]; then
                step "Running .NET installation as user: $ORIGINAL_USER"
                execute_command "sudo -u $ORIGINAL_USER bash \"$SCRIPT_DIR/dotnet_install_script.sh\"" "Install .NET runtime" || {
                    err "Failed to install .NET"
                    exit 1
                }
            else
                warn ".NET installation requires non-root execution"
                warn "Please run this installer without sudo, or install .NET manually"
                read -p "Skip .NET installation and continue? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            fi
        else
            execute_command "bash \"$SCRIPT_DIR/dotnet_install_script.sh\"" "Install .NET runtime" || {
                err "Failed to install .NET"
                exit 1
            }
        fi
    else
        warn ".NET install script not found: $SCRIPT_DIR/dotnet_install_script.sh"
        warn "Assuming .NET is already installed"
    fi
    
    # Install SQLite
    if [ -f "$SCRIPT_DIR/git_sqlite_installer.sh" ]; then
        execute_command "bash \"$SCRIPT_DIR/git_sqlite_installer.sh\"" "Install SQLite" || {
            err "Failed to install SQLite"
            exit 1
        }
    else
        warn "SQLite install script not found: $SCRIPT_DIR/git_sqlite_installer.sh"
        warn "Assuming SQLite is already installed"
    fi
    
    log "Dependencies installed"
}

# Step 3: Install FileMonitorWorkerService
install_filemonitor() {
    if [ "$SKIP_FILEMONITOR" = true ]; then
        return 0
    fi
    
    header "Step 3: Installing FileMonitorWorkerService"
    
    local installer="$FILEMONITOR_SOURCE/../scripts/FileMonitorWorkerService_MainInstaller.sh"
    if [ ! -f "$installer" ]; then
        installer="$SCRIPT_DIR/FileMonitorWorkerService_MainInstaller.sh"
    fi
    
    if [ ! -f "$installer" ]; then
        err "FileMonitor installer not found"
        exit 1
    fi
    
    local cmd="bash \"$installer\" --data-path \"$FILEMONITOR_DATA\" --source-path \"$FILEMONITOR_SOURCE\""
    
    execute_command "$cmd" "Install FileMonitorWorkerService" || {
        err "Failed to install FileMonitorWorkerService"
        exit 1
    }
}

# Step 4: Install APIMonitorWorkerService
install_apimonitor() {
    if [ "$SKIP_APIMONITOR" = true ]; then
        return 0
    fi
    
    header "Step 4: Installing APIMonitorWorkerService"
    
    local installer="$APIMONITOR_SOURCE/../scripts/APIMonitorWorkerService_MainInstaller.sh"
    if [ ! -f "$installer" ]; then
        installer="$SCRIPT_DIR/APIMonitorWorkerService_MainInstaller.sh"
    fi
    
    if [ ! -f "$installer" ]; then
        err "APIMonitor installer not found"
        exit 1
    fi
    
    local cmd="bash \"$installer\" --data-path \"$APIMONITOR_DATA\" --source-path \"$APIMONITOR_SOURCE\""
    
    execute_command "$cmd" "Install APIMonitorWorkerService" || {
        err "Failed to install APIMonitorWorkerService"
        exit 1
    }
}

# Step 5: Install MonitoringServiceAPI
install_monitoringapi() {
    if [ "$SKIP_MONITORING" = true ]; then
        return 0
    fi
    
    header "Step 5: Installing MonitoringServiceAPI"
    
    info "Note: MonitoringAPI does not have its own database"
    info "It uses FileMonitor DB: $FILEMONITOR_DATA"
    info "It uses APIMonitor DB: $APIMONITOR_DATA"
    
    local installer="$MONITORINGAPI_SOURCE/../scripts/MonitoringServiceAPI_MainInstaller.sh"
    if [ ! -f "$installer" ]; then
        installer="$SCRIPT_DIR/MonitoringServiceAPI_MainInstaller.sh"
    fi
    
    if [ ! -f "$installer" ]; then
        err "MonitoringAPI installer not found"
        exit 1
    fi
    
    local cmd="bash \"$installer\" --source-path \"$MONITORINGAPI_SOURCE\""
    
    execute_command "$cmd" "Install MonitoringServiceAPI" || {
        err "Failed to install MonitoringServiceAPI"
        exit 1
    }
}

# Step 6: Configure sudo access for services
configure_sudo_access() {
    if [ "$SKIP_SUDO" = true ]; then
        return 0
    fi
    
    header "Step 6: Configuring Limited Sudo Access"
    
    info "Granting limited sudo privileges to service users..."
    info "This allows services to create/delete/move files and run scripts"
    echo ""
    
    # Check if grant script exists
    local sudo_script="$SCRIPT_DIR/grant_limited_sudo_access.sh"
    
    if [ ! -f "$sudo_script" ]; then
        warn "Sudo configuration script not found: $sudo_script"
        warn "Services will be installed without sudo access"
        warn "You can configure sudo later by running:"
        warn "  sudo bash grant_limited_sudo_access.sh"
        return 0
    fi
    
    # Make script executable
    chmod +x "$sudo_script"
    
    # Run the sudo configuration script
    if bash "$sudo_script"; then
        log "Sudo access configured successfully"
    else
        warn "Sudo configuration had issues, but continuing..."
        warn "Services may not have sudo access"
    fi
    
    echo ""
}

# Step 7: Fix database permissions
fix_database_permissions() {
    if [ "$SKIP_PERMISSIONS" = true ]; then
        return 0
    fi
    
    header "Step 7: Fixing Database Permissions"
    
    # Look for permission fix script in multiple locations
    local permission_script="$WORKSPACE_BASE/MonitoringServiceAPI/scripts/fix-database-permissions_v2.sh"
    
    if [ ! -f "$permission_script" ]; then
        permission_script="$SCRIPT_DIR/MonitoringServiceAPI/scripts/fix-database-permissions_v2.sh"
    fi
    
    if [ ! -f "$permission_script" ]; then
        permission_script="$SCRIPT_DIR/fix-database-permissions_v2.sh"
    fi
    
    if [ ! -f "$permission_script" ]; then
        warn "Permission fix script not found"
        warn "Tried locations:"
        warn "  - $WORKSPACE_BASE/MonitoringServiceAPI/scripts/fix-database-permissions_v2.sh"
        warn "  - $SCRIPT_DIR/fix-database-permissions_v2.sh"
        warn "You may need to fix database permissions manually using:"
        warn "  sudo bash MonitoringServiceAPI/scripts/fix-database-permissions_v2.sh"
        return 0
    fi
    
    info "Using permission script: $permission_script"
    local cmd="bash \"$permission_script\" --apimonitor-data \"$APIMONITOR_DATA\" --filemonitor-data \"$FILEMONITOR_DATA\""
    
    execute_command "$cmd" "Fix database permissions" || {
        warn "Database permission fix had issues, but continuing..."
    }
}

# Step 8: Create shared archive folder
create_archive_folder() {
    header "Step 8: Creating Shared Archive Folder"
    
    local ARCHIVE_PATH="/var/gateway-archive"
    
    info "Creating centralized archive folder for uploaded files"
    info "Location: $ARCHIVE_PATH"
    echo ""
    
    # Create the directory if it doesn't exist
    if [ ! -d "$ARCHIVE_PATH" ]; then
        if execute_command "mkdir -p \"$ARCHIVE_PATH\"" "Create archive directory"; then
            log "Archive directory created: $ARCHIVE_PATH"
        else
            err "Failed to create archive directory"
            return 1
        fi
    else
        warn "Archive directory already exists: $ARCHIVE_PATH"
    fi
    
    # Set ownership to root with a shared group
    # Create a shared group for gateway services if it doesn't exist
    if ! getent group gateway-archive >/dev/null 2>&1; then
        if execute_command "groupadd gateway-archive" "Create gateway-archive group"; then
            log "Created gateway-archive group"
        else
            warn "Failed to create gateway-archive group, using root:root ownership"
        fi
    fi
    
    # Add service users to the gateway-archive group
    local service_users=("filemonitor" "apimonitor" "monitoringapi" "www-data")
    for user in "${service_users[@]}"; do
        if id "$user" >/dev/null 2>&1; then
            if execute_command "usermod -aG gateway-archive \"$user\"" "Add $user to gateway-archive group"; then
                verbose "Added $user to gateway-archive group"
            else
                warn "Failed to add $user to gateway-archive group"
            fi
        else
            verbose "User $user does not exist, skipping"
        fi
    done
    
    # Set ownership to root:gateway-archive
    if execute_command "chown root:gateway-archive \"$ARCHIVE_PATH\"" "Set archive folder ownership"; then
        log "Set ownership to root:gateway-archive"
    else
        warn "Failed to set ownership, using default"
    fi
    
    # Set permissions: 2775 (rwxrwsr-x)
    # - Owner (root): read, write, execute
    # - Group (gateway-archive): read, write, execute
    # - Others: read, execute
    # - Setgid bit (2): Files created inherit group ownership
    if execute_command "chmod 2775 \"$ARCHIVE_PATH\"" "Set archive folder permissions"; then
        log "Set permissions to 2775 (rwxrwsr-x with setgid)"
    else
        err "Failed to set permissions"
        return 1
    fi
    
    # Create a README file in the archive directory
    cat > "$ARCHIVE_PATH/README.txt" << 'EOF'
Gateway Archive Folder
======================

This folder is used by the File Monitor service to archive uploaded files.

Location: /var/gateway-archive
Permissions: 2775 (rwxrwsr-x with setgid bit)
Group: gateway-archive

All services in the gateway-archive group have read/write access to this folder.

Files moved here retain their original names with timestamps prepended.

EOF
    
    if [ -f "$ARCHIVE_PATH/README.txt" ]; then
        execute_command "chmod 664 \"$ARCHIVE_PATH/README.txt\"" "Set README permissions"
        log "Created README.txt in archive folder"
    fi
    
    echo ""
    info "Archive folder setup complete"
    info "Path: $ARCHIVE_PATH"
    info "Group: gateway-archive"
    info "Permissions: 2775 (rwxrwsr-x)"
    info "Service users with access: filemonitor, apimonitor, monitoringapi, www-data"
    echo ""
}

# Step 9: Deploy React app
deploy_react_app() {
    if [ "$SKIP_REACT" = true ]; then
        return 0
    fi
    
    header "Step 9: Deploying React App"
    
    # Look for the React deployment script in AzureGateway.UI/scripts directory
    local deploy_script="$WORKSPACE_BASE/AzureGateway.UI/scripts/rpi5-deploy.sh"
    
    if [ ! -f "$deploy_script" ]; then
        # Fallback to script directory
        deploy_script="$SCRIPT_DIR/AzureGateway.UI/scripts/rpi5-deploy.sh"
    fi
    
    if [ ! -f "$deploy_script" ]; then
        warn "React deployment script not found: $deploy_script"
        warn "Expected location: $WORKSPACE_BASE/AzureGateway.UI/scripts/rpi5-deploy.sh"
        warn "Skipping React app deployment"
        return 0
    fi
    
    # Get the React app directory (parent of scripts folder)
    local react_app_dir="$WORKSPACE_BASE/AzureGateway.UI"
    
    if [ ! -d "$react_app_dir" ]; then
        warn "React app directory not found: $react_app_dir"
        warn "Skipping React app deployment"
        return 0
    fi
    
    info "React app directory: $react_app_dir"
    
    # React deployment script should NOT be run as root - run as original user
    if [ "$EUID" -eq 0 ]; then
        ORIGINAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo $USER)}"
        if [ -n "$ORIGINAL_USER" ] && [ "$ORIGINAL_USER" != "root" ]; then
            info "Running React deployment as user: $ORIGINAL_USER"
            # Run the script with full path - the script will handle changing to project root
            execute_command "sudo -u $ORIGINAL_USER bash \"$deploy_script\"" "Deploy React app" || {
                warn "React app deployment had issues, but continuing..."
            }
        else
            warn "React deployment requires non-root execution"
            warn "Please deploy React app manually: bash $deploy_script"
        fi
    else
        execute_command "bash \"$deploy_script\"" "Deploy React app" || {
            warn "React app deployment had issues, but continuing..."
        }
    fi
}

# ============================================================================
# POST-INSTALLATION
# ============================================================================

show_completion() {
    if [ "$DRY_RUN" = true ]; then
        header "Dry Run Complete"
        info "No actual installation was performed"
        info "Review the commands above to see what would be executed"
        return 0
    fi
    
    header "Installation Complete!"
    
    echo -e "${GREEN}All installation steps completed successfully!${NC}"
    echo ""
    
    echo -e "${CYAN}Installed Services:${NC}"
    [ "$SKIP_FILEMONITOR" = false ] && echo "  ✓ FileMonitorWorkerService"
    [ "$SKIP_APIMONITOR" = false ] && echo "  ✓ APIMonitorWorkerService"
    [ "$SKIP_MONITORING" = false ] && echo "  ✓ MonitoringServiceAPI"
    [ "$SKIP_REACT" = false ] && echo "  ✓ React App"
    
    echo ""
    echo -e "${CYAN}Database Locations:${NC}"
    [ "$SKIP_FILEMONITOR" = false ] && echo "  FileMonitor: $FILEMONITOR_DATA"
    [ "$SKIP_APIMONITOR" = false ] && echo "  APIMonitor:  $APIMONITOR_DATA"
    
    echo ""
    echo -e "${CYAN}Archive Folder:${NC}"
    echo "  Location:    /var/gateway-archive"
    echo "  Group:       gateway-archive"
    echo "  Permissions: 2775 (rwxrwsr-x)"
    
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Start the services:"
    [ "$SKIP_FILEMONITOR" = false ] && echo "       sudo systemctl start filemonitor"
    [ "$SKIP_APIMONITOR" = false ] && echo "       sudo systemctl start apimonitor"
    [ "$SKIP_MONITORING" = false ] && echo "       sudo systemctl start monitoringapi"
    
    echo ""
    echo "  2. Check status:"
    [ "$SKIP_FILEMONITOR" = false ] && echo "       sudo systemctl status filemonitor"
    [ "$SKIP_APIMONITOR" = false ] && echo "       sudo systemctl status apimonitor"
    [ "$SKIP_MONITORING" = false ] && echo "       sudo systemctl status monitoringapi"
    
    echo ""
    echo "  3. View logs:"
    [ "$SKIP_FILEMONITOR" = false ] && echo "       sudo journalctl -u filemonitor -f"
    [ "$SKIP_APIMONITOR" = false ] && echo "       sudo journalctl -u apimonitor -f"
    [ "$SKIP_MONITORING" = false ] && echo "       sudo journalctl -u monitoringapi -f"
    
    if [ "$SKIP_MONITORING" = false ]; then
        echo ""
        echo -e "${CYAN}API Access:${NC}"
        echo "  Health:  http://localhost/health"
        echo "  API:     http://localhost/api/"
        echo "  Swagger: http://localhost/swagger"
    fi
    
    if [ "$SKIP_REACT" = false ]; then
        echo ""
        echo -e "${CYAN}React App:${NC}"
        echo "  Access the web interface through your configured URL"
    fi
    
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    clear
    header "IoT Monitoring System - Complete Installation v${VERSION}"
    
    # Validation
    check_root
    check_paths
    
    # Show plan and confirm
    show_installation_plan
    
    # Execute installation steps in sequence
    make_scripts_executable
    install_dependencies
    install_filemonitor
    install_apimonitor
    install_monitoringapi
    configure_sudo_access
    fix_database_permissions
    create_archive_folder
    deploy_react_app
    
    # Complete
    show_completion
}

# Run main
main "$@"
