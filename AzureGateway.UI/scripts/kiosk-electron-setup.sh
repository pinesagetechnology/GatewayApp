#!/bin/bash

# Electron Kiosk Mode Setup for Raspberry Pi
# Description: Packages the React app as an Electron kiosk application
# Author: Senior Software Engineer
# Usage: bash kiosk-electron-setup.sh

set -e  # Exit on any error

# Detect script location and change to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="react-ui-app"
KIOSK_USER="${SUDO_USER:-pi}"

# Logging functions
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

# Install Electron dependencies
install_electron_deps() {
    log "Installing Electron dependencies..."
    
    cd "$PROJECT_ROOT"
    
    # Add Electron packages
    npm install --save-dev electron electron-builder electron-is-dev
    
    log "Electron dependencies installed"
}

# Create Electron main process file
create_electron_main() {
    log "Creating Electron main process..."
    
    cat > "${PROJECT_ROOT}/electron.js" <<'EOF'
const { app, BrowserWindow } = require('electron');
const path = require('path');
const isDev = require('electron-is-dev');

let mainWindow;

function createWindow() {
  // Create the browser window in kiosk mode
  mainWindow = new BrowserWindow({
    fullscreen: true,
    kiosk: true,
    frame: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      enableRemoteModule: false,
      devTools: !isDev ? false : true,
    },
    backgroundColor: '#000000',
  });

  // Load the app
  const startUrl = isDev
    ? 'http://localhost:3000'
    : `file://${path.join(__dirname, 'dist/index.html')}`;
  
  mainWindow.loadURL(startUrl);

  // Disable menu bar
  mainWindow.setMenuBarVisibility(false);

  // Prevent new windows from opening
  mainWindow.webContents.setWindowOpenHandler(() => {
    return { action: 'deny' };
  });

  // Disable keyboard shortcuts that could exit the app
  mainWindow.webContents.on('before-input-event', (event, input) => {
    // Disable F11, Alt+F4, Ctrl+W, Ctrl+Q, etc.
    const blockedKeys = ['F11', 'F4', 'W', 'Q', 'R'];
    
    if (input.alt && input.key === 'F4') {
      event.preventDefault();
    }
    if (input.control && blockedKeys.includes(input.key.toUpperCase())) {
      event.preventDefault();
    }
    if (input.key === 'F11') {
      event.preventDefault();
    }
  });

  // Open DevTools in development mode
  if (isDev) {
    mainWindow.webContents.openDevTools({ mode: 'detach' });
  }

  // Reload on crash (resilience)
  mainWindow.webContents.on('crashed', () => {
    console.error('App crashed, reloading...');
    setTimeout(() => {
      mainWindow.reload();
    }, 1000);
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  // Prevent navigation away from the app
  mainWindow.webContents.on('will-navigate', (event, url) => {
    const appUrl = mainWindow.webContents.getURL();
    const appOrigin = new URL(appUrl).origin;
    const navOrigin = new URL(url).origin;
    
    // Allow navigation within the same origin only
    if (navOrigin !== appOrigin) {
      event.preventDefault();
    }
  });
}

// Disable hardware acceleration for better compatibility on Raspberry Pi
app.disableHardwareAcceleration();

// This method will be called when Electron has finished initialization
app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

// Quit when all windows are closed (except on macOS)
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// Prevent multiple instances
const gotTheLock = app.requestSingleInstanceLock();
if (!gotTheLock) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (mainWindow) {
      if (mainWindow.isMinimized()) mainWindow.restore();
      mainWindow.focus();
    }
  });
}

// Graceful shutdown
process.on('SIGTERM', () => {
  app.quit();
});

process.on('SIGINT', () => {
  app.quit();
});
EOF
    
    log "Electron main process created"
}

# Update package.json with Electron configuration
update_package_json() {
    log "Updating package.json..."
    
    cd "$PROJECT_ROOT"
    
    # Backup original package.json
    cp package.json package.json.backup
    
    # Use Node.js to update package.json
    node <<'NODEJS'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));

// Update main entry point
pkg.main = 'electron.js';

// Add Electron scripts
pkg.scripts = pkg.scripts || {};
pkg.scripts['electron:dev'] = 'concurrently "npm start" "wait-on http://localhost:3000 && electron ."';
pkg.scripts['electron:build'] = 'npm run build && electron-builder';
pkg.scripts['electron:start'] = 'electron .';

