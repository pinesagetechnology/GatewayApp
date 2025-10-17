#!/bin/bash

# Interactive Kiosk Mode Setup Script
# Description: Helps users choose and set up the best kiosk mode for their needs
# Author: Senior Software Engineer
# Usage: bash setup-kiosk.sh

set -e  # Exit on any error

# Detect script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

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

info() {
    echo -e "${CYAN}$1${NC}"
}

header() {
    echo ""
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}════════════════════════════════════════════════════${NC}"
    echo ""
}

# Check system resources
check_system() {
    log "Checking system resources..."
    
    # Check available memory
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    info "Available RAM: ${TOTAL_MEM}MB"
    
    if [ "$TOTAL_MEM" -lt 1024 ]; then
        warn "Low memory detected. Chromium kiosk is recommended."
    fi
    
    # Check disk space
    DISK_SPACE=$(df -m / | awk 'NR==2 {print $4}')
    info "Available disk space: ${DISK_SPACE}MB"
    
    if [ "$DISK_SPACE" -lt 2048 ]; then
        warn "Low disk space. Consider freeing up space before continuing."
    fi
    
    # Check if app is deployed
    if ! curl -s http://localhost > /dev/null 2>&1; then
        warn "App not accessible at http://localhost"
        warn "You may need to deploy the app first using: bash scripts/rpi5-deploy.sh"
    else
        log "✓ App is accessible at http://localhost"
    fi
    
    echo ""
}

# Display main menu
show_menu() {
    header "Kiosk Mode Setup for Raspberry Pi"
    
    echo -e "${BOLD}Choose your kiosk mode:${NC}"
    echo ""
    echo -e "${GREEN}1)${NC} Chromium Kiosk Mode ${CYAN}(Recommended)${NC}"
    echo -e "   • Lightweight (~200MB RAM)"
    echo -e "   • Quick 5-minute setup"
    echo -e "   • Perfect for web apps"
    echo -e "   • Uses system browser"
    echo ""
    echo -e "${GREEN}2)${NC} Electron Kiosk Mode ${CYAN}(Advanced)${NC}"
    echo -e "   • Desktop app experience (~350MB RAM)"
    echo -e "   • 15-minute setup"
    echo -e "   • Full control & offline support"
    echo -e "   • Custom integrations possible"
    echo ""
    echo -e "${GREEN}3)${NC} Compare Options"
    echo ""
    echo -e "${GREEN}4)${NC} View System Requirements"
    echo ""
    echo -e "${GREEN}5)${NC} Deploy App First (if not deployed)"
    echo ""
    echo -e "${RED}0)${NC} Exit"
    echo ""
}

# Show comparison table
show_comparison() {
    header "Kiosk Mode Comparison"
    
    printf "${BOLD}%-25s %-25s %-25s${NC}\n" "Feature" "Chromium Kiosk" "Electron Kiosk"
    echo "────────────────────────────────────────────────────────────────────────────"
    printf "%-25s %-25s %-25s\n" "Setup Time" "~5 minutes" "~15 minutes"
    printf "%-25s %-25s %-25s\n" "RAM Usage" "~200MB" "~350MB"
    printf "%-25s %-25s %-25s\n" "CPU Usage" "Low" "Medium"
    printf "%-25s %-25s %-25s\n" "Boot Time" "Fast" "Moderate"
    printf "%-25s %-25s %-25s\n" "Offline Support" "No (needs nginx)" "Yes (native)"
    printf "%-25s %-25s %-25s\n" "DevTools" "Chrome DevTools" "Electron DevTools"
    printf "%-25s %-25s %-25s\n" "Updates" "Simple rebuild" "Rebuild + repackage"
    printf "%-25s %-25s %-25s\n" "Customization" "Limited" "Full control"
    printf "%-25s %-25s %-25s\n" "Touch Support" "Yes (browser)" "Yes (native)"
    printf "%-25s %-25s %-25s\n" "Best For" "Web apps" "Desktop apps"
    echo ""
    
    info "💡 Recommendation: Use Chromium for most use cases unless you need offline support or custom integrations."
    echo ""
}

# Show system requirements
show_requirements() {
    header "System Requirements"
    
    echo -e "${BOLD}Hardware:${NC}"
    echo "  • Raspberry Pi 3, 4, or 5 (or compatible ARM device)"
    echo "  • 2GB+ RAM recommended (1GB minimum for Chromium)"
    echo "  • 16GB+ SD card"
    echo "  • Monitor with HDMI connection"
    echo "  • Keyboard (for initial setup)"
    echo ""
    
    echo -e "${BOLD}Software:${NC}"
    echo "  • Raspberry Pi OS (Debian-based)"
    echo "  • Node.js 18+ (for Electron option)"
    echo "  • Internet connection (for initial setup)"
    echo ""
    
    echo -e "${BOLD}Prerequisites:${NC}"
    echo "  • App deployed and accessible at http://localhost"
    echo "  • SSH access configured (recommended)"
    echo "  • Static IP configured (recommended)"
    echo ""
}

# Deploy app
deploy_app() {
    header "Deploying Application"
    
    if [ ! -f "$SCRIPT_DIR/rpi5-deploy.sh" ]; then
        error "Deployment script not found: $SCRIPT_DIR/rpi5-deploy.sh"
    fi
    
    log "Starting app deployment..."
    bash "$SCRIPT_DIR/rpi5-deploy.sh"
    
    log "App deployment completed!"
    echo ""
    read -p "Press Enter to return to menu..."
}

