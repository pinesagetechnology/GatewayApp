#!/bin/bash

# Application Update Script
# Description: Update the deployed React TypeScript UI application

set -e

# Configuration
APP_NAME="react-ui-app"
APP_DIR="/opt/${APP_NAME}"
PM2_APP_NAME="ui-app"
BACKUP_DIR="/opt/backups"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

# Check if running from project directory
check_project() {
    if [[ ! -f "package.json" ]]; then
        error "package.json not found. Please run this script from your project root directory."
    fi
    log "Project directory verified"
}

# Create backup
create_backup() {
    log "Creating backup of current deployment..."
    
    sudo mkdir -p $BACKUP_DIR
    BACKUP_NAME="${APP_NAME}_$(date +%Y%m%d_%H%M%S)"
    
    if [[ -d $APP_DIR ]]; then
        sudo cp -r $APP_DIR "${BACKUP_DIR}/${BACKUP_NAME}"
        log "Backup created: ${BACKUP_DIR}/${BACKUP_NAME}"
    else
        warn "No existing deployment found to backup"
    fi
}

# Stop services
stop_services() {
    log "Stopping services..."
    
    # Stop PM2 application
    pm2 stop $PM2_APP_NAME 2>/dev/null || warn "PM2 app not running"
    
    log "Services stopped"
}

# Update application
update_application() {
    log "Updating application..."
    
    # Install dependencies (including dev dependencies for build)
    npm install
    
    # Build the application
    log "Building application..."
    npm run build
    
    # Copy new build to app directory
    sudo mkdir -p "$APP_DIR"
    if [[ -d "$APP_DIR/dist" ]]; then
        sudo rm -rf "$APP_DIR/dist"
    fi
    
    sudo cp -r dist $APP_DIR/
    sudo chown -R $(whoami):$(whoami) $APP_DIR
    
    log "Application updated successfully"
}

# Start services
start_services() {
    log "Starting services..."
    
    # Start or restart PM2 application
    if pm2 list | grep -q "\b$PM2_APP_NAME\b"; then
        pm2 restart $PM2_APP_NAME || true
    else
        cd "$APP_DIR"
        if [[ -f "ecosystem.config.js" ]]; then
            pm2 start ecosystem.config.js
        else
            # Fallback: start a serve process directly
            pm2 start npx --name $PM2_APP_NAME -- serve -s dist -l 3001
        fi
        pm2 save
    fi
    
    # Reload Nginx (just in case)
    sudo systemctl reload nginx
    
    log "Services started"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    sleep 5
    
    if curl -s http://localhost > /dev/null; then
        log "✓ Application is accessible"
    else
        error "✗ Application is not accessible"
    fi
    
    if pm2 list | grep -q $PM2_APP_NAME; then
        log "✓ PM2 service is running"
    else
        error "✗ PM2 service is not running"
    fi
}

# Rollback function
rollback() {
    warn "Rolling back to previous version..."
    
    # Find latest backup
    LATEST_BACKUP=$(ls -t ${BACKUP_DIR}/${APP_NAME}_* 2>/dev/null | head -n1)
    
    if [[ -n "$LATEST_BACKUP" ]]; then
        log "Rolling back to: $LATEST_BACKUP"
        
        # Stop services
        pm2 stop $PM2_APP_NAME 2>/dev/null || true
        
        # Restore backup
        sudo rm -rf $APP_DIR
        sudo cp -r "$LATEST_BACKUP" $APP_DIR
        
        # Start services
        pm2 start $PM2_APP_NAME
        
        log "Rollback completed"
    else
        error "No backup found for rollback"
    fi
}

# Cleanup old backups (keep last 5)
cleanup_backups() {
    log "Cleaning up old backups..."
    
    if [[ -d $BACKUP_DIR ]]; then
        cd $BACKUP_DIR
        ls -t ${APP_NAME}_* 2>/dev/null | tail -n +6 | xargs sudo rm -rf 2>/dev/null || true
        log "Old backups cleaned up"
    fi
}

# Main update function
main() {
    case "${1:-update}" in
        "update")
            log "Starting application update..."
            check_project
            create_backup
            stop_services
            update_application
            start_services
            verify_deployment
            cleanup_backups
            log "Update completed successfully!"
            ;;
        "rollback")
            rollback
            ;;
        "restart")
            log "Restarting services..."
            stop_services
            start_services
            verify_deployment
            log "Services restarted successfully!"
            ;;
        *)
            echo "Usage: $0 [update|rollback|restart]"
            echo "  update   - Update application with current code"
            echo "  rollback - Rollback to previous version"
            echo "  restart  - Restart services without updating"
            exit 1
            ;;
    esac
}

# Handle interruption during rollback
trap 'if [[ "${1:-update}" == "rollback" ]]; then error "Rollback interrupted"; else rollback; fi' INT TERM

main "$@"