// Add Electron builder configuration
pkg.build = {
  appId: 'com.reactapp.kiosk',
  productName: 'React Kiosk App',
  directories: {
    output: 'electron-dist'
  },
  files: [
    'dist/**/*',
    'electron.js',
    'package.json'
  ],
  linux: {
    target: ['dir', 'tar.gz'],
    category: 'Utility',
    executableName: 'react-kiosk'
  }
};

fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
console.log('package.json updated successfully');
NODEJS
    
    # Install additional dev dependencies
    npm install --save-dev concurrently wait-on
    
    log "package.json updated"
}

# Build Electron app
build_electron_app() {
    log "Building Electron application..."
    
    cd "$PROJECT_ROOT"
    
    # Build React app first
    npm run build
    
    # Build Electron app
    npm run electron:build
    
    log "Electron application built successfully"
}

# Create systemd service for Electron app
create_systemd_service() {
    log "Creating systemd service..."
    
    if [[ $EUID -ne 0 ]]; then
        warn "Not running as root. Skipping systemd service creation."
        warn "Run the following command manually with sudo after this script completes:"
        warn "sudo bash ${SCRIPT_DIR}/install-electron-service.sh"
        return
    fi
    
    cat > /etc/systemd/system/electron-kiosk.service <<EOF
[Unit]
Description=Electron Kiosk Application
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${KIOSK_USER}
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/${KIOSK_USER}/.Xauthority
Environment=NODE_ENV=production
WorkingDirectory=${PROJECT_ROOT}
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/npm run electron:start
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable electron-kiosk.service
    
    log "Systemd service created and enabled"
}

# Create helper scripts
create_helper_scripts() {
    log "Creating helper scripts..."
    
    # Exit kiosk script
    cat > "${PROJECT_ROOT}/exit-electron-kiosk.sh" <<'EOF'
#!/bin/bash
sudo systemctl stop electron-kiosk.service
killall electron 2>/dev/null || true
echo "Electron kiosk stopped"
EOF
    chmod +x "${PROJECT_ROOT}/exit-electron-kiosk.sh"
    
    # Start kiosk script
    cat > "${PROJECT_ROOT}/start-electron-kiosk.sh" <<'EOF'
#!/bin/bash
sudo systemctl start electron-kiosk.service
echo "Electron kiosk started"
EOF
    chmod +x "${PROJECT_ROOT}/start-electron-kiosk.sh"
    
    # Restart kiosk script
    cat > "${PROJECT_ROOT}/restart-electron-kiosk.sh" <<'EOF'
#!/bin/bash
sudo systemctl restart electron-kiosk.service
echo "Electron kiosk restarted"
EOF
    chmod +x "${PROJECT_ROOT}/restart-electron-kiosk.sh"
    
    log "Helper scripts created"
}

# Display information
show_info() {
    log "Electron Kiosk setup completed!"
    echo ""
    echo -e "${BLUE}=== Electron Kiosk Information ===${NC}"
    echo -e "Project Directory: ${PROJECT_ROOT}"
    echo -e "Electron Build: ${PROJECT_ROOT}/electron-dist"
    echo -e "Main Process: ${PROJECT_ROOT}/electron.js"
    echo ""
    echo -e "${BLUE}=== Development Commands ===${NC}"
    echo -e "Run in dev mode: npm run electron:dev"
    echo -e "Build production: npm run electron:build"
    echo -e "Start app: npm run electron:start"
    echo ""
    echo -e "${BLUE}=== Production Commands ===${NC}"
    echo -e "Start kiosk: ./start-electron-kiosk.sh"
    echo -e "Stop kiosk: ./exit-electron-kiosk.sh"
    echo -e "Restart kiosk: ./restart-electron-kiosk.sh"
    echo -e "View logs: sudo journalctl -u electron-kiosk.service -f"
    echo ""
    echo -e "${BLUE}=== Next Steps ===${NC}"
    echo -e "1. Test in development: npm run electron:dev"
    echo -e "2. If running as non-root, manually install service:"
    echo -e "   sudo bash -c 'source ${SCRIPT_DIR}/kiosk-electron-setup.sh && create_systemd_service'"
    echo -e "3. Enable autostart (see kiosk-chromium-setup.sh for autologin setup)"
    echo -e "4. Reboot: sudo reboot"
    echo ""
}

# Main function
main() {
    log "Starting Electron Kiosk setup..."
    
    install_electron_deps
    create_electron_main
    update_package_json
    create_helper_scripts
    create_systemd_service
    show_info
    
    log "Setup completed!"
    echo ""
    echo -e "${YELLOW}To build the production Electron app, run: npm run electron:build${NC}"
}

# Handle script interruption
trap 'error "Setup interrupted"' INT TERM

# Run main function
main "$@"

