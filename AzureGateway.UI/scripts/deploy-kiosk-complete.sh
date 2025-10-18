#!/bin/bash

# Complete Raspberry Pi Kiosk Deployment Script
# Description: One-script solution for deploying React app in kiosk mode
# Author: Senior Software Engineer
# Usage: sudo bash deploy-kiosk-complete.sh
# 
# This script:
# - Deploys the React application
# - Sets up PM2 properly
# - Configures Nginx
# - Sets up kiosk mode (tested and working)
# - Everything automated, no manual steps

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓] $1${NC}"; }
error() { echo -e "${RED}[✗] $1${NC}"; exit 1; }
warn() { echo -e "${YELLOW}[!] $1${NC}"; }
step() { echo -e "${BOLD}${BLUE}━━━ $1 ━━━${NC}"; }

# Check running as root
[[ $EUID -ne 0 ]] && error "Run this script with sudo"

# Detect the real user
if [ -n "$SUDO_USER" ]; then
    SERVICE_USER="$SUDO_USER"
else
    read -p "Enter username for the service: " SERVICE_USER
fi

# Validate user exists
id "$SERVICE_USER" &>/dev/null || error "User '$SERVICE_USER' does not exist!"

USER_HOME="/home/${SERVICE_USER}"
APP_DIR="/opt/react-ui-app"
APP_NAME="react-ui-app"

# Detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo ""
echo -e "${BOLD}${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${BLUE}║  Complete Raspberry Pi Kiosk Deployment           ║${NC}"
echo -e "${BOLD}${BLUE}║  User: ${SERVICE_USER}$(printf '%*s' $((41-${#SERVICE_USER})) '')║${NC}"
echo -e "${BOLD}${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
step "1. System Update & Package Installation"
# ============================================================================

apt update
apt install -y curl wget git nginx chromium-browser unclutter xdotool

log "System packages installed"

# ============================================================================
step "2. Install Node.js"
# ============================================================================

if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
fi

log "Node.js $(node --version) installed"

# ============================================================================
step "3. Install PM2"
# ============================================================================

if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
else
    npm install -g pm2@latest
    pm2 update
fi

log "PM2 $(pm2 --version) installed"

# ============================================================================
step "4. Deploy Application"
# ============================================================================

# Create app directory
mkdir -p $APP_DIR
chown $SERVICE_USER:$SERVICE_USER $APP_DIR

# Copy application files
cd "$PROJECT_ROOT"
if [[ ! -f "package.json" ]]; then
    error "package.json not found in ${PROJECT_ROOT}"
fi

log "Installing dependencies..."
su - $SERVICE_USER -c "cd $PROJECT_ROOT && npm install"

log "Building application..."
su - $SERVICE_USER -c "cd $PROJECT_ROOT && npm run build"

log "Copying build to ${APP_DIR}..."
rm -rf $APP_DIR/dist
cp -r "$PROJECT_ROOT/dist" $APP_DIR/
chown -R $SERVICE_USER:$SERVICE_USER $APP_DIR

log "Application deployed"

# ============================================================================
step "5. Configure PM2"
# ============================================================================

# Create ecosystem file
cat > $APP_DIR/ecosystem.config.js <<EOF
module.exports = {
  apps: [{
    name: 'ui-app',
    script: 'npx',
    args: 'serve -s dist -l 3001',
    cwd: '${APP_DIR}',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '512M',
    env: {
      NODE_ENV: 'production',
      PORT: 3001
    },
    error_file: '/var/log/${APP_NAME}/error.log',
    out_file: '/var/log/${APP_NAME}/out.log',
    log_file: '/var/log/${APP_NAME}/combined.log',
    time: true
  }]
};
EOF

# Create log directory
mkdir -p /var/log/$APP_NAME
chown $SERVICE_USER:$SERVICE_USER /var/log/$APP_NAME

# Install serve if not present
if ! command -v serve &> /dev/null; then
    npm install -g serve
fi

# Stop any existing PM2 processes
su - $SERVICE_USER -c "pm2 delete all 2>/dev/null || true"

# Start the application as service user
su - $SERVICE_USER -c "cd $APP_DIR && pm2 start ecosystem.config.js && pm2 save"

# Remove old PM2 systemd service
systemctl stop pm2-${SERVICE_USER}.service 2>/dev/null || true
systemctl disable pm2-${SERVICE_USER}.service 2>/dev/null || true
rm -f /etc/systemd/system/pm2-${SERVICE_USER}.service

# Create proper PM2 systemd service
env PATH=$PATH:/usr/bin pm2 startup systemd -u $SERVICE_USER --hp $USER_HOME

# Save PM2 config again
su - $SERVICE_USER -c "pm2 save"

# Create the correct service file (oneshot type)
cat > /etc/systemd/system/pm2-${SERVICE_USER}.service <<EOF
[Unit]
Description=PM2 process manager
Documentation=https://pm2.keymetrics.io/
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
User=${SERVICE_USER}
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Environment=PATH=/opt/dotnet:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games:/snap/bin:${USER_HOME}/.dotnet:${USER_HOME}/.dotnet/tools
Environment=PM2_HOME=${USER_HOME}/.pm2
Restart=no

ExecStart=/usr/lib/node_modules/pm2/bin/pm2 resurrect
ExecStop=/usr/lib/node_modules/pm2/bin/pm2 kill

