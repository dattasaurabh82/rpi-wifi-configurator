#!/bin/bash

# RPi WiFi Configurator - Installation Script
# This script automates the setup of the WiFi configurator service

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
INSTALL_DIR="$SCRIPT_DIR"
DRY_RUN=false
TOTAL_STEPS=7

# Configuration variables
BUTTON_GPIO_PIN=""
LED_GPIO_PIN=""
AP_SSID=""
AP_PASSWORD=""

# ============================================
# Helper functions
# ============================================

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  RPi WiFi Configurator - Automated Setup            ║${NC}"
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

run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}[WOULD RUN]${NC} $1"
        return 0
    else
        eval "$1"
    fi
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
# Pre-flight check functions
# ============================================

check_raspberry_pi() {
    print_info "Checking system..."
    
    if [ "$DRY_RUN" = true ]; then
        print_success "Raspberry Pi 4 Model B detected (simulated)"
        print_success "Raspberry Pi OS (Bookworm) 64-bit (simulated)"
        return 0
    fi
    
    # Check if running on Raspberry Pi
    if [ -f /proc/cpuinfo ]; then
        if grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
            local model=$(grep "Model" /proc/cpuinfo | cut -d: -f2 | xargs)
            print_success "Raspberry Pi detected: $model"
        else
            print_warning "Not a Raspberry Pi detected"
            if ! ask_yes_no "Continue anyway? (for testing purposes)"; then
                print_error "Installation cancelled"
                exit 1
            fi
        fi
    else
        print_warning "Cannot detect hardware"
        if ! ask_yes_no "Continue anyway? (for testing purposes)"; then
            print_error "Installation cancelled"
            exit 1
        fi
    fi
    
    # Check OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        print_success "OS: $PRETTY_NAME"
    fi
}

check_network_manager() {
    print_info "Checking NetworkManager..."
    
    if [ "$DRY_RUN" = true ]; then
        print_success "NetworkManager 1.44.2 installed (simulated)"
        return 0
    fi
    
    if command -v nmcli &> /dev/null; then
        local nm_version=$(nmcli --version | head -n1)
        print_success "NetworkManager installed: $nm_version"
    else
        print_warning "NetworkManager not found"
        
        # Check if this is old Pi OS
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            if [[ "$VERSION_CODENAME" == "buster" ]] || [[ "$VERSION_CODENAME" == "stretch" ]]; then
                print_error "Old Raspberry Pi OS detected ($VERSION_CODENAME)"
                print_error "This tool requires NetworkManager (available in Bookworm or newer)"
                print_error "Please upgrade your OS or use a newer Pi OS image"
                exit 1
            fi
        fi
        
        print_info "Attempting to install NetworkManager..."
        if ask_yes_no "Install NetworkManager now?"; then
            sudo apt-get update
            sudo apt-get install -y network-manager
            print_success "NetworkManager installed successfully"
        else
            print_error "NetworkManager is required for this tool"
            exit 1
        fi
    fi
}

check_python() {
    print_info "Checking Python..."
    
    if [ "$DRY_RUN" = true ]; then
        print_success "Python 3.11.2 found (simulated)"
        return 0
    fi
    
    if command -v python3 &> /dev/null; then
        local py_version=$(python3 --version)
        print_success "$py_version found"
    else
        print_error "Python 3 not found!"
        print_error "Please install Python 3: sudo apt-get install python3 python3-pip python3-venv"
        exit 1
    fi
    
    # Check if python3-venv is available
    if ! python3 -m venv --help &> /dev/null; then
        print_warning "python3-venv not found"
        if ask_yes_no "Install python3-venv now?"; then
            sudo apt-get install -y python3-venv
        else
            print_error "python3-venv is required"
            exit 1
        fi
    fi
}

check_internet() {
    print_info "Checking internet connection..."
    
    if [ "$DRY_RUN" = true ]; then
        print_success "Internet connection available (simulated)"
        return 0
    fi
    
    if ping -c 1 google.com &> /dev/null || ping -c 1 8.8.8.8 &> /dev/null; then
        print_success "Internet connection available"
    else
        print_warning "No internet connection detected"
        print_info "Internet is required to install Python dependencies"
        
        # Check if we already have venv with packages
        if [ -d "$INSTALL_DIR/venv" ] && [ -f "$INSTALL_DIR/venv/bin/python" ]; then
            print_info "Existing virtual environment found"
            if "$INSTALL_DIR/venv/bin/python" -c "import flask" 2>/dev/null; then
                print_success "Required packages already installed"
                return 0
            fi
        fi
        
        print_error "Cannot proceed without internet connection"
        print_info "Please connect to internet and try again"
        exit 1
    fi
}

