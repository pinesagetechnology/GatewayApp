#!/usr/bin/env bash

# Build and Package Script for MonitoringServiceAPI
# This script builds the application and creates distribution packages

set -e

# Configuration
PROJECT_NAME="MonitoringServiceAPI"
PROJECT_FILE="MonitoringServiceAPI.csproj"
BUILD_CONFIG="Release"
OUTPUT_DIR="dist"
PACKAGE_DIR="packages"
VERSION=""
SKIP_TESTS=false
SKIP_PACKAGING=false
VERBOSE=false
CLEAN_BUILD=false

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
    --version) VERSION="$2"; shift 2;;
    --output-dir) OUTPUT_DIR="$2"; shift 2;;
    --package-dir) PACKAGE_DIR="$2"; shift 2;;
    --skip-tests) SKIP_TESTS=true; shift;;
    --skip-packaging) SKIP_PACKAGING=true; shift;;
    --clean-build) CLEAN_BUILD=true; shift;;
    --verbose) VERBOSE=true; shift;;
    -h|--help)
      echo "MonitoringServiceAPI Build Script"
      echo ""
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Build Options:"
      echo "  --version VERSION        Set version for packages (default: auto-detect)"
      echo "  --output-dir DIR         Output directory for builds (default: dist)"
      echo "  --package-dir DIR        Package directory (default: packages)"
      echo "  --skip-tests             Skip running tests"
      echo "  --skip-packaging         Skip creating packages"
      echo "  --clean-build            Clean before building"
      echo "  --verbose                Enable verbose output"
      echo "  -h, --help              Show this help"
      echo ""
      echo "Examples:"
      echo "  $0 --version 1.0.0"
      echo "  $0 --clean-build --skip-tests"
      exit 0;;
    *) echo "Unknown option: $1"; exit 1;;
  esac
done

# Check if we're in the right directory
check_project() {
  if [ ! -f "$PROJECT_FILE" ]; then
    err "Project file not found: $PROJECT_FILE"
    err "Please run this script from the MonitoringServiceAPI project root directory"
    exit 1
  fi
}

# Get version from project file if not specified
get_version() {
  if [ -z "$VERSION" ]; then
    VERSION=$(grep -oP '<Version>\K[^<]+' "$PROJECT_FILE" 2>/dev/null || echo "1.0.0")
    info "Auto-detected version: $VERSION"
  else
    log "Using specified version: $VERSION"
  fi
}

# Clean previous builds
clean_build() {
  if [ "$CLEAN_BUILD" = true ]; then
    step "Cleaning previous builds..."
    rm -rf "$OUTPUT_DIR" "$PACKAGE_DIR" "bin" "obj"
    log "Clean completed"
  fi
}

# Restore dependencies
restore_dependencies() {
  step "Restoring NuGet packages..."
  if [ "$VERBOSE" = true ]; then
    dotnet restore --verbosity normal
  else
    dotnet restore --verbosity minimal
  fi
  log "Dependencies restored"
}

# Build the project
build_project() {
  step "Building project..."
  
  local build_args="-c $BUILD_CONFIG"
  if [ "$VERBOSE" = true ]; then
    build_args="$build_args --verbosity normal"
  else
    build_args="$build_args --verbosity minimal"
  fi
  
  dotnet build $build_args
  log "Build completed"
}

# Run tests
run_tests() {
  if [ "$SKIP_TESTS" = true ]; then
    warn "Skipping tests"
    return
  fi
  
  step "Running tests..."
  
  local test_args="-c $BUILD_CONFIG --no-build"
  if [ "$VERBOSE" = true ]; then
    test_args="$test_args --verbosity normal"
  else
    test_args="$test_args --verbosity minimal"
  fi
  
  if dotnet test $test_args; then
    log "All tests passed"
  else
    err "Tests failed"
    exit 1
  fi
}

# Publish for different platforms
publish_application() {
  step "Publishing application..."
  
  local publish_args="-c $BUILD_CONFIG --no-build"
  if [ "$VERBOSE" = true ]; then
    publish_args="$publish_args --verbosity normal"
  else
    publish_args="$publish_args --verbosity minimal"
  fi
  
  # Create output directory
  mkdir -p "$OUTPUT_DIR"
  
  # Publish for Linux x64
  info "Publishing for Linux x64..."
  dotnet publish $publish_args -o "$OUTPUT_DIR/linux-x64" -r linux-x64 --self-contained false
  
  # Publish for Windows x64
  info "Publishing for Windows x64..."
  dotnet publish $publish_args -o "$OUTPUT_DIR/win-x64" -r win-x64 --self-contained false
  
  # Publish for macOS x64
  info "Publishing for macOS x64..."
  dotnet publish $publish_args -o "$OUTPUT_DIR/osx-x64" -r osx-x64 --self-contained false
  
  # Create a portable version
  info "Creating portable version..."
  dotnet publish $publish_args -o "$OUTPUT_DIR/portable"
  
  log "Publishing completed"
}

