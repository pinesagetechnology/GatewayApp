#!/usr/bin/env bash

################################################################################
# Test Sudo Setup for Monitoring Services
# 
# This script validates that the sudo configuration is working correctly
# and that the monitoringapi service can execute required commands.
#
# Usage: sudo ./test_sudo_setup.sh
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

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -e "\n${BLUE}Test $TESTS_RUN: $test_name${NC}"
    
    if eval "$test_command" &>/dev/null; then
        log_info "PASSED"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "FAILED"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

main() {
    echo ""
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${GREEN}  Test Sudo Setup for Monitoring Services${NC}"
    echo -e "${GREEN}==========================================================${NC}"
    echo ""
    
    check_root
    
    # Test 1: Check if monitoringapi user exists
    log_step "Checking if service users exist..."
    run_test "monitoringapi user exists" "id monitoringapi"
    run_test "apimonitor user exists" "id apimonitor"
    run_test "filemonitor user exists" "id filemonitor"
    
    # Test 2: Check if sudoers files exist
    log_step "Checking if sudoers files exist..."
    run_test "monitoringapi sudoers file exists" "test -f /etc/sudoers.d/monitoringapi"
    run_test "apimonitor sudoers file exists" "test -f /etc/sudoers.d/apimonitor"
    run_test "filemonitor sudoers file exists" "test -f /etc/sudoers.d/filemonitor"
    
    # Test 3: Validate sudoers syntax
    log_step "Validating sudoers syntax..."
    run_test "Overall sudoers configuration is valid" "visudo -c"
    run_test "monitoringapi sudoers syntax is valid" "visudo -c -f /etc/sudoers.d/monitoringapi"
    run_test "apimonitor sudoers syntax is valid" "visudo -c -f /etc/sudoers.d/apimonitor"
    run_test "filemonitor sudoers syntax is valid" "visudo -c -f /etc/sudoers.d/filemonitor"
    
    # Test 4: Check sudoers file permissions
    log_step "Checking sudoers file permissions..."
    run_test "monitoringapi sudoers has correct permissions (440)" "test \$(stat -c '%a' /etc/sudoers.d/monitoringapi) = '440'"
    
    # Test 5: Test sudo access for monitoringapi user
    log_step "Testing sudo access for monitoringapi user..."
    run_test "monitoringapi can list sudo permissions" "sudo -u monitoringapi sudo -n -l"
    
    # Test 6: Test specific commands
    log_step "Testing specific sudo commands..."
    
    # Create a test directory in /tmp
    TEST_DIR="/tmp/monitoring-test-$(date +%s)"
    
    # Test mkdir
    if run_test "monitoringapi can use sudo mkdir" "sudo -u monitoringapi sudo /bin/mkdir -p $TEST_DIR"; then
        # Test chmod
        run_test "monitoringapi can use sudo chmod" "sudo -u monitoringapi sudo /bin/chmod 755 $TEST_DIR"
        
        # Test chown
        run_test "monitoringapi can use sudo chown" "sudo -u monitoringapi sudo /bin/chown monitoringapi:monitoringapi $TEST_DIR"
        
        # Test rm
        run_test "monitoringapi can use sudo rm" "sudo -u monitoringapi sudo /bin/rm -rf $TEST_DIR"
    fi
    
    # Test 7: Test script execution
    log_step "Testing script execution..."
    
    # Check if the permission script exists
    SCRIPT_PATHS=(
        "/opt/monitoringapi/scripts/fix-monitored-folder-permissions.sh"
        "./MonitoringServiceAPI/scripts/fix-monitored-folder-permissions.sh"
        "./MonitoringServiceAPI/MonitoringServiceAPI/fix-monitored-folder-permissions.sh"
    )
    
    SCRIPT_FOUND=false
    SCRIPT_PATH=""
    
    for path in "${SCRIPT_PATHS[@]}"; do
        if [ -f "$path" ]; then
            SCRIPT_PATH="$path"
            SCRIPT_FOUND=true
            break
        fi
    done
    
    if [ "$SCRIPT_FOUND" = true ]; then
        log_info "Found permission script at: $SCRIPT_PATH"
        
        # Make sure script is executable
        chmod +x "$SCRIPT_PATH"
        
        # Test script execution with --help (doesn't require sudo)
        run_test "Permission script is executable" "$SCRIPT_PATH --help"
        
        # Test script execution with sudo (dry run with help)
        run_test "monitoringapi can execute permission script with sudo" "sudo -u monitoringapi sudo /bin/bash $SCRIPT_PATH --help"
    else
        log_warn "Permission script not found at expected locations"
        log_warn "Skipping script execution tests"
    fi
    
    # Test 8: Check if monitoring services are installed
    log_step "Checking if services are installed..."
    run_test "monitoringapi service exists" "systemctl list-unit-files | grep -q monitoringapi"
    run_test "apimonitor service exists" "systemctl list-unit-files | grep -q apimonitor"
    run_test "filemonitor service exists" "systemctl list-unit-files | grep -q filemonitor"
    
    # Test 9: Check if monitor-services group exists
    log_step "Checking shared group..."
    run_test "monitor-services group exists" "getent group monitor-services"
    
    # Summary
    echo ""
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${GREEN}  Test Summary${NC}"
    echo -e "${GREEN}==========================================================${NC}"
    echo ""
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    else
        echo -e "Tests failed: $TESTS_FAILED"
    fi
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo ""
        echo "The sudo setup is working correctly."
        echo "The monitoringapi service should be able to create folders and set permissions."
        echo ""
        exit 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        echo ""
        echo "Please review the failed tests and:"
        echo "  1. Run grant_limited_sudo_access.sh to set up sudo access"
        echo "  2. Ensure all services are installed"
        echo "  3. Check the sudoers configuration in /etc/sudoers.d/"
        echo ""
        exit 1
    fi
}

# Run main function
main "$@"

