#!/bin/bash

# System Monitoring Script for UI Application
# Description: Monitor system resources and application health

# Configuration
APP_NAME="react-ui-app"
PM2_APP_NAME="ui-app"
LOG_FILE="/var/log/${APP_NAME}/monitoring.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Thresholds
CPU_THRESHOLD=80
MEM_THRESHOLD=85
DISK_THRESHOLD=90
TEMP_THRESHOLD=70

log_entry() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a $LOG_FILE
}

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}    System Monitoring Dashboard${NC}"
    echo -e "${BLUE}    $(date)${NC}"
    echo -e "${BLUE}============================================${NC}"
}

# Detect platform
detect_platform() {
    if [[ -f /etc/nv_tegra_release ]] || [[ -f /sys/devices/soc0/machine ]]; then
        echo "jetson"
    elif grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
        echo "raspberry"
    else
        echo "generic"
    fi
}

# Check system resources
check_system_resources() {
    echo -e "\n${BLUE}=== System Resources ===${NC}"
    
    # CPU Usage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d',' -f1)
    if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l) )); then
        echo -e "CPU Usage: ${RED}${CPU_USAGE}%${NC} (High)"
        log_entry "WARNING: High CPU usage: ${CPU_USAGE}%"
    else
        echo -e "CPU Usage: ${GREEN}${CPU_USAGE}%${NC}"
    fi
    
    # Memory Usage
    MEM_INFO=$(free | awk 'NR==2{printf "%.1f %.1f", $3*100/$2, $2/1024/1024}')
    MEM_USAGE=$(echo $MEM_INFO | cut -d' ' -f1)
    MEM_TOTAL=$(echo $MEM_INFO | cut -d' ' -f2)
    
    if (( $(echo "$MEM_USAGE > $MEM_THRESHOLD" | bc -l) )); then
        echo -e "Memory Usage: ${RED}${MEM_USAGE}%${NC} of ${MEM_TOTAL}GB (High)"
        log_entry "WARNING: High memory usage: ${MEM_USAGE}%"
    else
        echo -e "Memory Usage: ${GREEN}${MEM_USAGE}%${NC} of ${MEM_TOTAL}GB"
    fi
    
    # Disk Usage
    DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
    if [[ $DISK_USAGE -gt $DISK_THRESHOLD ]]; then
        echo -e "Disk Usage: ${RED}${DISK_USAGE}%${NC} (High)"
        log_entry "WARNING: High disk usage: ${DISK_USAGE}%"
    else
        echo -e "Disk Usage: ${GREEN}${DISK_USAGE}%${NC}"
    fi
    
    # Load Average
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
    echo -e "Load Average:${LOAD_AVG}"
}

# Check temperatures
check_temperatures() {
    PLATFORM=$(detect_platform)
    
    echo -e "\n${BLUE}=== Temperature Monitoring ===${NC}"
    
    case $PLATFORM in
        "jetson")
            if [[ -d /sys/devices/virtual/thermal ]]; then
                for zone in /sys/devices/virtual/thermal/thermal_zone*/temp; do
                    if [[ -r "$zone" ]]; then
                        TEMP=$(cat "$zone" 2>/dev/null)
                        if [[ -n "$TEMP" && "$TEMP" -gt 0 ]]; then
                            TEMP_C=$((TEMP / 1000))
                            ZONE_NAME=$(basename $(dirname "$zone"))
                            
                            if [[ $TEMP_C -gt $TEMP_THRESHOLD ]]; then
                                echo -e "${ZONE_NAME}: ${RED}${TEMP_C}°C${NC} (High)"
                                log_entry "WARNING: High temperature in ${ZONE_NAME}: ${TEMP_C}°C"
                            else
                                echo -e "${ZONE_NAME}: ${GREEN}${TEMP_C}°C${NC}"
                            fi
                        fi
                    fi
                done
            fi
            ;;
        "raspberry")
            if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
                TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
                TEMP_C=$((TEMP / 1000))
                
                if [[ $TEMP_C -gt $TEMP_THRESHOLD ]]; then
                    echo -e "CPU Temperature: ${RED}${TEMP_C}°C${NC} (High)"
                    log_entry "WARNING: High CPU temperature: ${TEMP_C}°C"
                else
                    echo -e "CPU Temperature: ${GREEN}${TEMP_C}°C${NC}"
                fi
            fi
            ;;
        *)
            echo "Temperature monitoring not available for this platform"
            ;;
    esac
}

