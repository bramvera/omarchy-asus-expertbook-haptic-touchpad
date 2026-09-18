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

## Adding a verified model

Open an issue with:

1. The DMI product name
2. The `HID_ID` line
3. Report descriptor size and SHA-256
4. Confirmation that Light and Firm feel different at the same intensity
5. Confirmation that low and high intensity feel different at the same click force
6. Confirmation that the settings survive a reboot