# Setup Chromium kiosk
setup_chromium() {
    header "Setting Up Chromium Kiosk Mode"
    
    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Install Chromium browser and X11 dependencies"
    echo "  2. Configure automatic login"
    echo "  3. Create kiosk startup script"
    echo "  4. Set up systemd service"
    echo "  5. Disable screen blanking"
    echo "  6. Create watchdog for auto-recovery"
    echo ""
    echo -e "${RED}Note: This requires sudo privileges${NC}"
    echo ""
    
    read -p "Continue with Chromium kiosk setup? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ ! -f "$SCRIPT_DIR/kiosk-chromium-setup.sh" ]; then
            error "Chromium setup script not found: $SCRIPT_DIR/kiosk-chromium-setup.sh"
        fi
        
        log "Starting Chromium kiosk setup..."
        sudo bash "$SCRIPT_DIR/kiosk-chromium-setup.sh"
        
        echo ""
        log "✓ Chromium kiosk setup completed!"
        echo ""
        echo -e "${BOLD}${GREEN}Next Steps:${NC}"
        echo -e "  1. Reboot the system: ${CYAN}sudo reboot${NC}"
        echo -e "  2. The kiosk will start automatically after boot"
        echo -e "  3. For maintenance, SSH from another computer"
        echo ""
        echo -e "${BOLD}Useful Commands:${NC}"
        echo -e "  • Stop kiosk: ${CYAN}sudo systemctl stop kiosk.service${NC}"
        echo -e "  • View logs: ${CYAN}sudo journalctl -u kiosk.service -f${NC}"
        echo -e "  • Update app: ${CYAN}sudo /usr/local/bin/update-kiosk-app${NC}"
        echo ""
        
        read -p "Reboot now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Rebooting..."
            sudo reboot
        fi
    else
        info "Setup cancelled."
    fi
    
    echo ""
    read -p "Press Enter to return to menu..."
}

# Setup Electron kiosk
setup_electron() {
    header "Setting Up Electron Kiosk Mode"
    
    echo -e "${YELLOW}This will:${NC}"
    echo "  1. Install Electron and dependencies"
    echo "  2. Create Electron main process"
    echo "  3. Update package.json configuration"
    echo "  4. Create helper scripts"
    echo "  5. Set up systemd service"
    echo ""
    echo -e "${YELLOW}Note: This is a longer process (~15 minutes)${NC}"
    echo ""
    
    read -p "Continue with Electron kiosk setup? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ ! -f "$SCRIPT_DIR/kiosk-electron-setup.sh" ]; then
            error "Electron setup script not found: $SCRIPT_DIR/kiosk-electron-setup.sh"
        fi
        
        log "Starting Electron kiosk setup..."
        bash "$SCRIPT_DIR/kiosk-electron-setup.sh"
        
        echo ""
        log "Electron dependencies installed!"
        echo ""
        echo -e "${YELLOW}Would you like to build the Electron app now?${NC}"
        echo -e "(This may take 10-15 minutes on Raspberry Pi)"
        echo ""
        
        read -p "Build now? (y/n): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$PROJECT_ROOT"
            log "Building Electron application..."
            npm run electron:build
            
            echo ""
            log "✓ Electron app built successfully!"
        else
            warn "Build skipped. Run 'npm run electron:build' when ready."
        fi
        
        echo ""
        echo -e "${BOLD}${GREEN}Next Steps:${NC}"
        echo -e "  1. Configure autologin (if not done):"
        echo -e "     ${CYAN}sudo mkdir -p /etc/systemd/system/getty@tty1.service.d${NC}"
        echo -e "     ${CYAN}sudo nano /etc/systemd/system/getty@tty1.service.d/autologin.conf${NC}"
        echo -e "     (See KIOSK_QUICKSTART.md for details)"
        echo ""
        echo -e "  2. Reboot the system: ${CYAN}sudo reboot${NC}"
        echo ""
        echo -e "${BOLD}Useful Commands:${NC}"
        echo -e "  • Test in dev: ${CYAN}npm run electron:dev${NC}"
        echo -e "  • Start kiosk: ${CYAN}./start-electron-kiosk.sh${NC}"
        echo -e "  • Stop kiosk: ${CYAN}./exit-electron-kiosk.sh${NC}"
        echo -e "  • View logs: ${CYAN}sudo journalctl -u electron-kiosk.service -f${NC}"
        echo ""
    else
        info "Setup cancelled."
    fi
    
    echo ""
    read -p "Press Enter to return to menu..."
}

# Main loop
main() {
    while true; do
        clear
        check_system
        show_menu
        
        read -p "Enter your choice [0-5]: " choice
        
        case $choice in
            1)
                setup_chromium
                ;;
            2)
                setup_electron
                ;;
            3)
                clear
                show_comparison
                read -p "Press Enter to return to menu..."
                ;;
            4)
                clear
                show_requirements
                read -p "Press Enter to return to menu..."
                ;;
            5)
                clear
                deploy_app
                ;;
            0)
                log "Exiting setup wizard. Goodbye!"
                exit 0
                ;;
            *)
                error "Invalid option. Please choose 0-5."
                sleep 2
                ;;
        esac
    done
}

# Welcome message
clear
header "Welcome to Kiosk Mode Setup Wizard"
info "This wizard will help you set up your React app as a kiosk on Raspberry Pi."
info "You'll be guided through the process step by step."
echo ""
read -p "Press Enter to continue..."

# Run main menu
main

