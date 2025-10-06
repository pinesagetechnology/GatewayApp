#!/usr/bin/env bash

set -e

# Main Installer for MonitoringServiceAPI
# This script handles the complete installation process including downloading, building, and installing the service

INSTALL_PATH="/opt/monitoringapi"
DATA_PATH=""
SERVICE_NAME="monitoringapi"
SERVICE_USER="monitoringapi"
API_PORT=5000
SKIP_DOTNET=false
VERBOSE=false
INTERACTIVE=true
DOWNLOAD_URL=""
BUILD_FROM_SOURCE=false
SOURCE_PATH=""
RELEASE_VERSION="latest"
CLEAN_INSTALL=false
SKIP_BUILD=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
err() { echo -e "${RED}✗${NC} $1"; }
step() { echo -e "${BLUE}==>${NC} $1"; }
info() { echo -e "${BLUE}ℹ${NC} $1"; }

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --install-path) INSTALL_PATH="$2"; shift 2;;
    --data-path) DATA_PATH="$2"; shift 2;;
    --api-port) API_PORT="$2"; shift 2;;
    --download-url) DOWNLOAD_URL="$2"; shift 2;;
    --source-path) SOURCE_PATH="$2"; BUILD_FROM_SOURCE=true; shift 2;;
    --release-version) RELEASE_VERSION="$2"; shift 2;;
    --skip-dotnet) SKIP_DOTNET=true; shift;;
    --skip-build) SKIP_BUILD=true; shift;;
    --clean-install) CLEAN_INSTALL=true; shift;;
    --verbose) VERBOSE=true; shift;;
    --non-interactive) INTERACTIVE=false; shift;;
    -h|--help)
      echo "MonitoringServiceAPI Main Installer"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Installation Options:"
      echo "  --install-path PATH      Installation directory (default: /opt/monitoringapi)"
      echo "  --data-path PATH         Data directory for logs (optional, default: /opt/monitoringapi/logs)"
      echo "  --api-port PORT          API port (default: 5000)"
      echo ""
      echo "Source Options (choose one):"
      echo "  --download-url URL       Download pre-built release from URL"
      echo "  --source-path PATH       Build from source code at PATH"
      echo "  --release-version VER    Specific release version (default: latest)"
      echo ""
      echo "Build Options:"
      echo "  --skip-build             Skip building if source provided"
      echo "  --skip-dotnet            Skip .NET runtime installation"
      echo "  --clean-install          Remove existing installation first"
      echo ""
      echo "General Options:"
      echo "  --verbose                Enable verbose output"
      echo "  --non-interactive        No prompts (requires --data-path)"
      echo "  -h, --help              Show this help"
      echo ""
      echo "Examples:"
      echo "  $0 --source-path /path/to/source --data-path /var/monitoringapi"
      echo "  $0 --download-url https://github.com/user/repo/releases/download/v1.0.0/release.tar.gz"
      echo "  $0 --non-interactive --data-path /var/monitoringapi --download-url https://..."
      exit 0;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

# Validation functions
check_root() {
  [ "$EUID" -eq 0 ] || { err "This script must be run as root (use sudo)"; exit 1; }
}

detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
  else
    err "Cannot detect Linux distribution"
    exit 1
  fi
}

prompt_data_path() {
  # MonitoringServiceAPI doesn't need a data path - use default if not specified
  if [ -z "$DATA_PATH" ]; then
    DATA_PATH="$INSTALL_PATH/logs"
    log "Using default data path: $DATA_PATH (for logs only)"
  fi
}

validate_paths() {
  step "Validating and creating directories..."
  
  # Create and validate data directory
  mkdir -p "$DATA_PATH" || { err "Cannot create data directory: $DATA_PATH"; exit 1; }
  
  # Test write permissions
  touch "$DATA_PATH/.write_test" && rm -f "$DATA_PATH/.write_test" || {
    err "Cannot write to data directory: $DATA_PATH"
    exit 1
  }
  
  log "Directory validation completed"
}

