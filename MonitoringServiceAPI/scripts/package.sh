#!/usr/bin/env bash

# Quick Package Script for MonitoringServiceAPI
# Creates a simple distribution package with installers

set -e

# Configuration
VERSION=$(date +"%Y%m%d-%H%M%S")
PACKAGE_NAME="MonitoringServiceAPI-$VERSION"
PACKAGE_DIR="packages/$PACKAGE_NAME"
SOURCE_DIR="../MonitoringServiceAPI"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
err() { echo -e "${RED}✗${NC} $1"; }
step() { echo -e "${BLUE}==>${NC} $1"; }

# Check if we're in the scripts directory
if [ ! -f "MonitoringServiceAPI_MainInstaller.sh" ]; then
  err "Please run this script from the scripts directory"
  exit 1
fi

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
  err "Source directory not found: $SOURCE_DIR"
  exit 1
fi

# Create package directory
step "Creating package directory..."
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Copy application files
step "Copying application files..."
if [ -d "$SOURCE_DIR/bin/Release/net8.0/publish" ]; then
  cp -r "$SOURCE_DIR/bin/Release/net8.0/publish"/* "$PACKAGE_DIR/"
  log "Copied published files"
else
  warn "No published files found. Building application..."
  cd "$SOURCE_DIR"
  dotnet publish -c Release -o publish
  cp -r publish/* "../scripts/$PACKAGE_DIR/"
  rm -rf publish
  cd "../scripts"
  log "Built and copied application files"
fi

# Copy installation scripts
step "Copying installation scripts..."
cp "MonitoringServiceAPI_MainInstaller.sh" "$PACKAGE_DIR/"
cp "MonitoringServiceAPI_Linux_Installation.sh" "$PACKAGE_DIR/"

# Create quick install script
step "Creating quick install script..."
cat > "$PACKAGE_DIR/quick-install.sh" <<'EOF'
#!/usr/bin/env bash

echo "MonitoringServiceAPI Quick Install"
echo "================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root (use sudo)"
  exit 1
fi

# Default values
DATA_PATH="/var/monitoringapi"
API_PORT="5000"

echo "Quick installation with defaults:"
echo "- Data directory: $DATA_PATH"
echo "- API port: $API_PORT"
echo "- Installation path: /opt/monitoringapi"
echo ""

read -p "Continue with these settings? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Installation cancelled"
  exit 0
fi

# Run the main installer
echo "Starting installation..."
bash MonitoringServiceAPI_MainInstaller.sh \
  --source-path . \
  --data-path "$DATA_PATH" \
  --api-port "$API_PORT" \
  --non-interactive

echo ""
echo "Installation completed!"
echo "Start the service with: sudo systemctl start monitoringapi"
echo "Check status with: sudo systemctl status monitoringapi"
EOF

chmod +x "$PACKAGE_DIR/quick-install.sh"

# Create README
step "Creating README..."
cat > "$PACKAGE_DIR/README.md" <<EOF
# MonitoringServiceAPI $VERSION

## Quick Installation

Run the quick installer:
\`\`\`bash
sudo bash quick-install.sh
\`\`\`

## Manual Installation

For custom configuration, use the full installer:
\`\`\`bash
sudo bash MonitoringServiceAPI_MainInstaller.sh --source-path . --data-path /your/data/path
\`\`\`

## Requirements

- Linux system (Ubuntu/Debian/CentOS/RHEL)
- .NET 8 Runtime (will be installed automatically)
- Root/sudo access

## Default Configuration

- **Installation Path:** /opt/monitoringapi
- **Data Path:** /var/monitoringapi
- **API Port:** 5000
- **Service Name:** monitoringapi
- **Web Access:** http://localhost/api/
- **Health Check:** http://localhost/health
- **Swagger UI:** http://localhost/swagger

## Post-Installation

After installation, the service will be:
- Enabled to start on boot
- Configured with Nginx reverse proxy
- Accessible via systemctl commands

### Service Management
\`\`\`bash
# Start the service
sudo systemctl start monitoringapi

# Stop the service
sudo systemctl stop monitoringapi

# Restart the service
sudo systemctl restart monitoringapi

# Check status
sudo systemctl status monitoringapi

# View logs
sudo journalctl -u monitoringapi -f
\`\`\`

### File Locations
- **Application:** /opt/monitoringapi/
- **Database:** /var/monitoringapi/database/
- **Logs:** /var/monitoringapi/logs/
- **Configuration:** /opt/monitoringapi/appsettings.json
- **Service File:** /etc/systemd/system/monitoringapi.service
- **Nginx Config:** /etc/nginx/sites-available/monitoringapi

## Troubleshooting

1. **Check service status:**
   \`\`\`bash
   sudo systemctl status monitoringapi
   \`\`\`

2. **View recent logs:**
   \`\`\`bash
   sudo journalctl -u monitoringapi --since "1 hour ago"
   \`\`\`

3. **Test API connectivity:**
   \`\`\`bash
   curl http://localhost/health
   \`\`\`

4. **Check port binding:**
   \`\`\`bash
   sudo netstat -tlnp | grep 5000
   \`\`\`

## Uninstallation

To uninstall:
\`\`\`bash
sudo /opt/monitoringapi/uninstall.sh
\`\`\`

## Support

For issues and support, please refer to the project documentation or contact support.
EOF

# Create package archive
step "Creating package archive..."
cd packages
tar -czf "$PACKAGE_NAME.tar.gz" "$PACKAGE_NAME"
cd ..

# Generate checksum
step "Generating checksum..."
cd packages
sha256sum "$PACKAGE_NAME.tar.gz" > "$PACKAGE_NAME.tar.gz.sha256"
cd ..

# Display summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Package Created Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Package: packages/$PACKAGE_NAME.tar.gz"
echo "Checksum: packages/$PACKAGE_NAME.tar.gz.sha256"
echo "Size: $(du -h packages/$PACKAGE_NAME.tar.gz | cut -f1)"
echo ""
echo "Package Contents:"
echo "- MonitoringServiceAPI application files"
echo "- MonitoringServiceAPI_MainInstaller.sh (full installer)"
echo "- MonitoringServiceAPI_Linux_Installation.sh (basic installer)"
echo "- quick-install.sh (simple installer)"
echo "- README.md (installation guide)"
echo ""
echo "To distribute:"
echo "1. Upload packages/$PACKAGE_NAME.tar.gz to your distribution point"
echo "2. Users can download and extract: tar -xzf $PACKAGE_NAME.tar.gz"
echo "3. Run: sudo bash quick-install.sh"
echo ""

log "Package creation completed!"
