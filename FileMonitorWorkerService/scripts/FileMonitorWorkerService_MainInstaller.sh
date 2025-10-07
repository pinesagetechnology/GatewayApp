#!/usr/bin/env bash
# FileMonitorWorkerService - Main Installation Script for Linux

set -e

# Default values
INSTALL_PATH="/opt/filemonitor"
DATA_PATH=""
SOURCE_PATH=""
SKIP_VALIDATION=false
VERBOSE=false
INTERACTIVE=true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-path)
            INSTALL_PATH="$2"
            shift 2
            ;;
        --data-path)
            DATA_PATH="$2"
            shift 2
            ;;
        --source-path)
            SOURCE_PATH="$2"
            shift 2
            ;;
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --non-interactive)
            INTERACTIVE=false
            shift
            ;;
        -h|--help)
            echo "FileMonitorWorkerService - Main Installation Script for Linux"
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --install-path PATH    Installation directory (default: /opt/filemonitor)"
            echo "  --data-path PATH       Data directory (will prompt if not specified)"
            echo "  --source-path PATH     Path to published application files"
            echo "  --skip-validation     Skip post-installation validation"
            echo "  --verbose             Verbose output"
            echo "  --non-interactive     Skip user prompts (requires --data-path)"
            echo "  -h, --help            Show this help"
            echo ""
            echo "Note: .NET must be installed separately before running this script"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠ ${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_step() { echo -e "${BLUE}==>${NC} $1"; }

# Function to update configuration files in the install path
update_config_files() {
    log_step "Updating configuration files..."

    local config_file="$INSTALL_PATH/appsettings.json"

    if [ -f "$config_file" ]; then
        log_info "Updating $config_file"

        # Create backup
        cp "$config_file" "$config_file.backup" || true

        # Normalize CRLF just in case
        sed -i 's/\r$//' "$config_file" || true

        # Update database path
        sed -i "s|\"Data Source=.*\"|\"Data Source=$DATA_PATH/database/filemonitor.db\"|g" "$config_file" || true

        log_info "Updated $config_file"
    fi
}

# Function to prompt for data path
prompt_data_path() {
    if [ -n "$DATA_PATH" ]; then
        log_info "Using specified data path: $DATA_PATH"
        return 0
    fi

    if [ "$INTERACTIVE" = false ]; then
        log_error "Data path must be specified when using --non-interactive mode"
        exit 1
    fi

    echo ""
    echo -e "${BLUE}=== Data Directory Configuration ===${NC}"
    echo "The data directory will store:"
    echo "  - Database files (SQLite)"
    echo "  - Application logs"
    echo "  - Configuration files"
    echo "  - Temporary files"
    echo ""
    echo "Recommended locations:"
    echo "  - /var/filemonitor (system-wide, requires root)"
    echo "  - /home/\$USER/filemonitor (user-specific)"
    echo "  - /opt/filemonitor/data (alongside application)"
    echo ""

    while true; do
        read -p "Enter the data directory path: " DATA_PATH
        
        if [ -z "$DATA_PATH" ]; then
            log_error "Data path cannot be empty"
            continue
        fi

        # Expand tilde and make absolute
        DATA_PATH=$(eval echo "$DATA_PATH")
        if command -v realpath >/dev/null 2>&1; then
            DATA_PATH=$(realpath -m "$DATA_PATH")
        fi

        # Validate path
        if [[ "$DATA_PATH" =~ ^/ ]]; then
            log_info "Using data path: $DATA_PATH"
            break
        else
            log_error "Please provide an absolute path (starting with /)"
        fi
    done
}

# Function to verify .NET is installed
verify_dotnet() {
    log_step "Verifying .NET installation..."
    
    if ! command -v dotnet &> /dev/null; then
        log_error ".NET is not installed"
        log_error "Please install .NET 8 runtime/SDK before running this script"
        exit 1
    fi

    if ! dotnet --list-runtimes | grep -q "Microsoft.AspNetCore.App 8"; then
        log_error ".NET 8 runtime not found"
        log_error "Please install .NET 8 runtime/SDK before running this script"
        exit 1
    fi

    log_info ".NET 8 is installed"
}

echo -e "${GREEN}=== FileMonitorWorkerService Linux Installation ===${NC}"
echo "This script will install FileMonitorWorkerService on your Linux system"
echo ""
echo "Configuration:"
echo "  Install Path: $INSTALL_PATH"
echo "  Source Path: ${SOURCE_PATH:-'Auto-detect next to this script'}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Verify .NET is installed
verify_dotnet

# Prompt for data path if not specified
prompt_data_path
echo "  Data Path: $DATA_PATH"
echo ""

# Step 1: Run prerequisites installation (without .NET)
log_step "Step 1: Installing prerequisites and setting up environment"
# Normalize potential CRLF in FileMonitorWorkerService_Linux_Installation.sh to avoid shebang issues
if [ -f "FileMonitorWorkerService_Linux_Installation.sh" ]; then
    sed -i 's/\r$//' FileMonitorWorkerService_Linux_Installation.sh || true
    chmod +x FileMonitorWorkerService_Linux_Installation.sh || true
fi

bash FileMonitorWorkerService_Linux_Installation.sh --install-path "$INSTALL_PATH" --data-path "$DATA_PATH"

if [ $? -ne 0 ]; then
    log_error "Prerequisites installation failed"
    exit 1
fi

log_info "Prerequisites installation completed"

# Step 2: Auto-detect source path relative to this script when not supplied, then deploy
if [ -z "$SOURCE_PATH" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ -d "$SCRIPT_DIR/FileMonitorWorkerService" ]; then
        SOURCE_PATH="$SCRIPT_DIR/FileMonitorWorkerService"
    else
        SOURCE_PATH="$SCRIPT_DIR"
    fi
fi

# Normalize source path (expand ~ and make absolute)
SOURCE_PATH=$(eval echo "$SOURCE_PATH")
if command -v realpath >/dev/null 2>&1; then
    SOURCE_PATH=$(realpath -m "$SOURCE_PATH")
fi

if [ -n "$SOURCE_PATH" ]; then
    log_step "Step 2: Deploying application files"
    if [ ! -d "$SOURCE_PATH" ]; then
        log_error "Source path not found: $SOURCE_PATH"
        exit 1
    fi

    SRC_FOR_COPY="$SOURCE_PATH"

    if [ ! -f "$SOURCE_PATH/FileMonitorWorkerService.dll" ]; then
        log_step "Publish output not found. Attempting to build and publish the project."

        # Try to locate the project file
        PROJECT_PATH=""
        if [ -f "$SOURCE_PATH/FileMonitorWorkerService.csproj" ]; then
            PROJECT_PATH="$SOURCE_PATH/FileMonitorWorkerService.csproj"
        elif [ -f "$SOURCE_PATH/FileMonitorWorkerService/FileMonitorWorkerService.csproj" ]; then
            PROJECT_PATH="$SOURCE_PATH/FileMonitorWorkerService/FileMonitorWorkerService.csproj"
        else
            # Fallback: first csproj under the directory
            PROJECT_PATH=$(find "$SOURCE_PATH" -maxdepth 2 -type f -name "*.csproj" | head -n 1)
        fi

        if [ -z "$PROJECT_PATH" ]; then
            log_error "Could not find a .csproj under: $SOURCE_PATH"
            exit 1
        fi

        # Ensure dotnet CLI is available (SDK should already be installed)
        if ! command -v dotnet >/dev/null 2>&1; then
            log_error "dotnet CLI not found. Please install .NET 8 SDK."
            exit 1
        fi
        
        if ! dotnet --list-sdks 2>/dev/null | grep -q "^8\."; then
            log_error ".NET 8 SDK not found. Please install .NET 8 SDK to build the project."
            exit 1
        fi

        PUBLISH_DIR="$DATA_PATH/temp/publish-$(date +%s)"
        mkdir -p "$PUBLISH_DIR"
        log_step "Publishing project: $PROJECT_PATH -> $PUBLISH_DIR"
        if ! dotnet publish "$PROJECT_PATH" -c Release -o "$PUBLISH_DIR"; then
            log_error "dotnet publish failed"
            exit 1
        fi

        if [ ! -f "$PUBLISH_DIR/FileMonitorWorkerService.dll" ]; then
            log_error "Publish succeeded but FileMonitorWorkerService.dll not found in: $PUBLISH_DIR"
            exit 1
        fi

        SRC_FOR_COPY="$PUBLISH_DIR"
        log_info "Publish completed. Using published output for deployment."
    fi

    cp -r "$SRC_FOR_COPY"/* "$INSTALL_PATH/"
    chown -R filemonitor:filemonitor "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"/*.dll || true
    log_info "Application files deployed"

    # Update configuration files with chosen data path
    update_config_files

    # Step 2b: Ensure systemd service exists after deployment
    SERVICE_NAME="filemonitor"
    if [ ! -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        log_step "Creating systemd service..."
        cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=FileMonitorWorkerService - File Monitoring and Azure Upload Service
After=network.target

[Service]
Type=simple
TimeoutStartSec=120
TimeoutStopSec=30
User=filemonitor
Group=filemonitor
WorkingDirectory=$INSTALL_PATH
ExecStart=/usr/bin/dotnet $INSTALL_PATH/FileMonitorWorkerService.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=$SERVICE_NAME
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
Environment=ASPNETCORE_ENVIRONMENT=Production

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=false
ReadWritePaths=$INSTALL_PATH $DATA_PATH
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable "$SERVICE_NAME" || true
        log_info "Systemd service created and enabled"
    else
        log_step "Systemd service already exists"
        systemctl daemon-reload
    fi
else
    log_step "Step 2: Application deployment skipped"
    log_warn "No source path provided. You need to manually deploy the application:"
    echo "  1. Publish: dotnet publish -c Release -o publish"
    echo "  2. Copy: sudo cp -r publish/* \"$INSTALL_PATH/\""
    echo "  3. Set ownership: sudo chown -R filemonitor:filemonitor \"$INSTALL_PATH\""
fi

# Step 3: Validation
if [ "$SKIP_VALIDATION" = false ]; then
    log_step "Step 3: Validating installation"
    cat > /tmp/validate-config.sh << 'EOF'
#!/bin/bash
INSTALL_PATH="$1"
DATA_PATH="$2"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠ ${NC} $1"; }

errors=0

# Check .NET
if command -v dotnet &> /dev/null && dotnet --list-runtimes | grep -q "Microsoft.AspNetCore.App 8"; then
    log_success ".NET 8 is installed"
else
    log_error ".NET 8 not found"
    ((errors++))
fi

# Check directories
for dir in "$INSTALL_PATH" "$DATA_PATH" "$DATA_PATH/database" "$DATA_PATH/logs" "$DATA_PATH/config"; do
    if [ -d "$dir" ]; then
        log_success "Directory exists: $dir"
    else
        log_error "Directory missing: $dir"
        ((errors++))
    fi
done

# Check application
if [ -f "$INSTALL_PATH/FileMonitorWorkerService.dll" ]; then
    log_success "Application files found"
else
    log_warn "Application files not found (manual deployment needed)"
fi

# Check service
if systemctl is-enabled filemonitor &>/dev/null; then
    log_success "Service is configured"
else
    log_error "Service not configured"
    ((errors++))
fi

exit $errors
EOF
    chmod +x /tmp/validate-config.sh
    if /tmp/validate-config.sh "$INSTALL_PATH" "$DATA_PATH"; then
        log_info "Validation passed"
    else
        log_warn "Validation found issues - please review and fix"
    fi
    rm /tmp/validate-config.sh
else
    log_step "Step 3: Validation skipped"
fi

# Final instructions
echo ""
echo -e "${GREEN}=== Installation Summary ===${NC}"
echo "Install Path: $INSTALL_PATH"
echo "Data Path: $DATA_PATH"
echo "Service: filemonitor"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
if [ -f "$INSTALL_PATH/FileMonitorWorkerService.dll" ]; then
    echo "1. Configure Azure Storage connection in: $INSTALL_PATH/appsettings.json"
    echo "2. Add data source configurations for folder monitoring"
    echo "3. Start the service: sudo systemctl start filemonitor"
    echo "4. Enable auto-start: sudo systemctl enable filemonitor"
    echo "5. Check status: sudo systemctl status filemonitor"
    echo "6. View logs: sudo journalctl -u filemonitor -f"
else
    echo "1. Deploy application files to: $INSTALL_PATH"
    echo "2. Configure Azure Storage connection"
    echo "3. Add data source configurations"
    echo "4. Start the service"
fi

echo ""
echo "For detailed instructions: $INSTALL_PATH/DEPLOYMENT_GUIDE.txt"