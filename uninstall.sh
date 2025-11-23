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
# Helper functions
# ============================================

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  RPi WiFi Configuration - Uninstall                  ║${NC}"
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

# ============================================
# Main uninstallation
# ============================================

print_header

echo "Uninstallation script structure created!"
echo ""
echo "Next steps to implement:"
echo "  1. Backup current WiFi state"
echo "  2. Stop and remove service"
echo "  3. Remove NetworkManager hotspot"
echo "  4. Clean installation directory"
echo "  5. Restore WiFi connection"
echo "  6. Final cleanup"
echo ""
