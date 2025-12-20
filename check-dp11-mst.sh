#!/usr/bin/env bash
# Diagnostic script for DP-11 MST issue
# Run after reboot with drm.debug=0x1e

echo "=========================================="
echo "DP-11 MST Diagnostic Report"
echo "Generated: $(date)"
echo "=========================================="
echo ""

echo "1. Current DP-11 Status:"
echo "-----------------------"
echo "Niri output status:"
niri msg outputs | grep -A 10 "DP-11" || echo "DP-11 not found in Niri outputs"
echo ""
echo "DRM sysfs status:"
echo "  Status: $(cat /sys/class/drm/card2/card2-DP-11/status 2>/dev/null || echo 'N/A')"
echo "  Enabled: $(cat /sys/class/drm/card2/card2-DP-11/enabled 2>/dev/null || echo 'N/A')"
echo "  DPMS: $(cat /sys/class/drm/card2/card2-DP-11/dpms 2>/dev/null || echo 'N/A')"
echo ""

echo "2. Kernel Parameter Check:"
echo "--------------------------"
echo "drm.debug setting: $(cat /proc/cmdline | grep -o 'drm.debug=[^ ]*' || echo 'NOT FOUND')"
echo ""

echo "3. MST Topology and DP-11 Initialization (last 50 lines):"
echo "-----------------------------------------------------------"
journalctl -k --since '10 minutes ago' 2>/dev/null | grep -iE 'dp-11|mst.*dp-11|drm.*card2.*dp-11' | tail -50 || echo "No DP-11 specific messages found"
echo ""

echo "4. All MST-Related Messages (last 50 lines):"
echo "--------------------------------------------"
journalctl -k --since '10 minutes ago' 2>/dev/null | grep -iE 'mst|displayport.*mst|drm_dp_mst' | tail -50 || echo "No MST messages found"
echo ""

echo "5. Connector State Changes:"
echo "---------------------------"
journalctl -k --since '10 minutes ago' 2>/dev/null | grep -iE 'connector.*dp-11|atomic.*dp-11|state.*dp-11|testing.*state.*card2' | tail -50 || echo "No connector state messages found"
echo ""

echo "6. Power Delivery / DPCD / AUX Issues:"
echo "-------------------------------------"
journalctl -k --since '10 minutes ago' 2>/dev/null | grep -iE 'power.*dp-11|dpcd.*dp-11|aux.*dp-11|i2c.*mst|unsupported.*i2c' | tail -30 || echo "No power/DPCD messages found"
echo ""

echo "7. DRM Errors Related to card2:"
echo "--------------------------------"
journalctl -k --since '10 minutes ago' 2>/dev/null | grep -iE 'drm.*error.*card2|error.*testing.*state.*card2|invalid.*argument.*card2' | tail -30 || echo "No DRM errors found"
echo ""

echo "8. Comparison: DP-9 (working) vs DP-11 (failing):"
echo "------------------------------------------------"
echo "DP-9:"
echo "  Status: $(cat /sys/class/drm/card2-DP-9/status 2>/dev/null || echo 'N/A')"
echo "  Enabled: $(cat /sys/class/drm/card2-DP-9/enabled 2>/dev/null || echo 'N/A')"
echo "  DPMS: $(cat /sys/class/drm/card2-DP-9/dpms 2>/dev/null || echo 'N/A')"
echo ""
echo "DP-11:"
echo "  Status: $(cat /sys/class/drm/card2-DP-11/status 2>/dev/null || echo 'N/A')"
echo "  Enabled: $(cat /sys/class/drm/card2-DP-11/enabled 2>/dev/null || echo 'N/A')"
echo "  DPMS: $(cat /sys/class/drm/card2-DP-11/dpms 2>/dev/null || echo 'N/A')"
echo ""

echo "9. MST Connector List:"
echo "----------------------"
ls -1 /sys/class/drm/card2-DP-*/ 2>/dev/null | grep -o 'card2-DP-[0-9]*' | sort -V || echo "No MST connectors found"
echo ""

echo "=========================================="
echo "Diagnostic complete. Review the output above"
echo "for clues about power delivery, MST topology,"
echo "or communication issues."
echo "=========================================="