# Check application status
check_application() {
    echo -e "\n${BLUE}=== Application Status ===${NC}"
    
    # PM2 Status
    if pm2 list | grep -q $PM2_APP_NAME; then
        PM2_STATUS=$(pm2 jlist | jq -r ".[] | select(.name==\"$PM2_APP_NAME\") | .pm2_env.status" 2>/dev/null || echo "unknown")
        case $PM2_STATUS in
            "online")
                echo -e "PM2 Status: ${GREEN}Online${NC}"
                ;;
            "stopped")
                echo -e "PM2 Status: ${RED}Stopped${NC}"
                log_entry "ERROR: PM2 application is stopped"
                ;;
            *)
                echo -e "PM2 Status: ${YELLOW}${PM2_STATUS}${NC}"
                ;;
        esac
        
        # Memory usage of PM2 app
        PM2_MEMORY=$(pm2 jlist | jq -r ".[] | select(.name==\"$PM2_APP_NAME\") | .monit.memory" 2>/dev/null || echo "0")
        if [[ $PM2_MEMORY -gt 0 ]]; then
            PM2_MEMORY_MB=$((PM2_MEMORY / 1024 / 1024))
            echo -e "App Memory: ${GREEN}${PM2_MEMORY_MB}MB${NC}"
        fi
    else
        echo -e "PM2 Status: ${RED}Not Found${NC}"
        log_entry "ERROR: PM2 application not found"
    fi
    
    # Nginx Status
    if systemctl is-active --quiet nginx; then
        echo -e "Nginx Status: ${GREEN}Active${NC}"
    else
        echo -e "Nginx Status: ${RED}Inactive${NC}"
        log_entry "ERROR: Nginx is not active"
    fi
    
    # Web Application Accessibility
    if curl -s --max-time 5 http://localhost > /dev/null; then
        echo -e "Web Access: ${GREEN}Available${NC}"
    else
        echo -e "Web Access: ${RED}Unavailable${NC}"
        log_entry "ERROR: Web application is not accessible"
    fi
}

# Check network connectivity
check_network() {
    echo -e "\n${BLUE}=== Network Status ===${NC}"
    
    # Local network interface
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    echo -e "IP Address: ${GREEN}${IP_ADDRESS}${NC}"
    
    # Internet connectivity
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        echo -e "Internet: ${GREEN}Connected${NC}"
    else
        echo -e "Internet: ${RED}Disconnected${NC}"
        log_entry "WARNING: No internet connectivity"
    fi
    
    # Check active connections
    CONNECTIONS=$(netstat -an | grep :80 | grep ESTABLISHED | wc -l)
    echo -e "Active HTTP Connections: ${GREEN}${CONNECTIONS}${NC}"
}

# Check logs for errors
check_logs() {
    echo -e "\n${BLUE}=== Recent Log Analysis ===${NC}"
    
    # Check PM2 logs for errors
    if [[ -f "/var/log/${APP_NAME}/error.log" ]]; then
        ERROR_COUNT=$(tail -n 100 "/var/log/${APP_NAME}/error.log" 2>/dev/null | grep -c "ERROR\|Error\|error" || echo "0")
        if [[ $ERROR_COUNT -gt 0 ]]; then
            echo -e "Recent Errors: ${RED}${ERROR_COUNT}${NC}"
            echo "Last error:"
            tail -n 1 "/var/log/${APP_NAME}/error.log" 2>/dev/null | sed 's/^/  /'
        else
            echo -e "Recent Errors: ${GREEN}None${NC}"
        fi
    fi
    
    # Check Nginx error logs
    if [[ -f "/var/log/nginx/error.log" ]]; then
        NGINX_ERRORS=$(tail -n 100 "/var/log/nginx/error.log" 2>/dev/null | grep -c "error\|ERROR" || echo "0")
        if [[ $NGINX_ERRORS -gt 0 ]]; then
            echo -e "Nginx Errors: ${RED}${NGINX_ERRORS}${NC}"
        else
            echo -e "Nginx Errors: ${GREEN}None${NC}"
        fi
    fi
}

