#!/usr/bin/env bash

set -e

INSTALL_PATH="/opt/monitoringapi"
DATA_PATH=""
SERVICE_NAME="monitoringapi"
SERVICE_USER="monitoringapi"
SHARED_GROUP="monitor-services"
API_PORT=5000
SKIP_DOTNET=false
VERBOSE=false
INTERACTIVE=true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log() { echo -e "${GREEN}✓${NC} $1"; }; warn() { echo -e "${YELLOW}⚠${NC} $1"; }; err() { echo -e "${RED}✗${NC} $1"; };
step() { echo -e "${BLUE}==>${NC} $1"; }

while [[ $# -gt 0 ]]; do
  case $1 in
    --install-path) INSTALL_PATH="$2"; shift 2;;
    --data-path) DATA_PATH="$2"; shift 2;;
    --api-port) API_PORT="$2"; shift 2;;
    --skip-dotnet) SKIP_DOTNET=true; shift;;
    --verbose) VERBOSE=true; shift;;
    --non-interactive) INTERACTIVE=false; shift;;
    -h|--help)
      echo "MonitoringServiceAPI Linux Installation (Basic Installer)"
      echo ""
      echo "This script configures and installs MonitoringServiceAPI assuming"
      echo "the application files are already present in the install directory."
      echo ""
      echo "For complete installation (including downloading/building the app),"
      echo "use MonitoringServiceAPI_MainInstaller.sh instead."
      echo ""
      echo "Options:"
      echo "--install-path PATH   (default: /opt/monitoringapi)"
      echo "--data-path PATH      (optional, default: /opt/monitoringapi/logs)"
      echo "--api-port PORT       (default: 5000)"
      echo "--skip-dotnet         Skip .NET install"
      echo "--non-interactive     No prompts"
      echo ""
      echo "Usage:"
      echo "1. Copy application files to /opt/monitoringapi/"
      echo "2. Run: sudo $0 --data-path /var/monitoringapi"
      exit 0;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

check_root() { [ "$EUID" -eq 0 ] || { err "Run as root (sudo)"; exit 1; }; }

detect_distro() {
  . /etc/os-release || { err "Cannot detect distro"; exit 1; }
  DISTRO=$ID; VERSION=$VERSION_ID
}

prompt_data_path() {
  # MonitoringServiceAPI doesn't need a data path - use default if not specified
  if [ -z "$DATA_PATH" ]; then
    DATA_PATH="$INSTALL_PATH/logs"
    log_info "Using default data path: $DATA_PATH (for logs only)"
  fi
}

validate_paths() {
  mkdir -p "$DATA_PATH" || { err "Cannot create $DATA_PATH"; exit 1; }
  touch "$DATA_PATH/.w" && rm -f "$DATA_PATH/.w" || { err "Cannot write to $DATA_PATH"; exit 1; }
}

install_packages() {
  step "Installing prerequisites…"
  case $DISTRO in
    ubuntu|debian) apt-get update; apt-get install -y curl wget gpg software-properties-common apt-transport-https nginx;;
    *) warn "Non-Debian distro detected. Ensure curl/wget/gpg/nginx installed.";;
  esac
}

dotnet_ok() { command -v dotnet &>/dev/null && dotnet --list-runtimes | grep -q "Microsoft.AspNetCore.App 8"; }

install_dotnet() {
  step "Installing .NET 8 runtime…"
  case $DISTRO in
    ubuntu|debian)
      wget https://packages.microsoft.com/config/$DISTRO/$VERSION/packages-microsoft-prod.deb -O /tmp/msprod.deb
      dpkg -i /tmp/msprod.deb && rm /tmp/msprod.deb
      apt-get update && apt-get install -y aspnetcore-runtime-8.0;;
    *) warn "Falling back to dotnet-install.sh";
       curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh || wget -q https://dot.net/v1/dotnet-install.sh -O /tmp/dotnet-install.sh
       chmod +x /tmp/dotnet-install.sh
       /tmp/dotnet-install.sh --runtime aspnetcore --channel 8.0 --install-dir /usr/share/dotnet
       ln -sf /usr/share/dotnet/dotnet /usr/bin/dotnet || true;;
  esac
  dotnet_ok || { err ".NET 8 runtime not available"; exit 1; }
}