[Install]
WantedBy=multi-user.target
EOF

# Enable and start PM2 service
systemctl daemon-reload
systemctl enable pm2-${SERVICE_USER}.service
systemctl start pm2-${SERVICE_USER}.service

log "PM2 configured and running"

# ============================================================================
step "6. Configure Nginx"
# ============================================================================

cat > /etc/nginx/sites-available/$APP_NAME <<EOF
server {
    listen 80;
    server_name localhost;
    
    location / {
        root ${APP_DIR}/dist;
        try_files \$uri \$uri/ /index.html;
        index index.html;
        
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    location /api/ {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
    
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
}
EOF

ln -sfn /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/$APP_NAME
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl reload nginx
systemctl enable nginx

log "Nginx configured"

# ============================================================================
step "7. Configure Kiosk Mode"
# ============================================================================

# Set graphical target
systemctl set-default graphical.target

# Configure auto-login
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${SERVICE_USER} --noclear %I \$TERM
EOF

# Disable screen blanking
cat > /etc/X11/Xsession.d/90-disable-dpms <<'EOF'
#!/bin/sh
xset s off
xset s noblank
xset -dpms
EOF
chmod +x /etc/X11/Xsession.d/90-disable-dpms

# Create autostart directory
mkdir -p "${USER_HOME}/.config/autostart"

# Hide desktop
cat > "${USER_HOME}/.config/autostart/hide-desktop.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Hide Desktop
Exec=pcmanfm --desktop-off
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Hide cursor
cat > "${USER_HOME}/.config/autostart/unclutter.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Unclutter
Exec=unclutter -idle 0.1 -root
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Kiosk browser with tested flags
cat > "${USER_HOME}/.config/autostart/kiosk.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Kiosk Browser
Exec=/bin/bash -c "sleep 15 && chromium-browser --kiosk --disable-gpu --disable-software-rasterizer --disable-dev-shm-usage --no-sandbox --noerrdialogs --disable-infobars --no-first-run --disable-translate --disable-features=TranslateUI http://localhost"
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

# Set ownership
chown -R ${SERVICE_USER}:${SERVICE_USER} "${USER_HOME}/.config"

log "Kiosk mode configured"

# ============================================================================
step "8. Create Helper Scripts"
# ============================================================================

# Exit kiosk
cat > /usr/local/bin/exit-kiosk <<'EOF'
#!/bin/bash
killall chromium 2>/dev/null || true
killall chromium-browser 2>/dev/null || true
echo "Kiosk closed. Desktop is accessible."
EOF
chmod +x /usr/local/bin/exit-kiosk

# Restart kiosk
cat > /usr/local/bin/restart-kiosk <<'EOF'
#!/bin/bash
killall chromium 2>/dev/null || true
killall chromium-browser 2>/dev/null || true
sleep 2
DISPLAY=:0 chromium-browser --kiosk --disable-gpu --disable-software-rasterizer --disable-dev-shm-usage --no-sandbox --noerrdialogs --disable-infobars --no-first-run http://localhost &
echo "Kiosk restarted"
EOF
chmod +x /usr/local/bin/restart-kiosk

log "Helper scripts created"

# ============================================================================
step "9. Verification"
# ============================================================================

sleep 2

# Check services
NGINX_STATUS=$(systemctl is-active nginx)
PM2_STATUS=$(systemctl is-active pm2-${SERVICE_USER}.service)
PM2_APP=$(su - $SERVICE_USER -c "pm2 list" | grep -q "online" && echo "running" || echo "stopped")

echo ""
echo -e "${BOLD}Service Status:${NC}"
echo -e "  Nginx: ${NGINX_STATUS}"
echo -e "  PM2 Service: ${PM2_STATUS}"
echo -e "  PM2 App: ${PM2_APP}"
echo ""

# ============================================================================
echo ""
echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║  ✓ Deployment Complete!                           ║${NC}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}Configuration:${NC}"
echo "  • User: ${SERVICE_USER}"
echo "  • App Directory: ${APP_DIR}"
echo "  • URL: http://localhost"
echo "  • PM2 Service: pm2-${SERVICE_USER}.service"
echo ""

echo -e "${BLUE}Features Enabled:${NC}"
echo "  ✓ Auto-login as ${SERVICE_USER}"
echo "  ✓ Kiosk mode (Chromium full-screen)"
echo "  ✓ PM2 auto-start on boot"
echo "  ✓ Nginx serving static files"
echo "  ✓ Screen blanking disabled"
echo "  ✓ Cursor auto-hide"
echo ""

echo -e "${BLUE}Useful Commands:${NC}"
echo "  • Exit kiosk: ${BOLD}exit-kiosk${NC}"
echo "  • Restart kiosk: ${BOLD}restart-kiosk${NC}"
echo "  • View PM2 apps: ${BOLD}pm2 list${NC}"
echo "  • View PM2 logs: ${BOLD}pm2 logs${NC}"
echo "  • SSH access: ${BOLD}ssh ${SERVICE_USER}@<raspberry-pi-ip>${NC}"
echo ""

echo -e "${YELLOW}Next Step:${NC}"
echo -e "${BOLD}sudo reboot${NC}"
echo ""
echo "After reboot, your app will display in full-screen kiosk mode."
echo ""

log "Script completed successfully!"

