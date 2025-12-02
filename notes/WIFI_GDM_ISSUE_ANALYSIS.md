# WiFi and GDM Network Options Issue - Generation 75 to 76

## Issue Summary
- **Reported**: WiFi not working and GDM not showing network options after upgrade from generation 75 to 76
- **Current Status**: WiFi is actually working (connected, has IP, internet connectivity works)
- **Timing**: Issue may be boot-time related (WiFi not connecting automatically at boot)

## Investigation Results

### Current System State (Generation 76)
- ✅ NetworkManager service: Running
- ✅ WiFi radio: Enabled
- ✅ WiFi device: `wlp195s0` is UP and connected to "SpectrumSetup-39"
- ✅ Internet connectivity: Working (can ping 8.8.8.8)
- ✅ WiFi driver modules: Loaded (mt7925e, mt76, mac80211, cfg80211)
- ✅ NetworkManager packages: Identical between gen 75 and 76
- ⚠️ WiFi interface state: `UP mode DORMANT` (interface is up but may not be actively transmitting)

### Comparison Between Generations
- **NixOS Version**: Both on 25.11.650.8bb5646e0bed
- **Kernel**: Both on 6.17.9
- **NetworkManager packages**: Identical (networkmanager-1.54.1, network-manager-applet-1.36.0)
- **NetworkManager configuration**: Identical

### Potential Causes

1. **Boot-time Timing Issue**
   - WiFi may not be connecting automatically at boot
   - NetworkManager may be starting before WiFi hardware is ready
   - GDM may be starting before NetworkManager is fully initialized

2. **GDM Network UI Issue**
   - GDM's network options UI may not be displaying even though WiFi works
   - This could be a D-Bus or permissions issue
   - May need explicit NetworkManager configuration for GDM

3. **NixOS 25.11 Changes**
   - Display manager options moved from `services.xserver.*` to `services.*`
   - NetworkManager VPN plugins now require explicit configuration (but shouldn't affect basic WiFi)
   - GDM may need additional configuration to show network options

## Diagnostic Commands Run

```bash
# NetworkManager status
systemctl status NetworkManager  # ✅ Running

# WiFi status
nmcli radio wifi  # ✅ enabled
nmcli device status  # ✅ wlp195s0 connected
nmcli connection show --active  # ✅ SpectrumSetup-39 connected

# Internet connectivity
ping -c 3 8.8.8.8  # ✅ Working

# WiFi driver modules
lsmod | grep -i wifi  # ✅ mt7925e, mt76 loaded

# NetworkManager packages
nix-store --query --requisites /nix/var/nix/profiles/system-76-link | grep networkmanager
# ✅ Same packages in both generations
```

## Recommended Actions

### 1. Check Boot-time Behavior
If WiFi doesn't connect automatically at boot, check:
```bash
# Check NetworkManager startup logs
journalctl -u NetworkManager --since "boot" | grep -i -E "(wifi|wlan|error|fail)"

# Check if WiFi connects automatically
nmcli connection show --active | grep wifi
```

### 2. Verify GDM Network UI
GDM should show network options in the login screen. If it doesn't:
- Check GDM logs: `journalctl -u gdm --since "boot"`
- Verify NetworkManager D-Bus service is accessible to GDM
- Check if `network-manager-applet` is available to GDM

### 3. Explicit NetworkManager Configuration
While not required for basic WiFi, you may want to explicitly configure NetworkManager:
```nix
networking.networkmanager = {
  enable = true;
  wifi.backend = "wpa_supplicant";  # Already default, but explicit is clearer
};
```

### 4. Check for Timing Issues
If WiFi doesn't connect at boot, you may need to ensure NetworkManager waits for hardware:
```nix
systemd.services.NetworkManager = {
  after = [ "network-pre.target" "dbus.service" ];
  wants = [ "network-pre.target" ];
};
```

## Next Steps

1. **Test boot behavior**: Reboot and check if WiFi connects automatically
2. **Check GDM UI**: Verify if network options appear in GDM login screen
3. **Review logs**: Check boot-time logs for NetworkManager/WiFi errors
4. **Compare with gen 75**: If possible, boot into gen 75 and compare behavior

## Notes

- WiFi is currently working, so this may be a boot-time or UI display issue
- Both generations have identical NetworkManager packages, so the issue is likely configuration-related
- GDM network UI not showing could be a separate issue from WiFi connectivity