check_gpio_permissions() {
    print_info "Checking GPIO permissions..."
    
    if [ "$DRY_RUN" = true ]; then
        print_success "User in 'gpio' group (simulated)"
        return 0
    fi
    
    if groups | grep -q gpio; then
        print_success "User in 'gpio' group"
    else
        print_warning "User not in 'gpio' group"
        print_info "Adding user to 'gpio' group..."
        sudo usermod -a -G gpio $USER
        print_success "User added to 'gpio' group"
        print_warning "You need to log out and log back in for group changes to take effect"
        if ask_yes_no "Continue anyway? (GPIO access may not work until reboot)"; then
            print_info "Continuing installation..."
        else
            print_info "Please log out and log back in, then run this installer again"
            exit 0
        fi
    fi
}

check_existing_installation() {
    print_info "Checking for existing installation..."
    
    if [ "$DRY_RUN" = true ]; then
        print_success "No existing installation found (simulated)"
        return 0
    fi
    
    local has_existing=false
    
    # Check for config.ini
    if [ -f "$INSTALL_DIR/config.ini" ]; then
        has_existing=true
    fi
    
    # Check for service
    if systemctl --user list-unit-files | grep -q "rpi-btn-wifi-manager.service"; then
        has_existing=true
    fi
    
    if [ "$has_existing" = true ]; then
        print_warning "Existing installation detected"
        echo ""
        echo "  Options:"
        echo "  [1] Overwrite (keeps config.ini, updates code)"
        echo "  [2] Fresh install (deletes everything, new config)"
        echo "  [3] Exit"
        echo ""
        read -p "  Choice [1]: " choice
        choice=${choice:-1}
        
        case $choice in
            1)
                print_info "Keeping existing configuration, updating code..."
                # Stop service if running
                if systemctl --user is-active rpi-btn-wifi-manager.service &>/dev/null; then
                    print_info "Stopping service..."
                    systemctl --user stop rpi-btn-wifi-manager.service
                fi
                ;;
            2)
                print_warning "This will delete all existing configuration and files"
                if ask_yes_no "Are you sure?"; then
                    print_info "Removing existing installation..."
                    if [ -f "$INSTALL_DIR/uninstall.sh" ]; then
                        bash "$INSTALL_DIR/uninstall.sh"
                    else
                        # Manual cleanup
                        systemctl --user stop rpi-btn-wifi-manager.service 2>/dev/null || true
                        systemctl --user disable rpi-btn-wifi-manager.service 2>/dev/null || true
                        rm -f ~/.config/systemd/user/rpi-btn-wifi-manager.service
                        systemctl --user daemon-reload
                        rm -rf "$INSTALL_DIR/venv"
                        rm -f "$INSTALL_DIR/config.ini"
                    fi
                    print_success "Existing installation removed"
                else
                    print_info "Installation cancelled"
                    exit 0
                fi
                ;;
            3)
                print_info "Installation cancelled"
                exit 0
                ;;
            *)
                print_error "Invalid choice"
                exit 1
                ;;
        esac
    else
        print_success "No existing installation found"
    fi
}

# ============================================
# Configuration functions
# ============================================

prompt_hardware_config() {
    print_info "GPIO Pin Configuration:"
    print_info "----------------------"
    
    # Button GPIO Pin
    read -p "  Button GPIO Pin [23]: " BUTTON_GPIO_PIN
    BUTTON_GPIO_PIN=${BUTTON_GPIO_PIN:-23}
    
    # Validate it's a number
    if ! [[ "$BUTTON_GPIO_PIN" =~ ^[0-9]+$ ]]; then
        print_error "Invalid GPIO pin number"
        exit 1
    fi
    
    # LED GPIO Pin
    read -p "  LED GPIO Pin [24]: " LED_GPIO_PIN
    LED_GPIO_PIN=${LED_GPIO_PIN:-24}
    
    # Validate it's a number
    if ! [[ "$LED_GPIO_PIN" =~ ^[0-9]+$ ]]; then
        print_error "Invalid GPIO pin number"
        exit 1
    fi
    
    print_success "GPIO pins configured: Button=${BUTTON_GPIO_PIN}, LED=${LED_GPIO_PIN}"
}

