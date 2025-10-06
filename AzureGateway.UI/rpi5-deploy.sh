#!/bin/bash

# Raspberry Pi 5 UI Deployment Script
# Author: Senior Software Engineer
# Description: Deploy React TypeScript UI application on Raspberry Pi 5

set -e  # Exit on any error

# Configuration
APP_NAME="react-ui-app"
APP_DIR="/opt/${APP_NAME}"
NODE_VERSION="18.19.0"
PM2_APP_NAME="ui-app"

# Get service user from user input
get_service_user() {
    echo -e "${BLUE}Please enter the service user for the application:${NC}"
    read -p "Service user (default: pi): " SERVICE_USER
    SERVICE_USER=${SERVICE_USER:-pi}
    
    # Validate that the user exists
    if ! id "$SERVICE_USER" &>/dev/null; then
        error "User '$SERVICE_USER' does not exist. Please create the user first or enter a valid username."
    fi
    
    log "Using service user: $SERVICE_USER"
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as regular user with sudo privileges."
    fi
}

# Update system packages
update_system() {
    log "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget git build-essential python3 python3-pip nginx
}

# Install Node.js using NodeSource repository
install_nodejs() {
    log "Installing Node.js ${NODE_VERSION}..."
    
    # Check if Node.js is already installed
    if command -v node &> /dev/null; then
        CURRENT_VERSION=$(node --version | sed 's/v//')
        if [[ "$CURRENT_VERSION" == "$NODE_VERSION"* ]]; then
            log "Node.js ${NODE_VERSION} is already installed"
            return
        fi
    fi
    
    # Install Node.js 18.x
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    
    # Verify installation
    log "Node.js version: $(node --version)"
    log "npm version: $(npm --version)"
}

# Install PM2 globally
install_pm2() {
    log "Installing PM2 process manager..."
    
    # Check if PM2 is already installed
    if command -v pm2 &> /dev/null; then
        log "PM2 is already installed. Updating..."
        sudo npm install -g pm2@latest
        
        # Update the in-memory PM2 daemon to match the CLI version
        pm2 update
        log "PM2 updated successfully"
    else
        log "Installing PM2..."
        sudo npm install -g pm2
        log "PM2 installed successfully"
    fi
    
    # Setup PM2 startup script
    sudo pm2 startup systemd -u $SERVICE_USER --hp /home/$SERVICE_USER
}

# Create application directory and set permissions
setup_app_directory() {
    log "Setting up application directory..."
    
    sudo mkdir -p $APP_DIR
    sudo chown $SERVICE_USER:$SERVICE_USER $APP_DIR
    chmod 755 $APP_DIR
}

# Deploy application
deploy_app() {
    log "Deploying application to ${APP_DIR}..."
    
    # Ensure we're in a project directory
    if [[ ! -f "package.json" ]]; then
        error "package.json not found. Please run this script from your project root directory."
    fi

    # Install dependencies (including dev dependencies for build)
    log "Installing dependencies..."
    npm install

    # Build the application
    log "Building application..."
    npm run build

    # Prepare target directory and copy only built assets
    log "Copying build artifacts to ${APP_DIR}/dist ..."
    sudo mkdir -p "$APP_DIR"
    if [[ -d "$APP_DIR/dist" ]]; then
        sudo rm -rf "$APP_DIR/dist"
    fi
    sudo cp -r dist "$APP_DIR/"

    # Set proper permissions
    sudo chown -R $SERVICE_USER:$SERVICE_USER $APP_DIR
}

