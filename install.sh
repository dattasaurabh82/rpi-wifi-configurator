#!/bin/bash

# RPi WiFi Configuration - Installation Script
# This script automates the setup of the WiFi configuration service

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

# ============================================
# Helper functions
# ============================================

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  RPi WiFi Configuration - Automated Setup            ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}[$1/$2]${NC} $3"
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
    else
        eval "$1"
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

# ============================================
# Main installation
# ============================================

print_header

# TODO: We'll implement steps here
echo "Installation script structure created!"
echo ""
echo "Next steps to implement:"
echo "  1. Pre-flight checks"
echo "  2. Hardware configuration prompts"
echo "  3. Access point configuration prompts"
echo "  4. Python venv setup"
echo "  5. NetworkManager hotspot creation"
echo "  6. Service setup"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}✓ Dry run complete${NC}"
else
    echo -e "${YELLOW}Note: Full implementation coming in next steps${NC}"
fi