prompt_ap_config() {
    print_info "Access Point Settings:"
    print_info "---------------------"
    
    # AP SSID
    read -p "  AP Name [RPI_NET_SETUP]: " AP_SSID
    AP_SSID=${AP_SSID:-RPI_NET_SETUP}
    
    # AP Password
    read -s -p "  AP Password (Leave empty for default '1234', min 8 chars if custom): " AP_PASSWORD
    echo ""
    
    # If empty, use default
    if [ -z "$AP_PASSWORD" ]; then
        AP_PASSWORD="1234"
        print_info "Using default password: 1234"
    else
        # Validate minimum length
        if [ ${#AP_PASSWORD} -lt 8 ]; then
            print_error "Password must be at least 8 characters"
            exit 1
        fi
    fi
    
    print_success "Access Point configured: SSID=${AP_SSID}"
}

create_config_file() {
    print_info "Creating configuration file..."
    
    if [ "$DRY_RUN" = true ]; then
        print_success "Would create config.ini with:"
        echo "    Button GPIO: $BUTTON_GPIO_PIN"
        echo "    LED GPIO: $LED_GPIO_PIN"
        echo "    AP SSID: $AP_SSID"
        echo "    AP Password: $AP_PASSWORD"
        return 0
    fi
    
    # Check if config.ini already exists and we're in overwrite mode
    local backup_config=false
    if [ -f "$INSTALL_DIR/config.ini" ]; then
        print_info "Backing up existing config.ini..."
        cp "$INSTALL_DIR/config.ini" "$INSTALL_DIR/config.ini.backup"
        backup_config=true
    fi
    
    # Create config.ini from template
    cat > "$INSTALL_DIR/config.ini" <<EOF
[hardware]
button_gpio_pin = $BUTTON_GPIO_PIN
led_gpio_pin = $LED_GPIO_PIN

[access_point]
ap_ssid = $AP_SSID
ap_password = $AP_PASSWORD

[server]
port = 4000
EOF
    
    if [ "$backup_config" = true ]; then
        print_success "Configuration created (backup saved as config.ini.backup)"
    else
        print_success "Configuration created: config.ini"
    fi
}

# ============================================
# Python venv setup functions
# ============================================

setup_python_venv() {
    print_info "Creating virtual environment 'venv'..."
    
    if [ "$DRY_RUN" = true ]; then
        print_success "Would create venv at: $INSTALL_DIR/venv"
        print_success "Would upgrade pip"
        print_success "Would install 30 packages from requirements.txt"
        return 0
    fi
    
    # Remove existing venv if it exists and we're doing fresh install
    if [ -d "$INSTALL_DIR/venv" ]; then
        print_info "Removing existing virtual environment..."
        rm -rf "$INSTALL_DIR/venv"
    fi
    
    # Create new venv
    python3 -m venv "$INSTALL_DIR/venv"
    print_success "Virtual environment created"
    
    # Upgrade pip
    print_info "Upgrading pip..."
    "$INSTALL_DIR/venv/bin/python" -m pip install --upgrade pip > /dev/null 2>&1
    print_success "Pip upgraded"
    
    # Install dependencies
    print_info "Installing dependencies from requirements.txt..."
    print_info "This may take a few minutes..."
    
    # Install with progress
    if "$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt" > /tmp/pip_install.log 2>&1; then
        local pkg_count=$(grep -c "Successfully installed" /tmp/pip_install.log || echo "30")
        print_success "All dependencies installed successfully"
        rm -f /tmp/pip_install.log
    else
        print_error "Failed to install dependencies"
        print_info "Check log at: /tmp/pip_install.log"
        print_info "You can try manually with:"
        print_info "  source $INSTALL_DIR/venv/bin/activate"
        print_info "  pip install -r $INSTALL_DIR/requirements.txt"
        exit 1
    fi
}

# ============================================
# Main installation flow
# ============================================

main() {
    print_header
    
    # Step 1: Pre-flight checks
    print_step "1" "$TOTAL_STEPS" "Pre-flight checks"
    check_raspberry_pi
    check_network_manager
    check_python
    check_internet
    check_gpio_permissions
    check_existing_installation
    echo ""
    
    # Step 2: Hardware configuration
    print_step "2" "$TOTAL_STEPS" "Hardware configuration"
    echo ""
    prompt_hardware_config
    echo ""
    
    # Step 3: Access Point configuration
    print_step "3" "$TOTAL_STEPS" "Access Point configuration"
    echo ""
    prompt_ap_config
    echo ""
    create_config_file
    echo ""
    
    # Step 4: Python venv setup
    print_step "4" "$TOTAL_STEPS" "Setting up Python environment"
    setup_python_venv
    echo ""
    
    # TODO: Steps 5-7 will be implemented next
    print_info "Python environment ready!"
    echo ""
    echo "  Next steps to implement:"
    echo "    5. NetworkManager hotspot creation"
    echo "    6. Service setup"
    echo "    7. Installation complete"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${GREEN}✓ Dry run complete${NC}"
    fi
}

# ============================================
# Check if dry-run mode
# ============================================
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
    echo -e "${YELLOW}[DRY RUN MODE - No actual changes will be made]${NC}"
    echo ""
fi

# Run main installation
main