# Configure Nginx reverse proxy
configure_nginx() {
    log "Configuring Nginx reverse proxy..."
    
    # Create Nginx configuration
    sudo tee /etc/nginx/sites-available/$APP_NAME > /dev/null <<EOF
server {
    listen 80;
    server_name localhost;
    
    # Serve static files directly
    location / {
        root ${APP_DIR}/dist;
        try_files \$uri \$uri/ /index.html;
        index index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://localhost:5000/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Proxy API requests to backend (adjust port if needed)
    location /api/ {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;
}
EOF
    
    # Enable the site explicitly and disable default
    sudo ln -sfn /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/$APP_NAME
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test and reload Nginx
    sudo nginx -t && sudo systemctl reload nginx
    sudo systemctl enable nginx
    
    log "Nginx configured successfully"
}

# Create PM2 ecosystem file
create_pm2_config() {
    log "Creating PM2 configuration..."
    
    cat > $APP_DIR/ecosystem.config.js <<EOF
module.exports = {
  apps: [
    {
      name: '${PM2_APP_NAME}',
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
    }
  ]
};
EOF
    
    # Create log directory
    sudo mkdir -p /var/log/$APP_NAME
    sudo chown $SERVICE_USER:$SERVICE_USER /var/log/$APP_NAME
}

# Start services
start_services() {
    log "Starting services..."
    
    cd $APP_DIR
    
    # Install serve globally if not present
    if ! command -v serve &> /dev/null; then
        sudo npm install -g serve
    fi
    
    # Stop any existing PM2 processes
    pm2 delete $PM2_APP_NAME 2>/dev/null || true
    
    # Start the application with PM2
    pm2 start ecosystem.config.js
    pm2 save
    
    # Enable PM2 to start on boot
    sudo pm2 startup systemd -u $SERVICE_USER --hp /home/$SERVICE_USER
    
    log "Services started successfully"
}

# Setup firewall
setup_firewall() {
    log "Configuring firewall..."
    
    # Install UFW if not present
    sudo apt install -y ufw
    
    # Configure firewall rules
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw --force enable
    
    log "Firewall configured successfully"
}

# System optimization for Raspberry Pi
optimize_system() {
    log "Optimizing system for Raspberry Pi..."
    
    # Increase swap if needed
    CURRENT_SWAP=$(free -m | awk '/^Swap:/ {print $2}')
    if [[ $CURRENT_SWAP -lt 1024 ]]; then
        log "Increasing swap space..."
        sudo dphys-swapfile swapoff
        sudo sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
        sudo dphys-swapfile setup
        sudo dphys-swapfile swapon
    fi
    
    # GPU memory split optimization
    if ! grep -q "gpu_mem=64" /boot/config.txt; then
        echo "gpu_mem=64" | sudo tee -a /boot/config.txt
        warn "GPU memory split updated. Reboot required to take effect."
    fi
    
    # Set CPU governor to performance
    echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
    
    log "System optimization completed"
}

# Health check
health_check() {
    log "Performing health check..."
    
    # Check if services are running
    if pm2 list | grep -q $PM2_APP_NAME; then
        log "✓ PM2 service is running"
    else
        error "✗ PM2 service is not running"
    fi
    
    if systemctl is-active --quiet nginx; then
        log "✓ Nginx is running"
    else
        error "✗ Nginx is not running"
    fi
    
    # Check if application is accessible
    sleep 5
    if curl -s http://localhost > /dev/null; then
        log "✓ Application is accessible"
    else
        warn "✗ Application may not be accessible on port 80"
    fi
    
    log "Health check completed"
}

# Display final information
show_info() {
    log "Deployment completed successfully!"
    echo ""
    echo -e "${BLUE}=== Deployment Information ===${NC}"
    echo -e "Application Directory: ${APP_DIR}"
    echo -e "Web Interface: http://$(hostname -I | awk '{print $1}')"
    echo -e "Local Access: http://localhost"
    echo -e "Logs: /var/log/${APP_NAME}/"
    echo ""
    echo -e "${BLUE}=== Useful Commands ===${NC}"
    echo -e "View PM2 status: pm2 status"
    echo -e "View PM2 logs: pm2 logs ${PM2_APP_NAME}"
    echo -e "Restart app: pm2 restart ${PM2_APP_NAME}"
    echo -e "View Nginx logs: sudo tail -f /var/log/nginx/access.log"
    echo -e "Restart Nginx: sudo systemctl restart nginx"
    echo ""
}

# Main deployment function
main() {
    log "Starting Raspberry Pi 5 UI deployment..."
    
    get_service_user
    check_root
    update_system
    install_nodejs
    install_pm2
    setup_app_directory
    deploy_app
    configure_nginx
    create_pm2_config
    start_services
    setup_firewall
    optimize_system
    health_check
    show_info
    
    log "Deployment script completed successfully!"
}

# Handle script interruption
trap 'error "Deployment interrupted"' INT TERM

# Run main function
main "$@"