# Installation functions
install_prerequisites() {
  step "Installing system prerequisites..."
  
  case $DISTRO in
    ubuntu|debian)
      apt-get update
      apt-get install -y curl wget gpg software-properties-common apt-transport-https nginx unzip
      ;;
    centos|rhel|fedora)
      if command -v dnf >/dev/null 2>&1; then
        dnf install -y curl wget nginx unzip
      else
        yum install -y curl wget nginx unzip
      fi
      ;;
    *)
      warn "Unsupported distribution: $DISTRO"
      warn "Please ensure curl, wget, nginx, and unzip are installed"
      ;;
  esac
  
  log "Prerequisites installed"
}

check_dotnet() {
  command -v dotnet >/dev/null 2>&1 && dotnet --list-runtimes | grep -q "Microsoft.AspNetCore.App 8"
}

install_dotnet() {
  step "Installing .NET 8 runtime..."
  
  case $DISTRO in
    ubuntu|debian)
      wget -q https://packages.microsoft.com/config/$DISTRO/$VERSION/packages-microsoft-prod.deb -O /tmp/msprod.deb
      dpkg -i /tmp/msprod.deb && rm /tmp/msprod.deb
      apt-get update && apt-get install -y aspnetcore-runtime-8.0
      ;;
    centos|rhel|fedora)
      rpm -Uvh https://packages.microsoft.com/config/$DISTRO/$VERSION/packages-microsoft-prod.rpm
      if command -v dnf >/dev/null 2>&1; then
        dnf install -y aspnetcore-runtime-8.0
      else
        yum install -y aspnetcore-runtime-8.0
      fi
      ;;
    *)
      warn "Falling back to dotnet-install.sh for $DISTRO"
      curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh || \
      wget -q https://dot.net/v1/dotnet-install.sh -O /tmp/dotnet-install.sh
      chmod +x /tmp/dotnet-install.sh
      /tmp/dotnet-install.sh --runtime aspnetcore --channel 8.0 --install-dir /usr/share/dotnet
      ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet || true
      ;;
  esac
  
  check_dotnet || { err ".NET 8 runtime installation failed"; exit 1; }
  log ".NET 8 runtime installed successfully"
}

create_user_and_dirs() {
  step "Creating service user and directories..."
  
  # Create shared group for cross-service database access
  if ! getent group "monitor-services" &>/dev/null; then
    groupadd "monitor-services"
    log "Created shared group: monitor-services"
  else
    log "Shared group already exists: monitor-services"
  fi
  
  # Create service user if it doesn't exist
  if ! id "$SERVICE_USER" &>/dev/null; then
    useradd --system --home-dir "$INSTALL_PATH" --shell /bin/false "$SERVICE_USER"
    log "Created service user: $SERVICE_USER"
  else
    log "Service user already exists: $SERVICE_USER"
  fi
  
  # Add user to shared group for cross-service database access
  usermod -a -G "monitor-services" "$SERVICE_USER"
  log "Added $SERVICE_USER to monitor-services group"
  
  # Create installation directory and minimal data directory
  mkdir -p "$INSTALL_PATH" "$INSTALL_PATH/logs" "$DATA_PATH"
  chown -R "$SERVICE_USER:monitor-services" "$INSTALL_PATH"
  chown -R "$SERVICE_USER:monitor-services" "$DATA_PATH"
  chmod 755 "$INSTALL_PATH"
  chmod 755 "$DATA_PATH"
  
  log "User and directories created (no database directory - uses other services' databases)"
}

