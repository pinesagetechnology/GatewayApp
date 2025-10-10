#!/usr/bin/env bash

# Diagnostic Script for Monitoring Service Permission Issues
# This script checks why the MonitoringServiceAPI cannot execute permission scripts

set +e  # Don't exit on errors - we want to collect all diagnostics

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

log_check() {
    echo -e "${CYAN}[CHECK]${NC} $1"
}

# Configuration
SERVICE_USER="monitoringapi"
SERVICE_NAME="monitoringapi"
SCRIPT_NAME="fix-monitored-folder-permissions.sh"
SERVICE_DIR="/opt/monitoringapi"
SHARED_GROUP="monitor-services"
OTHER_SERVICE_USERS=("apimonitor" "filemonitor")

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Monitoring Service Permission Diagnostic Tool           ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo ""
echo "This script will diagnose why the MonitoringServiceAPI"
echo "cannot execute permission management scripts."
echo ""

# ============================================================================
# 1. Check if running as root
# ============================================================================
log_section "1. Root Access Check"

log_check "Checking if script is running as root..."
if [ "$EUID" -ne 0 ]; then
    log_error "Not running as root"
    echo "  → This diagnostic should be run with: sudo $0"
    echo "  → Some checks may fail without root privileges"
else
    log_info "Running as root - full diagnostic available"
fi
echo ""

# ============================================================================
# 2. Service User Verification
# ============================================================================
log_section "2. Service User Verification"

log_check "Checking if service user '$SERVICE_USER' exists..."
if id "$SERVICE_USER" &>/dev/null; then
    log_info "Service user exists"
    echo "  User ID: $(id -u $SERVICE_USER)"
    echo "  Group ID: $(id -g $SERVICE_USER)"
    echo "  Groups: $(groups $SERVICE_USER 2>/dev/null || echo 'Unable to retrieve')"
    echo "  Home: $(eval echo ~$SERVICE_USER)"
    echo "  Shell: $(getent passwd $SERVICE_USER | cut -d: -f7)"
else
    log_error "Service user '$SERVICE_USER' does not exist!"
    echo "  → The service user must be created during installation"
fi
echo ""

# Check other service users
for user in "${OTHER_SERVICE_USERS[@]}"; do
    log_check "Checking if service user '$user' exists..."
    if id "$user" &>/dev/null; then
        log_info "Service user '$user' exists"
        echo "  Groups: $(groups $user 2>/dev/null || echo 'Unable to retrieve')"
    else
        log_warn "Service user '$user' does not exist"
    fi
done
echo ""

# ============================================================================
# 3. Shared Group Verification
# ============================================================================
log_section "3. Shared Group Verification"

log_check "Checking if shared group '$SHARED_GROUP' exists..."
if getent group "$SHARED_GROUP" &>/dev/null; then
    log_info "Shared group exists"
    echo "  Group ID: $(getent group $SHARED_GROUP | cut -d: -f3)"
    echo "  Members: $(getent group $SHARED_GROUP | cut -d: -f4)"
    
    # Check if service user is in the group
    if groups "$SERVICE_USER" 2>/dev/null | grep -q "$SHARED_GROUP"; then
        log_info "Service user '$SERVICE_USER' is in '$SHARED_GROUP'"
    else
        log_error "Service user '$SERVICE_USER' is NOT in '$SHARED_GROUP'"
        echo "  → Add with: sudo usermod -a -G $SHARED_GROUP $SERVICE_USER"
    fi
else
    log_error "Shared group '$SHARED_GROUP' does not exist!"
    echo "  → Create with: sudo groupadd $SHARED_GROUP"
fi
echo ""

# ============================================================================
# 4. Service Directory and Script Verification
# ============================================================================
log_section "4. Service Directory and Script Verification"

log_check "Checking service directory: $SERVICE_DIR"
if [ -d "$SERVICE_DIR" ]; then
    log_info "Service directory exists"
    ls -ld "$SERVICE_DIR"
    echo ""
    
    # Check ownership
    owner=$(stat -c '%U' "$SERVICE_DIR" 2>/dev/null)
    group=$(stat -c '%G' "$SERVICE_DIR" 2>/dev/null)
    perms=$(stat -c '%a' "$SERVICE_DIR" 2>/dev/null)
    
    echo "  Owner: $owner"
    echo "  Group: $group"
    echo "  Permissions: $perms"
    
    if [ "$owner" != "$SERVICE_USER" ]; then
        log_warn "Directory owner is '$owner', not '$SERVICE_USER'"
    fi
