#!/bin/bash

# .NET Core SDK Installation Script for Multiple Architectures
# Supports: x86_64, ARM64 (Jetson/RPi 64-bit), ARM (Raspberry Pi 32-bit)

set -e

# Configuration
DOTNET_VERSION="8.0"  # Change this to your desired version (6.0, 7.0, 8.0, etc.)
INSTALL_DIR="/usr/share/dotnet"
SYMLINK_DIR="/usr/bin"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to detect architecture
detect_architecture() {
    local arch=$(uname -m)
    local os_info=$(cat /etc/os-release 2>/dev/null || echo "")
    
    print_info "Detected machine architecture: $arch"
    
    case $arch in
        x86_64)
            ARCH_TYPE="x64"
            DOWNLOAD_ARCH="x64"
            ;;
        aarch64|arm64)
            ARCH_TYPE="arm64"
            DOWNLOAD_ARCH="arm64"
            # Check if it's Jetson
            if echo "$os_info" | grep -qi "jetson\|tegra"; then
                print_info "Detected NVIDIA Jetson device"
            fi
            ;;
        armv7l|armv6l)
            ARCH_TYPE="arm"
            DOWNLOAD_ARCH="arm"
            # Check if it's Raspberry Pi
            if [ -f /proc/device-tree/model ]; then
                MODEL=$(cat /proc/device-tree/model)
                print_info "Detected device: $MODEL"
            fi
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    
    print_info "Will install .NET for architecture: $ARCH_TYPE"
}

# Function to check if .NET is already installed
check_existing_dotnet() {
    if command -v dotnet &> /dev/null; then
        CURRENT_VERSION=$(dotnet --version 2>/dev/null || echo "unknown")
        print_warn ".NET SDK is already installed (version: $CURRENT_VERSION)"
        read -p "Do you want to continue with installation? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled"
            exit 0
        fi
    fi
}

# Function to install dependencies
install_dependencies() {
    print_info "Installing dependencies..."
    
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y wget curl libicu-dev libssl-dev
    elif command -v yum &> /dev/null; then
        sudo yum install -y wget curl libicu openssl-libs
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y wget curl libicu openssl-libs
    else
        print_warn "Could not detect package manager. Please install wget, curl, libicu, and openssl manually"
    fi
}

# Function to download and install .NET SDK
install_dotnet() {
    print_info "Starting .NET SDK installation..."
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Construct download URL
    DOWNLOAD_URL="https://dotnet.microsoft.com/download/dotnet/${DOTNET_VERSION}"
    
    print_info "Downloading .NET ${DOTNET_VERSION} SDK for ${ARCH_TYPE}..."
    
    # Use official installation script
    wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
    chmod +x dotnet-install.sh
    
    # Install with specific architecture
    print_info "Running installation script..."
    sudo ./dotnet-install.sh --channel ${DOTNET_VERSION} --architecture ${DOWNLOAD_ARCH} --install-dir ${INSTALL_DIR}
    
    # Clean up
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
}

# Function to configure environment
configure_environment() {
    print_info "Configuring environment..."
    
    # Create symbolic link
    if [ ! -f "${SYMLINK_DIR}/dotnet" ]; then
        sudo ln -s ${INSTALL_DIR}/dotnet ${SYMLINK_DIR}/dotnet
        print_info "Created symbolic link in ${SYMLINK_DIR}"
    fi
    
    # Add to PATH if not already present
    PROFILE_FILE="$HOME/.bashrc"
    if [ -f "$HOME/.zshrc" ]; then
        PROFILE_FILE="$HOME/.zshrc"
    fi
    
    if ! grep -q "DOTNET_ROOT" "$PROFILE_FILE"; then
        echo "" >> "$PROFILE_FILE"
        echo "# .NET Core Configuration" >> "$PROFILE_FILE"
        echo "export DOTNET_ROOT=${INSTALL_DIR}" >> "$PROFILE_FILE"
        echo "export PATH=\$PATH:\$DOTNET_ROOT:\$DOTNET_ROOT/tools" >> "$PROFILE_FILE"
        print_info "Added .NET to PATH in $PROFILE_FILE"
    fi
    
    # Export for current session
    export DOTNET_ROOT=${INSTALL_DIR}
    export PATH=$PATH:$DOTNET_ROOT:$DOTNET_ROOT/tools
}

# Function to verify installation
verify_installation() {
    print_info "Verifying installation..."
    
    if ${INSTALL_DIR}/dotnet --version &> /dev/null; then
        VERSION=$(${INSTALL_DIR}/dotnet --version)
        print_info "✓ .NET SDK successfully installed!"
        print_info "✓ Version: $VERSION"
        print_info "✓ Architecture: $ARCH_TYPE"
        
        # Show SDK list
        print_info "Installed SDKs:"
        ${INSTALL_DIR}/dotnet --list-sdks
    else
        print_error "Installation verification failed"
        exit 1
    fi
}

# Function for ARM64 specific optimizations (Jetson/RPi 4)
arm64_optimizations() {
    if [ "$ARCH_TYPE" = "arm64" ]; then
        print_info "Applying ARM64 optimizations..."
        
        # Set environment variables for better ARM64 performance
        ENV_FILE="/etc/environment"
        
        if ! grep -q "DOTNET_EnableWriteXorExecute" "$ENV_FILE" 2>/dev/null; then
            echo "DOTNET_EnableWriteXorExecute=0" | sudo tee -a "$ENV_FILE" > /dev/null
        fi
        
        if ! grep -q "DOTNET_TieredPGO" "$ENV_FILE" 2>/dev/null; then
            echo "DOTNET_TieredPGO=1" | sudo tee -a "$ENV_FILE" > /dev/null
        fi
        
        print_info "ARM64 optimizations applied"
    fi
}

# Main execution
main() {
    print_info "=== .NET Core SDK Installation Script ==="
    print_info "Target .NET Version: ${DOTNET_VERSION}"
    echo
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_warn "Please do not run this script as root. It will use sudo when needed."
        exit 1
    fi
    
    detect_architecture
    check_existing_dotnet
    install_dependencies
    install_dotnet
    configure_environment
    arm64_optimizations
    verify_installation
    
    echo
    print_info "=== Installation Complete ==="
    print_info "Please run: source ~/.bashrc (or restart your terminal)"
    print_info "Then verify by running: dotnet --version"
}

# Run main function
main