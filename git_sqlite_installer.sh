#!/bin/bash

# Git and SQLite Installation Script
# Supports: Ubuntu/Debian, RHEL/CentOS/Fedora, and other Linux distributions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to detect package manager
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
        print_info "Detected package manager: APT (Debian/Ubuntu)"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        print_info "Detected package manager: DNF (Fedora/RHEL 8+)"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        print_info "Detected package manager: YUM (CentOS/RHEL)"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        print_info "Detected package manager: Pacman (Arch Linux)"
    elif command -v zypper &> /dev/null; then
        PKG_MANAGER="zypper"
        print_info "Detected package manager: Zypper (openSUSE)"
    else
        print_error "Could not detect package manager"
        exit 1
    fi
}

# Function to check if running with proper privileges
check_privileges() {
    if [ "$EUID" -eq 0 ]; then
        print_warn "Running as root. This is okay, but not required."
        SUDO=""
    else
        if ! command -v sudo &> /dev/null; then
            print_error "sudo is not available. Please run as root or install sudo."
            exit 1
        fi
        SUDO="sudo"
    fi
}

# Function to update package repositories
update_repositories() {
    print_step "Updating package repositories..."
    
    case $PKG_MANAGER in
        apt)
            $SUDO apt-get update
            ;;
        dnf)
            $SUDO dnf check-update || true
            ;;
        yum)
            $SUDO yum check-update || true
            ;;
        pacman)
            $SUDO pacman -Sy
            ;;
        zypper)
            $SUDO zypper refresh
            ;;
    esac
    
    print_info "Repository update complete"
}

# Function to check if Git is installed
check_git() {
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version | cut -d' ' -f3)
        print_info "Git is already installed (version: $GIT_VERSION)"
        return 0
    else
        print_info "Git is not installed"
        return 1
    fi
}

# Function to install Git
install_git() {
    print_step "Installing Git..."
    
    case $PKG_MANAGER in
        apt)
            $SUDO apt-get install -y git
            ;;
        dnf)
            $SUDO dnf install -y git
            ;;
        yum)
            $SUDO yum install -y git
            ;;
        pacman)
            $SUDO pacman -S --noconfirm git
            ;;
        zypper)
            $SUDO zypper install -y git
            ;;
    esac
    
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version)
        print_info "✓ Git installed successfully: $GIT_VERSION"
    else
        print_error "Git installation failed"
        exit 1
    fi
}

# Function to configure Git (optional)
configure_git() {
    if command -v git &> /dev/null; then
        print_step "Git Configuration (optional)"
        
        # Check if git is already configured
        if git config --global user.name &> /dev/null; then
            CURRENT_NAME=$(git config --global user.name)
            CURRENT_EMAIL=$(git config --global user.email)
            print_info "Git is already configured:"
            print_info "  Name: $CURRENT_NAME"
            print_info "  Email: $CURRENT_EMAIL"
            
            read -p "Do you want to reconfigure? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                return
            fi
        fi
        
        read -p "Configure Git now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter your name: " GIT_NAME
            read -p "Enter your email: " GIT_EMAIL
            
            git config --global user.name "$GIT_NAME"
            git config --global user.email "$GIT_EMAIL"
            
            # Set default branch name to main
            git config --global init.defaultBranch main
            
            print_info "✓ Git configured successfully"
            print_info "  Name: $GIT_NAME"
            print_info "  Email: $GIT_EMAIL"
        fi
    fi
}

# Function to check if SQLite is installed
check_sqlite() {
    if command -v sqlite3 &> /dev/null; then
        SQLITE_VERSION=$(sqlite3 --version | cut -d' ' -f1)
        print_info "SQLite is already installed (version: $SQLITE_VERSION)"
        return 0
    else
        print_info "SQLite is not installed"
        return 1
    fi
}

# Function to install SQLite
install_sqlite() {
    print_step "Installing SQLite..."
    
    case $PKG_MANAGER in
        apt)
            $SUDO apt-get install -y sqlite3 libsqlite3-dev
            ;;
        dnf)
            $SUDO dnf install -y sqlite sqlite-devel
            ;;
        yum)
            $SUDO yum install -y sqlite sqlite-devel
            ;;
        pacman)
            $SUDO pacman -S --noconfirm sqlite
            ;;
        zypper)
            $SUDO zypper install -y sqlite3 sqlite3-devel
            ;;
    esac
    
    if command -v sqlite3 &> /dev/null; then
        SQLITE_VERSION=$(sqlite3 --version)
        print_info "✓ SQLite installed successfully: $SQLITE_VERSION"
    else
        print_error "SQLite installation failed"
        exit 1
    fi
}

# Function to verify installations
verify_installations() {
    print_step "Verifying installations..."
    echo
    
    if command -v git &> /dev/null; then
        echo -e "${GREEN}✓ Git:${NC}"
        git --version
        echo "  Location: $(which git)"
    else
        echo -e "${RED}✗ Git: Not found${NC}"
    fi
    
    echo
    
    if command -v sqlite3 &> /dev/null; then
        echo -e "${GREEN}✓ SQLite:${NC}"
        sqlite3 --version
        echo "  Location: $(which sqlite3)"
    else
        echo -e "${RED}✗ SQLite: Not found${NC}"
    fi
}

# Function to show usage information
show_usage() {
    print_info "Post-installation usage:"
    echo
    echo "Git commands:"
    echo "  git --version                  # Check Git version"
    echo "  git clone <repository-url>     # Clone a repository"
    echo "  git init                       # Initialize a new repository"
    echo
    echo "SQLite commands:"
    echo "  sqlite3 --version              # Check SQLite version"
    echo "  sqlite3 database.db            # Open/create a database"
    echo "  sqlite3 database.db '.tables'  # List tables in database"
}

# Main execution
main() {
    echo
    print_info "=== Git and SQLite Installation Script ==="
    echo
    
    detect_package_manager
    check_privileges
    echo
    
    update_repositories
    echo
    
    # Install Git
    if check_git; then
        read -p "Git is already installed. Reinstall/Update? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_git
        fi
    else
        install_git
    fi
    
    configure_git
    echo
    
    # Install SQLite
    if check_sqlite; then
        read -p "SQLite is already installed. Reinstall/Update? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_sqlite
        fi
    else
        install_sqlite
    fi
    
    echo
    verify_installations
    echo
    show_usage
    echo
    print_info "=== Installation Complete ==="
}

# Run main function
main