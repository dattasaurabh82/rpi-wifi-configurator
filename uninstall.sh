#!/bin/bash

# RPi WiFi Configuration - Uninstallation Script
# This script removes the WiFi configuration and restores original WiFi state

set -e  # Exit on any error

# ============================================
# Color codes for output
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# Global variables
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER=$(whoami)
TOTAL_STEPS=5

# ============================================
# Helper functions
# ============================================

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  RPi WiFi Configurator - Uninstall                   ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}[$1/$2]${NC} $3"
    echo ""
}

print_info() {
    echo -e "  ${BLUE}→${NC} $1"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    
    if [ "$default" = "y" ]; then
        read -p "$prompt (Y/n): " response
        response=${response:-y}
    else
        read -p "$prompt (y/N): " response
        response=${response:-n}
    fi
    
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# ============================================
# Main uninstallation
# ============================================

main() {
    print_header
    
    # Confirm uninstallation
    print_warning "This will remove the WiFi configurator and all its files"
    if ! ask_yes_no "Continue with uninstallation?"; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    echo ""
    
    # Step 1: Stop and remove service
    print_step "1" "$TOTAL_STEPS" "Stopping and removing service"
    
    if systemctl --user is-active rpi-btn-wifi-manager.service &>/dev/null; then
        print_info "Stopping service..."
        systemctl --user stop rpi-btn-wifi-manager.service
        print_success "Service stopped"
    else
        print_info "Service not running"
    fi
    
    if systemctl --user is-enabled rpi-btn-wifi-manager.service &>/dev/null; then
        print_info "Disabling service..."
        systemctl --user disable rpi-btn-wifi-manager.service
        print_success "Service disabled"
    else
        print_info "Service not enabled"
    fi
    
    if [ -f "$HOME/.config/systemd/user/rpi-btn-wifi-manager.service" ]; then
        print_info "Removing service file..."
        rm -f "$HOME/.config/systemd/user/rpi-btn-wifi-manager.service"
        systemctl --user daemon-reload
        print_success "Service file removed"
    else
        print_info "Service file not found"
    fi
    echo ""
    
    # Step 2: Remove PolicyKit rule
    print_step "2" "$TOTAL_STEPS" "Removing PolicyKit rule"
    
    POLKIT_RULES_FILE="/etc/polkit-1/rules.d/50-networkmanager-$CURRENT_USER.rules"
    POLKIT_PKLA_FILE="/etc/polkit-1/localauthority/50-local.d/50-networkmanager-$CURRENT_USER.pkla"
    
    if [ -f "$POLKIT_RULES_FILE" ]; then
        print_info "Removing PolicyKit rule: $POLKIT_RULES_FILE"
        sudo rm -f "$POLKIT_RULES_FILE"
        print_success "PolicyKit rule removed"
    elif [ -f "$POLKIT_PKLA_FILE" ]; then
        print_info "Removing PolicyKit rule: $POLKIT_PKLA_FILE"
        sudo rm -f "$POLKIT_PKLA_FILE"
        print_success "PolicyKit rule removed"
    else
        print_info "No PolicyKit rule found"
    fi
    echo ""
    
    # Step 3: Remove NetworkManager hotspot
    print_step "3" "$TOTAL_STEPS" "Removing NetworkManager hotspot"
    
    if sudo nmcli con show hotspot &>/dev/null; then
        print_info "Removing hotspot connection..."
        sudo nmcli con delete hotspot
        print_success "Hotspot removed"
    else
        print_info "Hotspot connection not found"
    fi
    echo ""
    
    # Step 4: Clean installation directory
    print_step "4" "$TOTAL_STEPS" "Cleaning installation files"
    
    if [ -d "$SCRIPT_DIR/venv" ]; then
        print_info "Removing virtual environment..."
        rm -rf "$SCRIPT_DIR/venv"
        print_success "Virtual environment removed"
    fi
    
    if [ -f "$SCRIPT_DIR/config.ini" ]; then
        print_info "Removing configuration file..."
        rm -f "$SCRIPT_DIR/config.ini"
        rm -f "$SCRIPT_DIR/config.ini.backup"
        print_success "Configuration removed"
    fi
    
    print_info "Keeping source files (install.sh, app.py, etc.)"
    print_info "To completely remove, manually delete: $SCRIPT_DIR"
    echo ""
    
    # Step 5: Final cleanup
    print_step "5" "$TOTAL_STEPS" "Uninstallation complete"
    echo ""
    print_success "WiFi configurator uninstalled successfully!"
    echo ""
    print_info "What was removed:"
    echo "     - Systemd service"
    echo "     - PolicyKit rule"
    echo "     - NetworkManager hotspot connection"
    echo "     - Python virtual environment"
    echo "     - Configuration files"
    echo ""
    print_info "What remains:"
    echo "     - Source code in: $SCRIPT_DIR"
    echo "     - To reinstall: cd $SCRIPT_DIR && ./install.sh"
    echo ""
}

# Run main uninstallation
main