else
    log_error "Service directory does not exist!"
fi
echo ""

# Check scripts directory
log_check "Checking scripts directory: $SERVICE_DIR/scripts"
if [ -d "$SERVICE_DIR/scripts" ]; then
    log_info "Scripts directory exists"
    ls -la "$SERVICE_DIR/scripts/" 2>/dev/null || echo "Cannot list scripts directory"
else
    log_error "Scripts directory does not exist!"
    echo "  → Expected at: $SERVICE_DIR/scripts"
fi
echo ""

# Check specific script
SCRIPT_PATH="$SERVICE_DIR/scripts/$SCRIPT_NAME"
log_check "Checking permission script: $SCRIPT_PATH"
if [ -f "$SCRIPT_PATH" ]; then
    log_info "Permission script exists"
    ls -l "$SCRIPT_PATH"
    
    # Check if executable
    if [ -x "$SCRIPT_PATH" ]; then
        log_info "Script is executable"
    else
        log_error "Script is NOT executable!"
        echo "  → Fix with: sudo chmod +x $SCRIPT_PATH"
    fi
    
    # Check shebang
    shebang=$(head -n 1 "$SCRIPT_PATH")
    echo "  Shebang: $shebang"
else
    log_error "Permission script does not exist!"
    echo "  → Expected at: $SCRIPT_PATH"
fi
echo ""

# ============================================================================
# 5. Sudo Configuration Check
# ============================================================================
log_section "5. Sudo Configuration Check"

log_check "Checking sudo configuration for service user..."