# Platform-specific monitoring
platform_specific() {
    PLATFORM=$(detect_platform)
    
    case $PLATFORM in
        "jetson")
            echo -e "\n${BLUE}=== Jetson Specific ===${NC}"
            
            # GPU usage (if tegrastats is available)
            if command -v tegrastats &> /dev/null; then
                echo "GPU monitoring available via: sudo tegrastats"
            fi
            
            # Power model
            if command -v nvpmodel &> /dev/null; then
                POWER_MODE=$(sudo nvpmodel -q 2>/dev/null | grep "Power Mode" | cut -d':' -f2 | xargs || echo "Unknown")
                echo -e "Power Mode: ${GREEN}${POWER_MODE}${NC}"
            fi
            ;;
        "raspberry")
            echo -e "\n${BLUE}=== Raspberry Pi Specific ===${NC}"
            
            # GPU memory split
            if command -v vcgencmd &> /dev/null; then
                GPU_MEM=$(vcgencmd get_mem gpu 2>/dev/null | cut -d'=' -f2 || echo "Unknown")
                echo -e "GPU Memory: ${GREEN}${GPU_MEM}${NC}"
                
                # Throttling status
                THROTTLE=$(vcgencmd get_throttled 2>/dev/null | cut -d'=' -f2 || echo "0x0")
                if [[ "$THROTTLE" != "0x0" ]]; then
                    echo -e "Throttling: ${RED}Detected (${THROTTLE})${NC}"
                    log_entry "WARNING: System throttling detected: ${THROTTLE}"
                else
                    echo -e "Throttling: ${GREEN}None${NC}"
                fi
            fi
            ;;
    esac
}

# Generate summary report
generate_summary() {
    echo -e "\n${BLUE}=== Summary ===${NC}"
    
    # Overall health score
    ISSUES=0
    
    # Check CPU
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d',' -f1)
    if (( $(echo "$CPU_USAGE > $CPU_THRESHOLD" | bc -l) )); then
        ((ISSUES++))
    fi
    
    # Check Memory
    MEM_USAGE=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
    if (( $(echo "$MEM_USAGE > $MEM_THRESHOLD" | bc -l) )); then
        ((ISSUES++))
    fi
    
    # Check Disk
    DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
    if [[ $DISK_USAGE -gt $DISK_THRESHOLD ]]; then
        ((ISSUES++))
    fi
    
    # Check services
    if ! pm2 list | grep -q $PM2_APP_NAME; then
        ((ISSUES++))
    fi
    
    if ! systemctl is-active --quiet nginx; then
        ((ISSUES++))
    fi
    
    if [[ $ISSUES -eq 0 ]]; then
        echo -e "System Health: ${GREEN}Excellent${NC}"
    elif [[ $ISSUES -le 2 ]]; then
        echo -e "System Health: ${YELLOW}Good${NC} (${ISSUES} issues)"
    else
        echo -e "System Health: ${RED}Poor${NC} (${ISSUES} issues)"
    fi
    
    echo -e "Uptime: ${GREEN}$(uptime -p)${NC}"
}

# Watch mode
watch_mode() {
    echo "Starting monitoring in watch mode (press Ctrl+C to exit)..."
    
    while true; do
        clear
        print_header
        check_system_resources
        check_temperatures
        check_application
        check_network
        generate_summary
        
        echo -e "\n${BLUE}Refreshing in 10 seconds...${NC}"
        sleep 10
    done
}

# Main function
main() {
    # Create log directory if it doesn't exist
    sudo mkdir -p $(dirname $LOG_FILE)
    
    case "${1:-status}" in
        "status"|"check")
            print_header
            check_system_resources
            check_temperatures
            check_application
            check_network
            check_logs
            platform_specific
            generate_summary
            ;;
        "watch")
            watch_mode
            ;;
        "logs")
            echo "=== Application Logs ==="
            pm2 logs $PM2_APP_NAME --lines 50
            ;;
        "errors")
            echo "=== Recent Errors ==="
            if [[ -f "/var/log/${APP_NAME}/error.log" ]]; then
                tail -n 20 "/var/log/${APP_NAME}/error.log"
            else
                echo "No error log found"
            fi
            ;;
        *)
            echo "Usage: $0 [status|watch|logs|errors]"
            echo "  status - Show current system status (default)"
            echo "  watch  - Continuously monitor system"
            echo "  logs   - Show application logs"
            echo "  errors - Show recent errors"
            exit 1
            ;;
    esac
}

# Handle interruption
trap 'echo -e "\n${YELLOW}Monitoring stopped${NC}"; exit 0' INT TERM

main "$@"