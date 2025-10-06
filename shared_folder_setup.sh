#!/usr/bin/env bash

# Setup Shared Folder for .NET Services
# Quick permission setup for folders that need to be accessed by multiple services

set -e

SHARED_GROUP="monitor-services"
FOLDER_PATH="$1"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [ -z "$FOLDER_PATH" ]; then
    echo -e "${RED}Error: Folder path required${NC}"
    echo "Usage: sudo $0 /path/to/folder"
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Must run as root${NC}"
    exit 1
fi

# Expand and resolve path
FOLDER_PATH=$(eval echo "$FOLDER_PATH")
if command -v realpath >/dev/null 2>&1; then
    FOLDER_PATH=$(realpath -m "$FOLDER_PATH")
fi

# Create folder if it doesn't exist
mkdir -p "$FOLDER_PATH"

# Ensure group exists
if ! getent group "$SHARED_GROUP" &>/dev/null; then
    groupadd "$SHARED_GROUP"
fi

# Set permissions
chgrp -R "$SHARED_GROUP" "$FOLDER_PATH"
find "$FOLDER_PATH" -type d -exec chmod 775 {} \;
find "$FOLDER_PATH" -type f -exec chmod 664 {} \;

# Ensure parent directories are traversable
current_dir="$FOLDER_PATH"
while [ "$current_dir" != "/" ] && [ "$current_dir" != "/home" ]; do
    parent_dir=$(dirname "$current_dir")
    if [ -d "$parent_dir" ]; then
        parent_perms=$(stat -c '%a' "$parent_dir" 2>/dev/null)
        others_perm="${parent_perms: -1}"
        
        if [[ "$others_perm" =~ ^[0246]$ ]]; then
            first_two="${parent_perms:0:2}"
            case "$others_perm" in
                0) new_perms="${first_two}1" ;;
                2) new_perms="${first_two}3" ;;
                4) new_perms="${first_two}5" ;;
                6) new_perms="${first_two}7" ;;
            esac
            chmod "$new_perms" "$parent_dir"
        fi
    fi
    current_dir="$parent_dir"
done

echo -e "${GREEN}✓ Folder configured: $FOLDER_PATH${NC}"
echo "Group: $SHARED_GROUP | Permissions: 775 (dirs), 664 (files)"
exit 0