download_release() {
  step "Downloading MonitoringServiceAPI release..."
  
  local temp_dir="/tmp/monitoringapi-$$"
  mkdir -p "$temp_dir"
  cd "$temp_dir"
  
  if [[ "$DOWNLOAD_URL" =~ \.tar\.gz$ ]]; then
    wget -q "$DOWNLOAD_URL" -O release.tar.gz
    tar -xzf release.tar.gz
  elif [[ "$DOWNLOAD_URL" =~ \.zip$ ]]; then
    wget -q "$DOWNLOAD_URL" -O release.zip
    unzip -q release.zip
  else
    err "Unsupported download format. Please provide .tar.gz or .zip file"
    exit 1
  fi
  
  # Find the extracted directory
  local extracted_dir=$(find . -maxdepth 1 -type d -name "*MonitoringServiceAPI*" | head -1)
  if [ -z "$extracted_dir" ]; then
    extracted_dir="."
  fi
  
  # Copy files to installation directory
  cp -r "$extracted_dir"/* "$INSTALL_PATH/"
  
  # Clean up
  cd /
  rm -rf "$temp_dir"
  
  log "Release downloaded and extracted"
}

build_from_source() {
  step "Building MonitoringServiceAPI from source..."
  
  if [ ! -f "$SOURCE_PATH/MonitoringServiceAPI.csproj" ]; then
    err "Source path does not contain MonitoringServiceAPI.csproj: $SOURCE_PATH"
    exit 1
  fi
  
  cd "$SOURCE_PATH"
  
  # Restore dependencies
  log "Restoring NuGet packages..."
  dotnet restore
  
  # Publish the application
  log "Publishing application..."
  dotnet publish -c Release -o "$INSTALL_PATH" --self-contained false
  
  log "Application built and published successfully"
}

clean_existing_installation() {
  if [ "$CLEAN_INSTALL" = true ]; then
    step "Cleaning existing installation..."
    
    # Stop service if running
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
      systemctl stop "$SERVICE_NAME"
      log "Stopped existing service"
    fi
    
    # Remove installation files
    if [ -d "$INSTALL_PATH" ]; then
      rm -rf "$INSTALL_PATH"/*
      log "Cleaned installation directory"
    fi
  fi
}

configure_application() {
  step "Configuring application settings..."
  
  # Update appsettings.json
  local appsettings="$INSTALL_PATH/appsettings.json"
  if [ -f "$appsettings" ]; then
    # Backup original
    cp "$appsettings" "$appsettings.backup"
    
    # Update connection strings to point to other services' databases
    sed -i "s|\"FileMonitorConnection\":.*|\"FileMonitorConnection\": \"Data Source=/var/filemonitor/database/filemonitor.db\"|g" "$appsettings"
    sed -i "s|\"ApiMonitorConnection\":.*|\"ApiMonitorConnection\": \"Data Source=/var/apimonitor/database/apimonitor.db\"|g" "$appsettings"
    
    # Update URLs if present
    if grep -q "Urls" "$appsettings"; then
      sed -i "s|\"Urls\":.*|\"Urls\": \"http://localhost:$API_PORT\"|g" "$appsettings"
    fi
    
    log "Application settings updated to use other services' databases"
  else
    warn "appsettings.json not found, creating basic configuration"
    cat > "$appsettings" <<EOF
{
  "ConnectionStrings": {
    "FileMonitorConnection": "Data Source=/var/filemonitor/database/filemonitor.db",
    "ApiMonitorConnection": "Data Source=/var/apimonitor/database/apimonitor.db"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "Urls": "http://localhost:$API_PORT"
}
EOF
  fi
  
  # Set proper ownership
  chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_PATH"
}

create_systemd_service() {
  step "Creating systemd service..."
  
  cat > "/etc/systemd/system/$SERVICE_NAME.service" <<EOF
[Unit]
Description=MonitoringServiceAPI
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_PATH
ExecStart=/usr/bin/dotnet $INSTALL_PATH/MonitoringServiceAPI.dll
Restart=always
RestartSec=10
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://localhost:$API_PORT
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=false
ReadWritePaths=$INSTALL_PATH

[Install]
WantedBy=multi-user.target
EOF
  
  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME" || true
  
  log "Systemd service created and enabled"
}

configure_nginx() {
  step "Configuring Nginx reverse proxy..."
  
  cat > "/etc/nginx/sites-available/$SERVICE_NAME" <<EOF
server {
  listen 80;
  server_name localhost;
  
  location /api/ {
    proxy_pass http://localhost:$API_PORT;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_cache_bypass \$http_upgrade;
    proxy_read_timeout 300;
  }
  
  location /health {
    proxy_pass http://localhost:$API_PORT/health;
  }
  
  location /swagger {
    proxy_pass http://localhost:$API_PORT/swagger;
  }
}
EOF
  
  # Enable site
  ln -sfn "/etc/nginx/sites-available/$SERVICE_NAME" "/etc/nginx/sites-enabled/$SERVICE_NAME"
  
  # Remove default site if it exists
  rm -f /etc/nginx/sites-enabled/default
  
  # Test configuration
  nginx -t && systemctl reload nginx
  systemctl enable nginx || true
  
  log "Nginx configured successfully"
}

create_uninstaller() {
  step "Creating uninstaller script..."
  
  cat > "$INSTALL_PATH/uninstall.sh" <<EOF
#!/usr/bin/env bash
# MonitoringServiceAPI Uninstaller

echo "Uninstalling MonitoringServiceAPI..."

# Stop and disable service
systemctl stop $SERVICE_NAME 2>/dev/null || true
systemctl disable $SERVICE_NAME 2>/dev/null || true

# Remove service file
rm -f "/etc/systemd/system/$SERVICE_NAME.service"
systemctl daemon-reload

# Remove nginx configuration
rm -f "/etc/nginx/sites-available/$SERVICE_NAME"
rm -f "/etc/nginx/sites-enabled/$SERVICE_NAME"
systemctl reload nginx

# Remove installation directory
rm -rf "$INSTALL_PATH"

# Remove service user (optional)
read -p "Remove service user '$SERVICE_USER'? (y/N): " -n 1 -r
echo
if [[ \$REPLY =~ ^[Yy]$ ]]; then
  userdel "$SERVICE_USER" 2>/dev/null || true
fi

echo "Uninstallation completed"
EOF
  
  chmod +x "$INSTALL_PATH/uninstall.sh"
  log "Uninstaller created: $INSTALL_PATH/uninstall.sh"
}

create_management_script() {
  step "Creating management script..."
  
  cat > "$INSTALL_PATH/manage.sh" <<EOF
#!/usr/bin/env bash
# MonitoringServiceAPI Management Script

SERVICE_NAME="$SERVICE_NAME"

case "\$1" in
  start)
    echo "Starting $SERVICE_NAME..."
    systemctl start "\$SERVICE_NAME"
    ;;
  stop)
    echo "Stopping $SERVICE_NAME..."
    systemctl stop "\$SERVICE_NAME"
    ;;
  restart)
    echo "Restarting $SERVICE_NAME..."
    systemctl restart "\$SERVICE_NAME"
    ;;
  status)
    systemctl status "\$SERVICE_NAME"
    ;;
  logs)
    journalctl -u "\$SERVICE_NAME" -f
    ;;
  *)
    echo "Usage: \$0 {start|stop|restart|status|logs}"
    exit 1
    ;;
esac
EOF
  
  chmod +x "$INSTALL_PATH/manage.sh"
  log "Management script created: $INSTALL_PATH/manage.sh"
}

write_deployment_guide() {
  step "Creating deployment guide..."
  
  cat > "$INSTALL_PATH/DEPLOYMENT_GUIDE.txt" <<EOF
MonitoringServiceAPI Deployment Guide
=====================================

IMPORTANT: This service does NOT have its own database!
It provides a REST API to access and manage FileMonitor and APIMonitor services.

Installation Details:
- Installation Path: $INSTALL_PATH
- Data Path: $DATA_PATH (logs/config only, no database)
- API Port: $API_PORT
- Service Name: $SERVICE_NAME
- Service User: $SERVICE_USER

Database Access (External Services):
- FileMonitor DB: /var/filemonitor/database/filemonitor.db
- APIMonitor DB: /var/apimonitor/database/apimonitor.db
- Access via shared group: monitor-services

Prerequisites:
- FileMonitorWorkerService must be installed first
- APIMonitorWorkerService must be installed first
- Both services must be in the monitor-services group

Log Files:
- Service Logs: journalctl -u $SERVICE_NAME
- Application Logs: $DATA_PATH/logs/

Configuration:
- Main Config: $INSTALL_PATH/appsettings.json
- Nginx Config: /etc/nginx/sites-available/$SERVICE_NAME

Management Commands:
- Start: sudo systemctl start $SERVICE_NAME
- Stop: sudo systemctl stop $SERVICE_NAME
- Restart: sudo systemctl restart $SERVICE_NAME
- Status: sudo systemctl status $SERVICE_NAME
- Logs: sudo journalctl -u $SERVICE_NAME -f

Quick Management:
- Use: $INSTALL_PATH/manage.sh {start|stop|restart|status|logs}

Uninstallation:
- Run: $INSTALL_PATH/uninstall.sh

API Endpoints:
- Health Check: http://localhost/health
- Swagger UI: http://localhost/swagger
- API Base: http://localhost/api/

Service Status:
- Check if running: systemctl is-active $SERVICE_NAME
- Check if enabled: systemctl is-enabled $SERVICE_NAME

Troubleshooting:
- Check logs: journalctl -u $SERVICE_NAME --since "1 hour ago"
- Check nginx: nginx -t && systemctl status nginx
- Check port: netstat -tlnp | grep $API_PORT
- Verify database access: Check that FileMonitor and APIMonitor services are running
- Check group membership: groups $SERVICE_USER
EOF
  
  log "Deployment guide created: $INSTALL_PATH/DEPLOYMENT_GUIDE.txt"
}

main() {
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}    MonitoringServiceAPI Main Installer${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  
  # Initial checks
  check_root
  detect_distro
  prompt_data_path
  validate_paths
  
  # Validate source options
  if [ -z "$DOWNLOAD_URL" ] && [ -z "$SOURCE_PATH" ]; then
    err "Either --download-url or --source-path must be specified"
    echo "Use --help for more information"
    exit 1
  fi
  
  if [ -n "$DOWNLOAD_URL" ] && [ -n "$SOURCE_PATH" ]; then
    err "Cannot specify both --download-url and --source-path"
    exit 1
  fi
  
  # Installation steps
  install_prerequisites
  
  if [ "$SKIP_DOTNET" = false ]; then
    if ! check_dotnet; then
      install_dotnet
    else
      log ".NET 8 runtime already installed"
    fi
  fi
  
  create_user_and_dirs
  clean_existing_installation
  
  # Get application files
  if [ -n "$DOWNLOAD_URL" ]; then
    download_release
  elif [ -n "$SOURCE_PATH" ]; then
    if [ "$SKIP_BUILD" = false ]; then
      build_from_source
    else
      cp -r "$SOURCE_PATH"/* "$INSTALL_PATH/"
    fi
  fi
  
  # Configure and setup
  configure_application
  create_systemd_service
  configure_nginx
  create_uninstaller
  create_management_script
  write_deployment_guide
  
  # Final setup
  chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_PATH"
  
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}    Installation Completed Successfully!${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "Next steps:"
  echo "1. Start the service: sudo systemctl start $SERVICE_NAME"
  echo "2. Check status: sudo systemctl status $SERVICE_NAME"
  echo "3. View logs: sudo journalctl -u $SERVICE_NAME -f"
  echo "4. Access API: http://localhost/api/"
  echo "5. Health check: http://localhost/health"
  echo ""
  echo "Management:"
  echo "- Use: $INSTALL_PATH/manage.sh {start|stop|restart|status|logs}"
  echo "- Guide: $INSTALL_PATH/DEPLOYMENT_GUIDE.txt"
  echo "- Uninstall: $INSTALL_PATH/uninstall.sh"
  echo ""
}

# Run main function with all arguments
main "$@"
