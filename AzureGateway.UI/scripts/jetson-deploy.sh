#!/bin/bash

# NVIDIA Jetson UI Deployment Script
# Author: Senior Software Engineer
# Description: Deploy React TypeScript UI application on NVIDIA Jetson devices

set -e  # Exit on any error

# Configuration
APP_NAME="react-ui-app"
APP_DIR="/opt/${APP_NAME}"
NODE_VERSION="18.19.0"
PM2_APP_NAME="ui-app"

# Get service user from user input
get_service_user() {
    echo -e "${BLUE}Please enter the service user for the application:${NC}"
    read -p "Service user (default: jetson): " SERVICE_USER
    SERVICE_USER=${SERVICE_USER:-jetson}
    
    # Validate that the user exists
    if ! id "$SERVICE_USER" &>/dev/null; then
        error "User '$SERVICE_USER' does not exist. Please create the user first or enter a valid username."
    fi
    
    log "Using service user: $SERVICE_USER"
}

# Jetson-specific configurations
JETSON_MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "Unknown")
CUDA_VERSION="11.4"

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

# Check if running on Jetson
check_jetson() {
    if [[ ! -f /etc/nv_tegra_release ]] && [[ ! -f /sys/devices/soc0/machine ]]; then
        warn "This script is designed for NVIDIA Jetson devices. Current device: $JETSON_MODEL"
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    log "Detected Jetson device: $JETSON_MODEL"
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
    sudo apt install -y curl wget git rsync build-essential python3 python3-pip nginx
    
    # Install Jetson-specific packages
    sudo apt install -y nvidia-l4t-jetson-multimedia-api

    # Try to install jetson-stats via apt; if unavailable, fall back to pip3
    if sudo apt install -y jetson-stats; then
        log "Installed jetson-stats via apt"
    else
        warn "apt package 'jetson-stats' not found. Installing via pip3 instead..."
        if sudo -H pip3 install -U jetson-stats; then
            # Ensure jtop is on PATH for all users
            if [[ -f /usr/local/bin/jtop && ! -f /usr/bin/jtop ]]; then
                sudo ln -s /usr/local/bin/jtop /usr/bin/jtop || true
            fi
            log "Installed jetson-stats (jtop) via pip3"
        else
            warn "Failed to install jetson-stats via pip3. Continuing without it."
        fi
    fi
    
    log "System packages updated successfully"
}

# Install Node.js using ARM64 binaries
install_nodejs() {
    log "Installing Node.js ${NODE_VERSION} for ARM64..."
    
    # Check if Node.js is already installed
    if command -v node &> /dev/null; then
        CURRENT_VERSION=$(node --version | sed 's/v//')
        if [[ "$CURRENT_VERSION" == "$NODE_VERSION"* ]]; then
            log "Node.js ${NODE_VERSION} is already installed"
            return
        fi
    fi
    
    # Download and install Node.js ARM64 binary
    cd /tmp
    NODE_TARBALL="node-v${NODE_VERSION}-linux-arm64.tar.xz"
    NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_TARBALL}"
    
    log "Downloading Node.js from $NODE_URL"
    wget -q $NODE_URL
    
    # Extract and install
    sudo tar -C /usr/local --strip-components=1 -xf $NODE_TARBALL
    
    # Clean up
    rm $NODE_TARBALL
    
    # Update PATH if needed
    if ! echo $PATH | grep -q "/usr/local/bin"; then
        echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
        export PATH="/usr/local/bin:$PATH"
    fi
    
    # Verify installation
    log "Node.js version: $(node --version)"
    log "npm version: $(npm --version)"
}

# Install PM2 globally
install_pm2() {
    log "Installing PM2 process manager..."
    sudo npm install -g pm2
    
    # Setup PM2 startup script
    sudo pm2 startup systemd -u $SERVICE_USER --hp /home/$SERVICE_USER
    
    log "PM2 installed successfully"
}

# Create application directory and set permissions
setup_app_directory() {
    log "Setting up application directory..."
    
    sudo mkdir -p $APP_DIR
    # Own by current user for copy/build, reassign to service user after build
    sudo chown $USER:$USER $APP_DIR
    chmod 755 $APP_DIR
}

# Deploy application
deploy_app() {
    log "Deploying application to ${APP_DIR}..."
    
    # Determine project directory (defaults to current working directory)
    local PROJECT_DIR=${PROJECT_DIR:-$PWD}
    log "Using project directory: ${PROJECT_DIR}"
    
    # Copy files from project directory to app directory, excluding VCS and heavy folders
    if command -v rsync &> /dev/null; then
        rsync -a --delete \
            --exclude='.git' \
            --exclude='.github' \
            --exclude='.gitignore' \
            --exclude='node_modules' \
            --exclude='dist' \
            "${PROJECT_DIR}/" "$APP_DIR/"
    else
        warn "rsync not available; falling back to cp -r (will include .git if present)"
        cp -r "${PROJECT_DIR}/." "$APP_DIR/"
    fi
    cd "$APP_DIR"
    
    # Verify package.json exists after copy
    if [[ ! -f "package.json" ]]; then
        error "package.json not found in ${APP_DIR}. Ensure you run the script from your project root or set PROJECT_DIR to the project path."
    fi
    
    # Install dependencies with ARM64 optimizations (including dev dependencies for build)
    log "Installing dependencies..."
    npm install
    
    # Build the application
    log "Building application..."
    npm run build
    
    # Set proper permissions
    sudo chown -R $SERVICE_USER:$SERVICE_USER $APP_DIR
}

