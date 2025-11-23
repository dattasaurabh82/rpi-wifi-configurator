#!/bin/bash

# Test script to verify the installer works in dry-run mode
# Run this on your Mac to test without a Pi

cd "$(dirname "$0")"

echo "Making scripts executable..."
chmod +x install.sh uninstall.sh configure.py

echo ""
echo "Testing install.sh in dry-run mode..."
echo "================================================"
./install.sh --dry-run

echo ""
echo "================================================"
echo "Test complete!"
echo ""
echo "To test on your Mac:"
echo "  ./test_install.sh"
