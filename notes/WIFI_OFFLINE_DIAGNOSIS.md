# WiFi Offline Diagnosis Guide - Generation 76

## Quick Reference for Diagnosing WiFi Issues Without Network

### Step 1: Run Diagnostic Script
```bash
cd /home/miles/Documents/SpectreOS
./WIFI_DIAGNOSTIC_COMMANDS.sh > wifi_diagnostic_output.txt 2>&1
```

This will create a file with all diagnostic information that can be reviewed later.

### Step 2: Key Things to Check

#### A. NetworkManager Service
```bash
systemctl status NetworkManager
```
**Look for**: Is it running? Any errors? When did it start?

#### B. WiFi Radio State
```bash
nmcli radio wifi
```
**Expected**: `enabled`
**If disabled**: `nmcli radio wifi on` (may need sudo)

#### C. WiFi Device Status
```bash
nmcli device status
```
**Look for**: Is `wlp195s0` listed? What's its state?
- `connected` = Good
- `disconnected` = WiFi not connected
- `unavailable` = Hardware/driver issue
- `unmanaged` = NetworkManager not managing it

#### D. Active Connections
```bash
nmcli connection show --active
```
**Look for**: Is "SpectrumSetup-39" or any WiFi connection listed?

#### E. WiFi Interface
```bash
ip link show wlp195s0
ip addr show wlp195s0
```
**Look for**: 
- Interface state: `UP` or `DOWN`
- IP address: Should have one if connected
- Mode: `DORMANT` may indicate not fully active

#### F. Driver Modules
```bash
lsmod | grep -i -E "(mt792|mt76|mac80211|cfg80211)"
```
**Look for**: Are WiFi driver modules loaded?

#### G. NetworkManager Logs
```bash
journalctl -u NetworkManager --since "boot" | tail -50
```
**Look for**: 
- Errors or warnings
- WiFi connection attempts
- Hardware detection issues
- D-Bus errors

#### H. Boot Timing
```bash
systemd-analyze blame | grep -i networkmanager
```
**Look for**: Is NetworkManager taking too long to start?

### Step 3: Common Issues and Quick Fixes

#### Issue: WiFi Radio Disabled
```bash
nmcli radio wifi on
```

#### Issue: NetworkManager Not Running
```bash
sudo systemctl start NetworkManager
sudo systemctl status NetworkManager
```

#### Issue: WiFi Device Unavailable
```bash
# Check if hardware is detected
lspci | grep -i network
lsusb | grep -i network

# Check driver modules
lsmod | grep -i wifi

# Try reloading driver (if needed)
sudo modprobe -r mt7925e
sudo modprobe mt7925e
```

#### Issue: No Active Connection
```bash
# List available connections
nmcli connection show

# Try to connect manually
nmcli connection up "SpectrumSetup-39"
# Or
nmcli device wifi connect "SpectrumSetup-39" password "YOUR_PASSWORD"
```

#### Issue: GDM Not Showing Network Options
```bash
# Check GDM service
systemctl status gdm

# Check if NetworkManager applet is available
ls -la /run/current-system/sw/bin/nm-applet

# Check D-Bus permissions
systemctl status dbus
```

### Step 4: Compare with Generation 75

If you can boot into generation 75, run the same diagnostic script and compare:
```bash
# In gen 75
./WIFI_DIAGNOSTIC_COMMANDS.sh > wifi_diagnostic_gen75.txt

# Compare key outputs
diff <(grep "WiFi Radio Status" wifi_diagnostic_gen75.txt) <(grep "WiFi Radio Status" wifi_diagnostic_output.txt)
```

### Step 5: What to Report Back

When you have network access again, share:
1. Output from `WIFI_DIAGNOSTIC_COMMANDS.sh`
2. Specific error messages from NetworkManager logs
3. Whether WiFi connects automatically at boot
4. Whether GDM shows network options
5. Any differences you notice compared to gen 75

### Quick Manual Connection (If Needed)

If WiFi isn't connecting automatically, you can try:
```bash
# Enable WiFi radio
nmcli radio wifi on

# Scan for networks
nmcli device wifi list

# Connect to known network
nmcli device wifi connect "SpectrumSetup-39" password "YOUR_PASSWORD"

# Or use existing connection profile
nmcli connection up "SpectrumSetup-39"
```

### Notes

- All commands can be run without network connectivity
- The diagnostic script saves output to a file for later analysis
- Focus on NetworkManager service status and WiFi device state
- Check logs for timing issues or hardware detection problems