# Create packages
create_packages() {
  if [ "$SKIP_PACKAGING" = true ]; then
    warn "Skipping package creation"
    return
  fi
  
  step "Creating distribution packages..."
  
  mkdir -p "$PACKAGE_DIR"
  
  # Create Linux package
  info "Creating Linux package..."
  cd "$OUTPUT_DIR/linux-x64"
  tar -czf "../../$PACKAGE_DIR/MonitoringServiceAPI-linux-x64-$VERSION.tar.gz" .
  cd ../..
  
  # Create Windows package
  info "Creating Windows package..."
  cd "$OUTPUT_DIR/win-x64"
  zip -r "../../$PACKAGE_DIR/MonitoringServiceAPI-windows-x64-$VERSION.zip" .
  cd ../..
  
  # Create macOS package
  info "Creating macOS package..."
  cd "$OUTPUT_DIR/osx-x64"
  tar -czf "../../$PACKAGE_DIR/MonitoringServiceAPI-macos-x64-$VERSION.tar.gz" .
  cd ../..
  
  # Create portable package
  info "Creating portable package..."
  cd "$OUTPUT_DIR/portable"
  zip -r "../../$PACKAGE_DIR/MonitoringServiceAPI-portable-$VERSION.zip" .
  cd ../..
  
  log "Packages created in $PACKAGE_DIR/"
}

# Create installation packages
create_installation_packages() {
  step "Creating installation packages..."
  
  # Create a comprehensive package with installers
  local installer_dir="$PACKAGE_DIR/installer-package-$VERSION"
  mkdir -p "$installer_dir"
  
  # Copy application files
  cp -r "$OUTPUT_DIR/linux-x64" "$installer_dir/MonitoringServiceAPI"
  
  # Copy installation scripts
  cp "scripts/MonitoringServiceAPI_MainInstaller.sh" "$installer_dir/"
  cp "scripts/MonitoringServiceAPI_Linux_Installation.sh" "$installer_dir/"
  
  # Create a simple install script
  cat > "$installer_dir/install.sh" <<EOF
#!/usr/bin/env bash
# Simple installer wrapper

echo "MonitoringServiceAPI Installation"
echo "================================"
echo ""
echo "Choose installation method:"
echo "1. Full installer (recommended)"
echo "2. Basic installer"
echo "3. Manual installation"
echo ""
read -p "Enter choice (1-3): " choice

case \$choice in
  1)
    sudo bash MonitoringServiceAPI_MainInstaller.sh --source-path . --interactive
    ;;
  2)
    sudo cp -r MonitoringServiceAPI /opt/monitoringapi
    sudo bash MonitoringServiceAPI_Linux_Installation.sh --non-interactive --data-path /var/monitoringapi
    ;;
  3)
    echo "Manual installation:"
    echo "1. Copy MonitoringServiceAPI to /opt/monitoringapi"
    echo "2. Run the appropriate installer script"
    echo "3. Configure your data directory"
    ;;
  *)
    echo "Invalid choice"
    exit 1
    ;;
esac
EOF
  
  chmod +x "$installer_dir/install.sh"
  
  # Create README for installer package
  cat > "$installer_dir/README.md" <<EOF
# MonitoringServiceAPI Installation Package

## Quick Start

Run the installer:
\`\`\`bash
sudo bash install.sh
\`\`\`

## Manual Installation

1. **Full Installation (Recommended):**
   \`\`\`bash
   sudo bash MonitoringServiceAPI_MainInstaller.sh --source-path . --data-path /var/monitoringapi
   \`\`\`

2. **Basic Installation:**
   \`\`\`bash
   sudo cp -r MonitoringServiceAPI /opt/monitoringapi
   sudo bash MonitoringServiceAPI_Linux_Installation.sh --non-interactive --data-path /var/monitoringapi
   \`\`\`

## Requirements

- Linux system (Ubuntu/Debian/CentOS/RHEL)
- .NET 8 Runtime
- Nginx (optional, for reverse proxy)
- Root/sudo access

## Configuration

After installation:
- Service will be available at http://localhost:5000
- Health check: http://localhost/health
- API documentation: http://localhost/swagger
- Data directory: /var/monitoringapi (configurable)

## Management

- Start: \`sudo systemctl start monitoringapi\`
- Stop: \`sudo systemctl stop monitoringapi\`
- Status: \`sudo systemctl status monitoringapi\`
- Logs: \`sudo journalctl -u monitoringapi -f\`

## Support

For issues and support, please refer to the project documentation.
EOF
  
  # Create final installer package
  cd "$PACKAGE_DIR"
  tar -czf "MonitoringServiceAPI-installer-$VERSION.tar.gz" "installer-package-$VERSION"
  rm -rf "installer-package-$VERSION"
  cd ..
  
  log "Installation packages created"
}

# Generate checksums
generate_checksums() {
  step "Generating checksums..."
  
  cd "$PACKAGE_DIR"
  find . -name "*.tar.gz" -o -name "*.zip" | while read -r file; do
    sha256sum "$file" >> "checksums.txt"
  done
  cd ..
  
  log "Checksums generated: $PACKAGE_DIR/checksums.txt"
}

# Display build summary
show_summary() {
  echo ""
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}    Build Summary${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  echo "Version: $VERSION"
  echo "Build Configuration: $BUILD_CONFIG"
  echo ""
  echo "Output Directory: $OUTPUT_DIR"
  echo "Package Directory: $PACKAGE_DIR"
  echo ""
  echo "Created Packages:"
  if [ -d "$PACKAGE_DIR" ]; then
    ls -la "$PACKAGE_DIR"/*.tar.gz "$PACKAGE_DIR"/*.zip 2>/dev/null | while read -r line; do
      echo "  $line"
    done
  fi
  echo ""
  echo "Next Steps:"
  echo "1. Test the packages on target systems"
  echo "2. Upload to release repository"
  echo "3. Update installation documentation"
  echo ""
}

# Main function
main() {
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}    MonitoringServiceAPI Build Script${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo ""
  
  # Validation and setup
  check_project
  get_version
  clean_build
  
  # Build process
  restore_dependencies
  build_project
  run_tests
  publish_application
  create_packages
  create_installation_packages
  generate_checksums
  
  # Summary
  show_summary
}

# Run main function
main "$@"
