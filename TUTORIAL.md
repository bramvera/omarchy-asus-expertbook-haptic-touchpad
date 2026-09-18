# Step-by-step setup for ASUS ExpertBook B9406CAA

This guide installs Linux control for the physical click threshold and haptic feedback strength of the PixArt `093A:4F05` touchpad, then adds the controls to the Omarchy bar.

## 1. Confirm the laptop model

Run:

```bash
cat /sys/class/dmi/id/product_name
```

Continue only if the result identifies the ASUS ExpertBook **B9406CAA**. This project does not claim support for similarly named ExpertBook models.

## 2. Confirm the touchpad hardware

Run this bounded scan of the local hidraw devices:

```bash
for path in /sys/class/hidraw/hidraw*/device/uevent; do
  if grep -qx 'HID_ID=0018:0000093A:00004F05' "$path"; then
    device=${path#/sys/class/hidraw/}
    printf '/dev/%s\n' "${device%%/*}"
  fi
done
```

Expected result:

```text
/dev/hidrawN
```

The final number varies between boots. The controller discovers it automatically; never hardcode the number in the configuration.

If nothing is printed, stop. The controller deliberately refuses unrecognized devices.

## 3. Obtain compatible source trees

You need:

- An `asus-expertbook-linux` checkout containing `haptic-click-control/module.sh`
- This `haptic-touchpad` Omarchy plugin repository

At the time of writing, the haptic controller changes are still in the developer’s patched checkout. Before a general release, publish that checkout or merge the module upstream and replace the source URLs in these instructions.

Check the controller source before continuing:

```bash
test -f "$HOME/asus-expertbook-linux/haptic-click-control/module.sh" && echo ready
```

It must print `ready`.

## 4. Install the touchpad compatibility fix

The existing `touchpad-fix` remains required. It masks malformed pressure axes that can make libinput reject cursor motion. The haptic controller does not remove that quirk or expose those malformed axes again.

```bash
cd "$HOME/asus-expertbook-linux"
sudo ./patch.sh install touchpad-fix
```

If it is already installed, the patcher updates or confirms it safely.

## 5. Install the haptic controller

From the same checkout:

```bash
sudo ./patch.sh install haptic-click-control
```

This installs:

| Path | Purpose |
|---|---|
| `/usr/local/bin/asus-b9406-hapticctl` | Validates and sends the HID settings |
| `/etc/asus-b9406-haptic-touchpad.conf` | Stores the requested values |
| `/etc/systemd/system/asus-b9406-haptic-touchpad.service` | Restores values during boot |

The module defaults to `CLICK_FORCE=3` because Firm is intended to reduce accidental clicks. A fresh install leaves haptic intensity unchanged until you save a value from the plugin or edit the configuration.

## 6. Verify the controller

Run:

```bash
/usr/local/bin/asus-b9406-hapticctl --status --json
systemctl is-enabled asus-b9406-haptic-touchpad.service
systemctl is-active asus-b9406-haptic-touchpad.service
```

A working controller returns JSON similar to:

```json
{
  "schemaVersion": 1,
  "ok": true,
  "device": "/dev/hidraw11",
  "clickForce": 3,
  "clickForceName": "firm",
  "hapticIntensity": null,
  "readbackAvailable": false,
  "applied": false,
  "saved": false
}
```

The hidraw number may differ. Both systemd checks should succeed with `enabled` and `active`.

## 7. Install the Omarchy plugin

For a published Git repository, review it and then run:

```bash
omarchy plugin add https://github.com/OWNER/omarchy-haptic-touchpad.git --enable
```

Replace the example URL with the actual published repository URL.

For the local development tree used on this laptop:

```bash
cd "$HOME/dev/omaplugins/haptic-touchpad"
bin/validate
omarchy plugin add "file://$HOME/dev/omaplugins/haptic-touchpad" --enable --yes
```

If it is already installed, update it instead:

```bash
omarchy plugin update io.github.bramvera.haptic-touchpad --yes
```

The plugin should appear as `TP` in the right section of the Omarchy bar.

## 8. Choose and apply settings

1. Left-click `TP`.
2. Choose **Light**, **Medium**, or **Firm** under Click Force.
3. Move Haptic Intensity to the desired percentage.
4. Select **Apply settings**.
5. Approve the Polkit dialog.

Start by comparing **Light** and **Firm** with the same intensity. This isolates the click threshold. Then keep the preferred click force and compare a low and high intensity to judge vibration strength.

Recommended starting point for accidental clicks:

```text
Click Force: Firm
Haptic Intensity: 100%
```

The settings apply immediately and are written to `/etc/asus-b9406-haptic-touchpad.conf` for the systemd service to restore at startup. No reboot is required for a change made from the panel.

## 9. Verify the saved values

Right-click `TP`, or run:

```bash
omarchy-shell io.github.bramvera.haptic-touchpad refresh
omarchy-shell io.github.bramvera.haptic-touchpad status
cat /etc/asus-b9406-haptic-touchpad.conf
```

For Firm at 100%, the plugin status should contain:

```json
{"available":true,"clickForce":3,"hapticIntensity":100}
```

The firmware does not support reliable `GET_FEATURE` reads. Status therefore reports the validated saved request rather than pretending it has read the current values from firmware.

## 10. Troubleshooting

### The panel says Unavailable and shows `unrecognized arguments: --json`

The installed controller is older than version 1.1.0. Update it and refresh the widget:

```bash
cd "$HOME/asus-expertbook-linux"
sudo ./patch.sh install haptic-click-control
omarchy-shell io.github.bramvera.haptic-touchpad refresh
```

### The panel says the controller is unavailable

Check the binary and service:

```bash
test -x /usr/local/bin/asus-b9406-hapticctl
/usr/local/bin/asus-b9406-hapticctl --status --json
systemctl status asus-b9406-haptic-touchpad.service --no-pager
```

### No Polkit dialog appears

Unlock the Omarchy session and try Apply again. Confirm the shell responds:

```bash
omarchy-shell shell ping
```

### The service fails after boot

Inspect its current boot log:

```bash
journalctl -b -u asus-b9406-haptic-touchpad.service --no-pager
```

The controller waits up to 12 seconds for the matching hidraw device during service startup.

### Firm and Light feel identical

Keep intensity fixed while comparing click-force levels. Click force changes the trigger threshold, while intensity changes feedback strength. The firmware offers no readback, so also confirm that Apply succeeded and the saved configuration changed.

### Cursor movement stops or becomes unreliable

Reinstall the separate compatibility quirk and restart the session:

```bash
cd "$HOME/asus-expertbook-linux"
sudo ./patch.sh install touchpad-fix
```

Do not remove the pressure-axis masking quirk in an attempt to enable haptic control; the HID feature reports used here are separate from libinput’s pressure-axis handling.

## Update

Update the controller from its checkout, then update the plugin:

```bash
cd "$HOME/asus-expertbook-linux"
git pull --ff-only
sudo ./patch.sh install haptic-click-control

omarchy plugin update io.github.bramvera.haptic-touchpad --yes
```

Only use `git pull` after the controller work is available from your checkout’s remote branch.

## Remove

Remove the Omarchy plugin:

```bash
omarchy plugin remove io.github.bramvera.haptic-touchpad
```

Remove boot-time controller application:

```bash
cd "$HOME/asus-expertbook-linux"
sudo ./patch.sh uninstall haptic-click-control
```

The module intentionally leaves `/etc/asus-b9406-haptic-touchpad.conf` in place so the preference can be restored later. Uninstalling does not reset the device immediately; it stops future boot-time writes.
