# Compatibility

Compatibility depends on the touchpad controller, not the laptop model. The controller refuses any device that is not PixArt `093A:4F05`.

## Verified

| Laptop | HID identity | Report descriptor |
|---|---|---|
| ASUS ExpertBook B9406CAA | `HID_ID=0018:0000093A:00004F05` | 964 bytes, SHA-256 `6f5470f0c99a355d00a380a4c3c0f5fd6fad1982ce2b18496a161172bdd297d4` |

Other ASUS laptops advertise haptic touchpads, but none has been shown to use this controller. A marketing name is not evidence.

## Check your laptop

```bash
cat /sys/class/dmi/id/product_name

for path in /sys/class/hidraw/hidraw*/device/uevent; do
  if grep -qx 'HID_ID=0018:0000093A:00004F05' "$path"; then
    dir=$(dirname "$path")
    echo "Found: $path"
    wc -c "$dir/report_descriptor"
    sha256sum "$dir/report_descriptor"
  fi
done
```

If nothing is found, the touchpad is not supported. If the device matches but the descriptor hash differs, treat it as a different hardware revision and do not apply settings until the descriptor has been reviewed.

## Verify on your machine

Force levels alone are hard to tell apart, so test with intensity first. Each step needs root and changes nothing permanently unless it says so.

1. **Dead-click test.** Apply Light at 0% without saving. The click should feel nearly dead, with no vibration. That proves both feature reports reach the firmware.

   ```bash
   sudo asus-b9406-hapticctl --click-force 1 --haptic-intensity 0
   ```

2. **Suspend test.** With that still applied, suspend, resume, and click again. Still dead means the firmware keeps settings across sleep, as the B9406CAA does.

   ```bash
   systemctl suspend
   ```

3. **Reboot test.** Restore your saved values, save Firm at 100%, reboot, and confirm the boot service applied them.

   ```bash
   sudo systemctl restart asus-b9406-haptic-touchpad.service
   sudo asus-b9406-hapticctl --save --click-force 3 --haptic-intensity 100
   sudo reboot
   journalctl -b -u asus-b9406-haptic-touchpad.service
   ```

   The log should end with `applied`.

4. **Force test.** Compare Light and Firm at the same intensity. The difference is a firmer press before the click registers, roughly 110 to 190 g.

## Adding a verified model

Open an issue with:

1. The DMI product name
2. The `HID_ID` line
3. Report descriptor size and SHA-256
4. The results of the four tests above
