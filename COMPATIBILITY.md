# Hardware compatibility evidence

Compatibility is determined by the HID device and report layout. A laptop having a “haptic touchpad” does not establish that it uses PixArt `093A:4F05` or accepts feature reports 8 and 9.

The current controller checks the exact HID ID before opening a device and does not require a B9406CAA DMI name. That permits careful testing on a second model with matching hardware without weakening the device guard.

Research last checked: **2026-09-18**.

## Verified

| Laptop | HID identity | Report descriptor | Status |
|---|---|---|---|
| ASUS ExpertBook Ultra B9406CAA | `HID_ID=0018:0000093A:00004F05`, ACPI `ASCP1D80` | 964 bytes; SHA-256 `6f5470f0c99a355d00a380a4c3c0f5fd6fad1982ce2b18496a161172bdd297d4` | Click force 1–3 and intensity 0–100 tested |

Public evidence for the exact ID currently points to B9406CAA: the [`asus-expertbook-linux` hardware table](https://github.com/burakgon/asus-expertbook-linux), the [original Omarchy hardware report](https://github.com/omacom/omarchy/issues/5423), and Omarchy’s [hardware-specific installation script](https://github.com/omacom/omarchy/blob/9c5482c58dbe4974de337450754885083c91eada/install/hardware/asus/fix-asus-ptl-b9406-touchpad.sh).

A GitHub code search for [`093A:4F05`](https://github.com/search?q=%22093A%3A4F05%22&type=code) found the B9406CAA work and downstream copies of it, but no independently reported second laptop model.

## Haptic ASUS models without an exact hardware match

These are research candidates. ASUS confirms that they have haptic touchpads, but no public source found during this review identifies their controller as `093A:4F05` or shows the same report descriptor.

| Model | What ASUS confirms | Why it is not yet compatible |
|---|---|---|
| Zenbook Pro 16X OLED UX7602 | [150 × 90 mm LRA haptic touchpad with pressure sensors](https://www.asus.com/us/laptops/for-creators/zenbook/zenbook-pro-16x-oled-ux7602/) | No public `093A:4F05` hardware report found |
| ProArt P16 H7607 | [ASUS HapticPad](https://www.asus.com/us/laptops/for-creators/proart/proart-p16-h7607/) | No public controller ID or descriptor found |
| 2026 ProArt P14 and P16 | [Precision haptic touchpad](https://www.asus.com/us/news/asus-proart-ifa2026/) | Product announcement gives no controller ID |

They may use different vendors, firmware, report numbers, or transports. Do not send this controller’s feature reports based only on those product descriptions.

## Verify another model

Collect the model and exact HID evidence without following symlinks or scanning the whole filesystem:

```bash
printf 'Vendor: '; cat /sys/class/dmi/id/sys_vendor
printf 'Model:  '; cat /sys/class/dmi/id/product_name

for path in /sys/class/hidraw/hidraw*/device/uevent; do
  if grep -qx 'HID_ID=0018:0000093A:00004F05' "$path"; then
    device_dir=$(dirname "$path")
    device=${path#/sys/class/hidraw/}
    printf 'Device: /dev/%s\n' "${device%%/*}"
    cat "$path"
    wc -c "$device_dir/report_descriptor"
    sha256sum "$device_dir/report_descriptor"
  fi
done
```

Evidence required to add a verified model:

1. Exact DMI product name.
2. Exact `HID_ID=0018:0000093A:00004F05` match.
3. Report descriptor size and SHA-256.
4. Successful controlled comparison of click force 1 versus 3 at a fixed intensity.
5. Successful controlled comparison of low versus high intensity at a fixed click force.
6. Confirmation that the setting service works again after reboot.

If the device ID matches but the descriptor hash differs, treat it as a new hardware revision and inspect the descriptor before sending feature reports.
