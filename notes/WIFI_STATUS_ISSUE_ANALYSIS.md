# WiFi Status Issue Analysis - Noctalia Shell

**STATUS: ✅ RESOLVED**

The WiFi widget issue was fixed by ensuring `nmcli` is accessible in the Noctalia service PATH. The root cause was that `nmcli` was not found when NetworkService tried to scan for networks, causing the scan to fail silently and leaving `NetworkService.networks` empty.

**Solution Applied**:
- Added explicit PATH to `noctalia-shell` systemd service environment
- Included `/run/current-system/sw/bin` and NetworkManager binaries in PATH
- Added `PassEnvironment = [ "PATH" ];` to ensure PATH is inherited

The widget now correctly shows WiFi status (connected/disconnected).

---

## How Noctalia Queries WiFi Status

### NetworkService Implementation

Noctalia uses **`nmcli`** (NetworkManager command-line interface) to query WiFi status, **NOT D-Bus directly**. The implementation is in:
- `/nix/store/*noctalia-shell*/share/noctalia-shell/Services/Networking/NetworkService.qml`

### Key Functions:

1. **`syncWifiState()`** - Checks if WiFi adapter is enabled
   - Runs: `nmcli radio wifi`
   - Compares output to `"enabled"` string
   - Updates: `Settings.data.network.wifiEnabled` property
   - Called on: Component initialization and after WiFi state changes

2. **`scan()`** - Scans for available WiFi networks
   - Runs: `nmcli -t -f SSID,SECURITY,SIGNAL,IN-USE device wifi list --rescan yes`
   - Populates: `NetworkService.networks` object with discovered networks
   - Marks connected network with `connected: true` if `IN-USE` field contains `*`

### Widget Display Logic

The WiFi widget (in `Modules/Bar/Widgets/WiFi.qml`) shows icon based on:

```qml
icon: {
  if (NetworkService.ethernetConnected) {
    return NetworkService.internetConnectivity ? "ethernet" : "ethernet-off";
  }
  let connected = false;
  let signalStrength = 0;
  for (const net in NetworkService.networks) {
    if (NetworkService.networks[net].connected) {
      connected = true;
      signalStrength = NetworkService.networks[net].signal;
      break;
    }
  }
  return connected ? NetworkService.signalIcon(signalStrength, true) : "wifi-off";
}
```

**Key Finding**: The widget shows `"wifi-off"` when:
- `NetworkService.networks` is empty (no networks found), OR
- No network in `NetworkService.networks` has `connected: true`

**The widget does NOT check `Settings.data.network.wifiEnabled` for the icon display!**

## Root Cause Analysis

### The Problem

The WiFi widget shows "off" even though:
- WiFi adapter is enabled (`nmcli radio wifi` returns "enabled")
- WiFi is connected (active connection exists)
- `Settings.data.network.wifiEnabled` is `true`

### Why This Happens

The widget icon depends on `NetworkService.networks` having a connected network, but:

1. **Initial State**: On startup, `NetworkService.networks` starts as empty `{}`
2. **Scan Timing**: The scan happens asynchronously after component initialization
3. **Scan Failure**: If the scan fails or doesn't complete, `networks` remains empty
4. **State Mismatch**: `Settings.data.network.wifiEnabled` can be `true` while `networks` is empty

### Specific Issues to Check

1. **Scan Process Failure**
   - Check if `nmcli device wifi list` command is working
   - Check if scan process is completing successfully
   - Check for errors in Noctalia logs

2. **Network Detection**
   - The scan looks for `IN-USE` field containing `*` to mark connected networks
   - If `nmcli` output format changed or is different, connected networks might not be detected

3. **Timing Issues**
   - Widget might render before scan completes
   - Initial scan might be delayed or fail silently

4. **Settings Sync Issue**
   - `syncWifiState()` updates `Settings.data.network.wifiEnabled` from `nmcli radio wifi`
   - But widget doesn't use this setting for icon display
   - Widget only checks `NetworkService.networks` for connected status

## Potential Solutions

### Solution 1: Fix Widget Logic (Recommended)
Modify the widget to check `Settings.data.network.wifiEnabled` as a fallback:
- If WiFi is enabled but no networks found, show WiFi icon (not wifi-off)
- Only show wifi-off if WiFi is explicitly disabled

### Solution 2: Ensure Scan Completes
- Check why scan might be failing
- Ensure `nmcli` is available in PATH
- Check for permission issues with NetworkManager

### Solution 3: Improve State Detection
- Add a property that combines `wifiEnabled` AND network connection status
- Use this combined property for widget display

### Solution 4: Check nmcli Output Format
- Verify `nmcli device wifi list` output format matches expected parsing
- The code expects: `SSID:SECURITY:SIGNAL:IN-USE` format
- If format differs, parsing will fail

## Diagnostic Commands

Run these to diagnose the issue:

```bash
# Check if nmcli is available
which nmcli

# Check WiFi radio status
nmcli radio wifi

# Check if WiFi is connected
nmcli -t -f NAME,TYPE,DEVICE connection show --active | grep wifi

# Test scan command (what Noctalia uses)
nmcli -t -f SSID,SECURITY,SIGNAL,IN-USE device wifi list --rescan yes

# Check NetworkManager service
systemctl status NetworkManager

# Check user permissions
groups $USER | grep networkmanager
```

## Expected Behavior

1. On startup: `syncWifiState()` runs `nmcli radio wifi` → updates `Settings.data.network.wifiEnabled`
2. Then: `scan()` runs `nmcli device wifi list` → populates `NetworkService.networks`
3. Widget checks: `NetworkService.networks` for connected networks → shows appropriate icon

## Current System State

- ✅ WiFi adapter enabled: `nmcli radio wifi` returns "enabled"
- ✅ WiFi connected: Active connection "SpectrumSetup-39" on `wlp195s0`
- ✅ NetworkManager running: System service active
- ✅ User permissions: User in `networkmanager` group
- ✅ nmcli scan command works: `nmcli device wifi list` shows "SpectrumSetup-39:WPA2 WPA3:100:*" (the `*` indicates connected)
- ❓ NetworkService.networks: Unknown (need to check if scan is completing in Noctalia)

## Verified nmcli Output

The `nmcli` command that Noctalia uses works correctly:
```bash
$ nmcli -t -f SSID,SECURITY,SIGNAL,IN-USE device wifi list --rescan yes
SpectrumSetup-39:WPA2 WPA3:100:*    # * indicates connected
```

The parsing logic in NetworkService should detect the `*` and mark the network as `connected: true`.

## Next Steps

1. Check Noctalia logs for scan errors
2. Verify `nmcli device wifi list` output format
3. Test if scan process is completing
4. Check if `NetworkService.networks` is being populated
5. Consider modifying widget logic to use `Settings.data.network.wifiEnabled` as fallback