# Check if sudoers.d directory exists
if [ -d "/etc/sudoers.d" ]; then
    log_info "sudoers.d directory exists"
    
    # Look for service-specific sudoers files
    log_check "Looking for service-specific sudoers files..."
    found_sudoers=false
    
    for file in /etc/sudoers.d/*; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            if grep -q "$SERVICE_USER" "$file" 2>/dev/null; then
                log_info "Found sudoers configuration: $filename"
                echo "  Content:"
                cat "$file" | sed 's/^/    /'
                echo ""
                found_sudoers=true
            fi
        fi
    done
    
    if [ "$found_sudoers" = false ]; then
        log_error "No sudoers configuration found for '$SERVICE_USER'"
        echo "  → The service user needs passwordless sudo access"
        echo "  → Expected file: /etc/sudoers.d/monitoringapi-permissions"
    fi
else
    log_error "/etc/sudoers.d directory does not exist!"
fi
echo ""

# Test sudo access
log_check "Testing sudo access for service user..."
if [ "$EUID" -eq 0 ]; then
    # Test if user can run bash without password
    if sudo -n -u "$SERVICE_USER" sudo -n /usr/bin/bash -c "echo 'test'" &>/dev/null; then
        log_info "Service user CAN run sudo commands without password"
    else
        log_error "Service user CANNOT run sudo commands without password"
        echo "  Error output:"
        sudo -n -u "$SERVICE_USER" sudo -n /usr/bin/bash -c "echo 'test'" 2>&1 | sed 's/^/    /'
    fi
    echo ""
    
    # Test if user can run the specific script
    if sudo -n -u "$SERVICE_USER" sudo -n /usr/bin/bash "$SCRIPT_PATH" --help &>/dev/null; then
        log_info "Service user CAN run the permission script with sudo"
    else
        log_error "Service user CANNOT run the permission script with sudo"
        echo "  Error output:"
        sudo -n -u "$SERVICE_USER" sudo -n /usr/bin/bash "$SCRIPT_PATH" --help 2>&1 | sed 's/^/    /'
    fi
else
    log_warn "Not running as root - cannot test sudo access"
    echo "  → Run with sudo to test sudo access"
fi
echo ""

# ============================================================================
# 6. Service Status Check
# ============================================================================
log_section "6. Service Status Check"

log_check "Checking service status: $SERVICE_NAME"
if systemctl is-active "$SERVICE_NAME" &>/dev/null; then
    log_info "Service is running"
else
    log_warn "Service is not running"
fi

if systemctl is-enabled "$SERVICE_NAME" &>/dev/null; then
    log_info "Service is enabled"
else
    log_warn "Service is not enabled"
fi
echo ""

# Show service details
if [ "$EUID" -eq 0 ]; then
    log_check "Service unit file details..."
    systemctl cat "$SERVICE_NAME" 2>/dev/null || log_warn "Cannot retrieve service unit file"
    echo ""
fi

# ============================================================================
# 7. Recent Service Logs
# ============================================================================
log_section "7. Recent Service Logs (Last 20 lines)"

if command -v journalctl &>/dev/null; then
    journalctl -u "$SERVICE_NAME" -n 20 --no-pager 2>/dev/null || log_warn "Cannot retrieve service logs"
else
    log_warn "journalctl not available"
fi
echo ""

# ============================================================================
# 8. File System Permissions Check
# ============================================================================
log_section "8. File System Permissions Check"

log_check "Testing if service user can read/write test directories..."

# Test in service directory
test_file="$SERVICE_DIR/.test_write_$$"
if [ "$EUID" -eq 0 ]; then
    if sudo -u "$SERVICE_USER" touch "$test_file" 2>/dev/null; then
        log_info "Service user CAN write to service directory"
        rm -f "$test_file"
    else
        log_error "Service user CANNOT write to service directory"
    fi
    
    # Test /tmp
    test_file_tmp="/tmp/.test_write_${SERVICE_USER}_$$"
    if sudo -u "$SERVICE_USER" touch "$test_file_tmp" 2>/dev/null; then
        log_info "Service user CAN write to /tmp"
        rm -f "$test_file_tmp"
    else
        log_error "Service user CANNOT write to /tmp"
    fi
else
    log_warn "Not running as root - cannot test write permissions"
fi
echo ""

# ============================================================================
# 9. Environment Check
# ============================================================================
log_section "9. Environment Check"

log_check "Checking system environment..."
echo "  Hostname: $(hostname)"
echo "  OS: $(uname -s) $(uname -r)"
echo "  Architecture: $(uname -m)"
echo ""

if [ -f /etc/os-release ]; then
    echo "  Distribution info:"
    cat /etc/os-release | grep -E '^(NAME|VERSION)=' | sed 's/^/    /'
fi
echo ""

# ============================================================================
# 10. Script Execution Test
# ============================================================================
log_section "10. Script Execution Test"

if [ "$EUID" -eq 0 ] && [ -f "$SCRIPT_PATH" ]; then
    log_check "Testing script execution as service user..."
    
    # Try to run script help without sudo (should fail)
    echo "Test 1: Run script WITHOUT sudo (expected to fail):"
    sudo -u "$SERVICE_USER" bash "$SCRIPT_PATH" --help 2>&1 | head -20 | sed 's/^/  /'
    echo ""
    
    # Try to run script help with sudo (should work if configured correctly)
    echo "Test 2: Run script WITH sudo (should work if configured):"
    sudo -u "$SERVICE_USER" sudo bash "$SCRIPT_PATH" --help 2>&1 | head -20 | sed 's/^/  /'
    echo ""
else
    log_warn "Cannot run execution tests (need root and script must exist)"
fi

# ============================================================================
# Summary and Recommendations
# ============================================================================
log_section "Summary and Recommendations"

echo -e "${YELLOW}Common Issues and Solutions:${NC}\n"

echo "1. Service user cannot run sudo commands:"
echo "   → Create sudoers file: /etc/sudoers.d/monitoringapi-permissions"
echo "   → Content should allow passwordless sudo for specific commands"
echo "   → Example:"
echo "     monitoringapi ALL=(ALL) NOPASSWD: /usr/bin/bash /opt/monitoringapi/scripts/fix-monitored-folder-permissions.sh *"
echo ""

echo "2. Script is not executable:"
echo "   → Run: sudo chmod +x $SCRIPT_PATH"
echo ""

echo "3. Service user not in shared group:"
echo "   → Run: sudo usermod -a -G $SHARED_GROUP $SERVICE_USER"
echo "   → Restart service: sudo systemctl restart $SERVICE_NAME"
echo ""

echo "4. Script cannot be found by service:"
echo "   → Ensure script is at: $SCRIPT_PATH"
echo "   → Check service working directory in unit file"
echo ""

echo "5. Script requires root but service doesn't call it with sudo:"
echo "   → Update service code to call: sudo bash scripts/$SCRIPT_NAME"
echo "   → Configure sudoers to allow this command without password"
echo ""

echo -e "${CYAN}For detailed sudo configuration, see:${NC}"
echo "  - SUDO_ACCESS_CONFIGURATION.md (in project root)"
echo "  - /etc/sudoers.d/ directory"
echo ""

echo -e "${GREEN}Diagnostic complete!${NC}"
echo "If issues remain, check the specific error messages above."
echo ""

