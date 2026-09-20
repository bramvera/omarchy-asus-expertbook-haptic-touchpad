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

Force levels alone are hard to tell apart, so test with intensity first. The udev rule from the README must be in place. Nothing here changes anything permanently unless it says so.

```bash
ctl=~/.config/omarchy/plugins/io.github.bramvera.haptic-touchpad/controller/asus-b9406-hapticctl
```

1. **Dead-click test.** Apply Light at 0% without saving. The click should feel nearly dead, with no vibration. That proves both feature reports reach the firmware.

   ```bash
   $ctl --click-force 1 --haptic-intensity 0
   ```

2. **Suspend test.** With that still applied, suspend, resume, and click again. Still dead means the firmware keeps settings across sleep, as the B9406CAA does.

   ```bash
   systemctl suspend
   ```

3. **Reboot test.** Save Firm at 100%, reboot, and confirm the widget restored them when the shell started.

   ```bash
   $ctl --save --click-force 3 --haptic-intensity 100
   systemctl reboot
   omarchy-shell io.github.bramvera.haptic-touchpad status
   ```

   The status should report `"available":true` with click force 3 and intensity 100, and the click should feel firm and strong.

4. **Force test.** Compare Light and Firm at the same intensity. The difference is a firmer press before the click registers, roughly 110 to 190 g.

## Adding a verified model

Open an issue with:

1. The DMI product name
2. The `HID_ID` line
3. Report descriptor size and SHA-256
4. The results of the four tests above