# Configure Nginx with Jetson optimizations
configure_nginx() {
    log "Configuring Nginx reverse proxy with Jetson optimizations..."
    
    # Create Nginx configuration for Jetson (server block only)
    sudo tee /etc/nginx/sites-available/$APP_NAME > /dev/null <<'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /opt/react-ui-app/dist;
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Serve static files directly
    location / {
        try_files $uri $uri/ /index.html;

        # Cache headers for static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            access_log off;
        }
    }

    # Proxy API requests to backend (adjust port if needed)
    location /api/ {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # SignalR hub with WebSocket support (if backend exists)
    location /hubs/ {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }

    # SignalR hub (non-prefixed route used by API)
    location /uploadStatusHub {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }

    # Gzip compression optimized for ARM
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json
        application/xml
        image/svg+xml;
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

# Create PM2 ecosystem file with Jetson optimizations
create_pm2_config() {
    log "Creating PM2 configuration with Jetson optimizations..."
    
    # Get available memory and CPU cores
    TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
    CPU_CORES=$(nproc)
    
    # Calculate memory limit (use 25% of total memory, max 1GB)
    MEM_LIMIT=$((TOTAL_MEM / 4))
    if [[ $MEM_LIMIT -gt 1024 ]]; then
        MEM_LIMIT=1024
    fi
    
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
      max_memory_restart: '${MEM_LIMIT}M',
      min_uptime: '10s',
      max_restarts: 10,
      env: {
        NODE_ENV: 'production',
        PORT: 3001,
        UV_THREADPOOL_SIZE: ${CPU_CORES}
      },
      error_file: '/var/log/${APP_NAME}/error.log',
      out_file: '/var/log/${APP_NAME}/out.log',
      log_file: '/var/log/${APP_NAME}/combined.log',
      time: true,
      // Jetson-specific optimizations
      node_args: [
        '--max-old-space-size=${MEM_LIMIT}',
        '--optimize-for-size'
      ]
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

# Jetson-specific optimizations
optimize_jetson() {
    log "Applying Jetson-specific optimizations..."
    
    # Set CPU governor to performance
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
        
        # Make it persistent
        sudo tee /etc/systemd/system/cpu-performance.service > /dev/null <<EOF
[Unit]
Description=Set CPU governor to performance mode
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl enable cpu-performance.service
        log "CPU governor set to performance mode"
    fi
    
    # Maximize GPU memory allocation if available
    if command -v jetson_clocks &> /dev/null; then
        sudo jetson_clocks
        log "Jetson clocks maximized"
    fi
    
    # Set power mode to maximum performance (if supported)
    if command -v nvpmodel &> /dev/null; then
        sudo nvpmodel -m 0 2>/dev/null || log "Max performance mode not available"
    fi
    
    # Increase swap if needed
    CURRENT_SWAP=$(free -m | awk '/^Swap:/ {print $2}')
    if [[ $CURRENT_SWAP -lt 2048 ]]; then
        log "Creating swap file for better memory management..."
        sudo fallocate -l 2G /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
    
    # Optimize memory management
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    echo 'vm.dirty_ratio=15' | sudo tee -a /etc/sysctl.conf
    echo 'vm.dirty_background_ratio=5' | sudo tee -a /etc/sysctl.conf
    
    log "Jetson optimizations completed"
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
    
    # Check system resources
    log "System resource usage:"
    echo "Memory: $(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2 }')"
    echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
    
    if command -v tegrastats &> /dev/null; then
        log "GPU status available via: sudo tegrastats"
    fi
    
    log "Health check completed"
}

# Display final information
show_info() {
    log "Deployment completed successfully!"
    echo ""
    echo -e "${BLUE}=== Deployment Information ===${NC}"
    echo -e "Jetson Model: ${JETSON_MODEL}"
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
    echo -e "Monitor GPU: sudo tegrastats"
    echo -e "Check Jetson stats: sudo jetson_stats"
    echo -e "Set max performance: sudo nvpmodel -m 0 && sudo jetson_clocks"
    echo ""
    echo -e "${BLUE}=== Performance Monitoring ===${NC}"
    echo -e "CPU temperature: cat /sys/class/thermal/thermal_zone*/temp"
    echo -e "GPU temperature: cat /sys/devices/virtual/thermal/thermal_zone*/temp"
    echo -e "Memory usage: free -h"
    echo -e "Disk usage: df -h"
    echo ""
}

# Main deployment function
main() {
    log "Starting NVIDIA Jetson UI deployment..."
    
    get_service_user
    check_jetson
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
    optimize_jetson
    health_check
    show_info
    
    log "Deployment script completed successfully!"
}

# Handle script interruption
trap 'error "Deployment interrupted"' INT TERM

# Run main function
main "$@"