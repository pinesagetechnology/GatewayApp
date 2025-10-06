#!/usr/bin/env bash

# Diagnostic script for monitoring service permissions
# Run this to check the current state of permissions and group memberships

echo "=== Permission Diagnostics ==="
echo ""

FOLDER="/home/admin/workspace/gateway"
GROUP="monitor-services"

echo "1. Checking if folder exists:"
if [ -d "$FOLDER" ]; then
    echo "   ✓ Folder exists"
    ls -ld "$FOLDER"
else
    echo "   ✗ Folder does NOT exist"
fi
echo ""

echo "2. Checking parent directory:"
PARENT=$(dirname "$FOLDER")
if [ -d "$PARENT" ]; then
    echo "   ✓ Parent exists: $PARENT"
    ls -ld "$PARENT"
else
    echo "   ✗ Parent does NOT exist: $PARENT"
fi
echo ""

echo "3. Checking /home/admin permissions:"
if [ -d "/home/admin" ]; then
    ls -ld "/home/admin"
else
    echo "   ✗ /home/admin does NOT exist"
fi
echo ""

echo "4. Checking if monitor-services group exists:"
if getent group "$GROUP" &>/dev/null; then
    echo "   ✓ Group exists"
    getent group "$GROUP"
else
    echo "   ✗ Group does NOT exist"
fi
echo ""

echo "5. Checking service user existence:"
for user in filemonitor apimonitor; do
    if id "$user" &>/dev/null; then
        echo "   ✓ User $user exists"
        echo "     Groups: $(groups $user)"
    else
        echo "   ✗ User $user does NOT exist"
    fi
done
echo ""

echo "6. Testing filemonitor access to folder:"
if [ -d "$FOLDER" ]; then
    echo "   Read test:"
    if sudo -u filemonitor test -r "$FOLDER" 2>&1; then
        echo "     ✓ Can read"
    else
        echo "     ✗ Cannot read"
    fi
    
    echo "   Write test:"
    if sudo -u filemonitor test -w "$FOLDER" 2>&1; then
        echo "     ✓ Can write"
    else
        echo "     ✗ Cannot write"
    fi
    
    echo "   Execute test:"
    if sudo -u filemonitor test -x "$FOLDER" 2>&1; then
        echo "     ✓ Can execute (enter directory)"
    else
        echo "     ✗ Cannot execute"
    fi
else
    echo "   Folder doesn't exist, testing parent: $PARENT"
    if [ -d "$PARENT" ]; then
        echo "   Parent write test:"
        if sudo -u filemonitor test -w "$PARENT" 2>&1; then
            echo "     ✓ Can write to parent (can create folder)"
        else
            echo "     ✗ Cannot write to parent (cannot create folder)"
        fi
    fi
fi
echo ""

echo "7. Checking service status:"
for service in filemonitor apimonitor; do
    if systemctl is-active "$service" &>/dev/null; then
        echo "   ✓ $service is running"
    else
        echo "   ✗ $service is NOT running"
    fi
done
echo ""

echo "=== Recommendations ==="
echo ""
echo "If the folder doesn't exist or has wrong permissions, run:"
echo "  sudo ./fix-monitored-folder-permissions.sh --folder $FOLDER --owner admin --verbose"
echo ""
echo "If users are not in the monitor-services group, the fix script will add them."
echo "After running the fix script, the services will be automatically restarted."
