#!/usr/bin/env bash
# Test script for Plymouth theme without rebooting
# Usage: sudo ./test-plymouth.sh

set -e

echo "Plymouth Theme Test Script"
echo "=========================="
echo ""
echo "This script will:"
echo "1. Check if Plymouth is available"
echo "2. Set the 'spectreos' theme"
echo "3. Show the splash screen"
echo "4. Simulate boot progress (0% to 100%)"
echo "5. Hide the splash screen"
echo ""
echo "IMPORTANT: This MUST be run on a VT (virtual terminal), not in a graphical session!"
echo "  - Switch to VT: Ctrl+Alt+F2 (or F3, F4, etc.)"
echo "  - Log in and run: sudo ./test-plymouth.sh"
echo "  - Switch back: Ctrl+Alt+F1 (or Alt+F7 for GDM)"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

# Check if Plymouth is installed
if ! command -v plymouth &> /dev/null; then
    echo "Error: Plymouth is not installed"
    exit 1
fi

# Check if plymouthd is running
if ! plymouth --ping &> /dev/null; then
    echo "Starting Plymouth daemon..."
    # Try to start plymouthd in boot mode
    # Note: This may not work in a graphical session
    plymouthd --mode=boot --attach-to-session 2>&1 || {
        echo "Warning: Could not start plymouthd automatically"
        echo "You may need to switch to a VT (Ctrl+Alt+F2) and run:"
        echo "  sudo plymouthd --mode=boot --attach-to-session"
        echo "Then run this script again"
        exit 1
    }
    sleep 1
fi

echo "Plymouth daemon is running"
echo ""

# Check if theme directory exists
echo "Checking if 'spectreos' theme is available..."
THEME_DIR="/run/current-system/sw/share/plymouth/themes/spectreos"
if [ -d "$THEME_DIR" ]; then
    echo "Theme directory found: $THEME_DIR"
else
    echo "Warning: Theme directory not found at $THEME_DIR"
    echo "Make sure you've rebuilt with: sudo nixos-rebuild switch"
fi

# Set the theme explicitly
echo "Setting theme to 'spectreos'..."
plymouth set-theme spectreos 2>&1 || {
    echo "Warning: Could not set theme. Continuing anyway..."
    echo "The theme should still work if it's set in configuration.nix"
}

# Change to boot mode to ensure proper initialization
echo "Changing to boot mode..."
plymouth change-mode boot 2>&1 || true

# Show splash screen
echo "Showing splash screen..."
plymouth show-splash

# Wait for OnDisplayInit to complete (give it time to initialize)
echo "Waiting 2 seconds for display initialization..."
sleep 2

# Wait a moment to see initial state
echo "Waiting 3 more seconds to see initial state..."
echo "  - Logo should be centered"
echo "  - Progress box should be visible below logo"
echo "  - Progress bar should be visible (starts at 0%, will animate)"
sleep 3

# Simulate boot progress using system-update command
echo "Simulating boot progress..."
# Progress is a float from 0.0 to 1.0
# Try both formats: decimal (0.0-1.0) and percentage (0-100)
for i in 0 10 20 30 40 50 60 70 80 90 100; do
    progress_decimal=$(awk "BEGIN {printf \"%.2f\", $i/100}")
    echo "Progress: $i% (sending: $progress_decimal)"
    # system-update with progress triggers OnBootProgress(duration, progress)
    # Try decimal format first (0.0 to 1.0)
    plymouth system-update --progress=$progress_decimal 2>&1 || {
        # Fallback: try percentage format
        plymouth system-update --progress=$i 2>&1 || true
    }
    sleep 0.5
done

# Wait a moment
sleep 1

# Hide splash screen
echo "Hiding splash screen..."
plymouth hide-splash

# Quit Plymouth
echo "Quitting Plymouth..."
plymouth quit

echo ""
echo "Test complete!"
echo ""
echo "If you didn't see the splash screen, try:"
echo "1. Switch to a VT: Ctrl+Alt+F2"
echo "2. Run: sudo plymouthd --mode=boot --attach-to-session"
echo "3. Run this script again: sudo ./test-plymouth.sh"

