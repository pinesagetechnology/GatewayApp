#!/usr/bin/env bash

# Test script to verify sudoers syntax
# This creates a minimal sudoers file and tests it

cat > /tmp/test_sudoers << 'EOF'
# Minimal working sudoers config
monitoringapi ALL=(ALL) NOPASSWD: /bin/bash /opt/monitoringapi/scripts/fix-monitored-folder-permissions.sh
monitoringapi ALL=(ALL) NOPASSWD: /bin/bash /opt/monitoringapi/scripts/fix-monitored-folder-permissions.sh *
monitoringapi ALL=(ALL) NOPASSWD: /bin/mkdir
monitoringapi ALL=(ALL) NOPASSWD: /bin/rm
monitoringapi ALL=(ALL) NOPASSWD: /bin/chmod
monitoringapi ALL=(ALL) NOPASSWD: /bin/chown
EOF

# Test syntax
if sudo visudo -c -f /tmp/test_sudoers; then
    echo "✓ Sudoers syntax is VALID"
    cat /tmp/test_sudoers
else
    echo "✗ Sudoers syntax is INVALID"
fi

rm /tmp/test_sudoers