setup_shared_group() {
  step "Setting up shared group for cross-service database access…"
  # Create shared group if it doesn't exist
  getent group "$SHARED_GROUP" &>/dev/null || groupadd "$SHARED_GROUP"
  log "Shared group '$SHARED_GROUP' ready"
}

create_user_dirs() {
  step "Creating user and directories…"
  id "$SERVICE_USER" &>/dev/null || useradd --system --home-dir "$INSTALL_PATH" --shell /bin/false "$SERVICE_USER"
  
  # Add user to shared group for cross-service database access
  usermod -a -G "$SHARED_GROUP" "$SERVICE_USER" || true
  log "Added $SERVICE_USER to $SHARED_GROUP group"
  
  # Create minimal directories (MonitoringServiceAPI doesn't need much)
  mkdir -p "$INSTALL_PATH" "$INSTALL_PATH/logs"
  
  # Set ownership with shared group
  chown -R "$SERVICE_USER:$SHARED_GROUP" "$INSTALL_PATH"
  
  # Set permissions
  chmod 755 "$INSTALL_PATH"
}

update_config() {
  step "Updating appsettings (if present)…"
  for f in "$INSTALL_PATH/appsettings.json" "$INSTALL_PATH/appsettings.Development.json"; do
    [ -f "$f" ] || continue
    cp "$f" "$f.backup" || true
    
    # Update connection strings to point to other services' databases
    # Note: These paths should be updated to match actual FileMonitor and APIMonitor data paths
    sed -i "s|\"FileMonitorConnection\":.*|\"FileMonitorConnection\": \"Data Source=/var/filemonitor/database/filemonitor.db\"|g" "$f" || true
    sed -i "s|\"ApiMonitorConnection\":.*|\"ApiMonitorConnection\": \"Data Source=/var/apimonitor/database/apimonitor.db\"|g" "$f" || true
    
    if grep -q "Urls" "$f"; then
      sed -i "s|\"Urls\":.*|\"Urls\": \"http://localhost:$API_PORT\"|g" "$f" || true
    fi
  done
}

create_service() {
  step "Creating systemd service…"
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
}

configure_nginx() {
  step "Configuring Nginx reverse proxy…"
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
}
EOF
  ln -sfn "/etc/nginx/sites-available/$SERVICE_NAME" "/etc/nginx/sites-enabled/$SERVICE_NAME"
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl reload nginx
  systemctl enable nginx || true
}

write_guide() {
  cat > "$INSTALL_PATH/DEPLOYMENT_GUIDE.txt" <<EOF
MonitoringServiceAPI Deployment
==============================

This service is a REST API that provides configuration management and data access
for FileMonitorWorkerService and APIMonitorWorkerService. It does NOT have its own database.

Deployment:
- Publish: dotnet publish -c Release -o publish
- Copy:    sudo cp -r publish/* $INSTALL_PATH/
- SetOwner: sudo chown -R $SERVICE_USER:$SERVICE_USER $INSTALL_PATH

Configuration:
- Port:    $API_PORT (ASPNETCORE_URLS)
- Service: $SERVICE_NAME
- Data Path: $DATA_PATH (logs/config only, no database)

Database Access:
- FileMonitor DB: /var/filemonitor/database/filemonitor.db
- APIMonitor DB:  /var/apimonitor/database/apimonitor.db
- Access via shared group: $SHARED_GROUP

Prerequisites:
- FileMonitorWorkerService must be installed first
- APIMonitorWorkerService must be installed first
- Both services must be in the $SHARED_GROUP for database access
EOF
}

main() {
  echo -e "${GREEN}=== MonitoringServiceAPI Basic Installer ===${NC}"
  check_root; detect_distro; prompt_data_path; validate_paths
  install_packages
  [ "$SKIP_DOTNET" = true ] || dotnet_ok || install_dotnet
  setup_shared_group
  create_user_dirs
  if [ ! -f "$INSTALL_PATH/MonitoringServiceAPI.dll" ]; then
    warn "No app files in $INSTALL_PATH."
    warn "This script assumes the application files are already present."
    warn "Use MonitoringServiceAPI_MainInstaller.sh for complete installation including downloading/building the app."
    write_guide; exit 0
  fi
  update_config
  create_service
  configure_nginx
  write_guide
  echo -e "${GREEN}Done. Start: sudo systemctl start $SERVICE_NAME${NC}"
}

main "$@"


