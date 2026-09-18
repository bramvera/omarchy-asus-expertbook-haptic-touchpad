# Haptic Touchpad

An [Omarchy](https://omarchy.org) bar widget for the PixArt `093A:4F05` haptic touchpad. It sets how hard you press before the touchpad clicks and how strong the click feedback feels. Settings apply immediately and are restored at startup.

Verified on the ASUS ExpertBook B9406CAA. Other laptops must have the same touchpad controller; see [COMPATIBILITY.md](COMPATIBILITY.md).

## Settings

| Setting | Values | Effect |
|---|---|---|
| Click force | Light, Medium, Firm | Pressure needed to trigger a click, roughly 110 to 190 g. Firm helps avoid accidental clicks. |
| Haptic intensity | 0–100% | Strength of the vibration produced by a click. |

## How it works

The repository has two parts:

- **The bar widget** (`Panel.qml` and friends) runs inside the Omarchy shell as an ordinary user. It reads the saved settings and shows the panel.
- **The controller** (`controller/asus-b9406-hapticctl`) is a small Python script with no dependencies beyond the standard library. It sends HID feature reports to the touchpad through the kernel's hidraw interface. A systemd unit runs it at boot to restore the saved values.

No kernel module or driver is needed. The touchpad already works with the in-tree `hid-multitouch` driver. The widget never runs as root: pressing **Apply settings** invokes the controller through Polkit with validated numeric arguments.

## Why Omarchy does not already do this

Checked on 2026-09-18 against Omarchy 4.0.4 with kernel 7.2.5-3-omarchy.

**Omarchy's haptic support is Dell-only.** The Trigger > Hardware > Touchpad Haptics menu calls `dell-xps-touchpad-haptics`, a package Omarchy installs only when `omarchy-hw-dell-xps-haptic-touchpad` matches a Dell XPS. Nothing in Omarchy speaks to the PixArt controller. The only ASUS B9406 touchpad handling in Omarchy is a libinput quirk that fixes cursor movement; it never writes to the device.

**The kernel exposes the haptics of this touchpad, but not these two settings.** Linux 6.18 added HID haptic touchpad support, and the Omarchy kernel builds it in. That support covers host-initiated feedback: user space can play press and release waveforms through the force-feedback interface. The kernel driver also refuses to treat this touchpad as a haptic touchpad at all. The device declares no haptic waveforms or triggers for the host to play, and it reports press force without a physical unit, both of which the driver requires. The touchpad input device therefore advertises no force-feedback capability.

The two settings this plugin changes are standard HID feature reports that the kernel simply has no interface for:

| Report | HID usage | Meaning |
|---|---|---|
| 8 | Digitizer page, `0xB0` Button Press Threshold | Click force |
| 9 | Haptics page, `0x23` Intensity | Haptic intensity |

These are "device-initiated" knobs: the touchpad decides when to click and how hard to vibrate, and the host only adjusts the thresholds. A June 2026 proposal on the linux-input list to expose exactly these two usages was still an open RFC at the time of writing, with the maintainer preferring the host-initiated model. Until something like it lands, the only way to set them on Linux is to write the feature reports directly, which is what the controller here does through hidraw. Windows exposes the same two knobs as the "Touchpad feedback" and click-pressure settings.

## Why this needs root

The touchpad's hidraw device node is owned by root with no group or world access. Sending it a feature report means opening that node for writing, and the kernel allows only root to do so. Everything privileged in this plugin exists to cross that one line as narrowly as possible.

What runs as root, and when:

| When | What runs | Why |
|---|---|---|
| Once, at install | `controller/install` | Copies the controller and boot service into `/usr/local/bin` and `/etc/systemd/system`, and enables the service. |
| At every boot | `asus-b9406-hapticctl --wait 12` | Re-sends the saved values, because the touchpad forgets them when powered off. |
| Each time you press Apply | `pkexec asus-b9406-hapticctl --save --click-force N --haptic-intensity N --json` | Writes the two values to the device and saves them. Polkit shows a dialog every time. |

What never runs as root: the widget itself. It lives in the Omarchy shell as your user and only reads status. The command it hands to Polkit is a fixed absolute path plus two integers that the widget has already range-checked, built as an argument list with no shell involved.

What the controller does with root: it opens only the one hidraw device whose HID id is `0018:0000093A:00004F05`, writes two single-byte feature reports (report 8 for click force, report 9 for intensity), and writes one file, `/etc/asus-b9406-haptic-touchpad.conf`. It has no network access, imports only the Python standard library, and is about 270 lines. The boot service runs with `ProtectHome`, `PrivateTmp`, and `NoNewPrivileges`.

Read `controller/asus-b9406-hapticctl` and `controller/install` before running them. That is the whole privileged surface.

## Requirements

- A PixArt `093A:4F05` touchpad. Run the check in [COMPATIBILITY.md](COMPATIBILITY.md) if unsure.
- Omarchy with plugin support.
- Python 3, which Omarchy already ships.

## Installation

### Step 0: if you came here on a fresh Omarchy install

If you just installed Omarchy on a B9406CAA and the touchpad clicks but the cursor does not move, stop here first. That is not a haptics problem and this plugin cannot fix it.

Omarchy ships the right fix but puts it in the wrong place. Its install script writes a libinput quirk to `/etc/libinput/asus-expertbook-b9406.quirks`, and libinput reads only `/etc/libinput/local-overrides.quirks` from that directory, so the fix is never loaded. Checked on Omarchy 4.0.4 with libinput 1.31.3 using `libinput quirks list --verbose`. The Omarchy tag `v4.0.4` and the current default branch both still write the ignored filename. Upstream knows: [PR #6388](https://github.com/omacom/omarchy/pull/6388) carries the fix and was still open at the time of writing.

You have two ways to get the cursor moving. Skip this step if it already works.

Either install the `touchpad-fix` module from [asus-expertbook-linux](https://github.com/burakgon/asus-expertbook-linux), which writes the right file:

```bash
git clone https://github.com/burakgon/asus-expertbook-linux.git
cd asus-expertbook-linux
sudo ./patch.sh install touchpad-fix
```

Or write the file yourself, then log out and back in:

```bash
sudo tee /etc/libinput/local-overrides.quirks >/dev/null <<'QUIRK'
[ASUS ExpertBook B9406 Touchpad]
MatchBus=i2c
MatchUdevType=touchpad
MatchVendor=0x093A
MatchProduct=0x4F05
MatchDMIModalias=dmi:*svnASUS*:pn*B9406*
AttrEventCode=-ABS_MT_PRESSURE;-ABS_PRESSURE;
QUIRK
```

Either way, the rule only tells libinput to ignore the touchpad's broken pressure axes. This step goes away once Omarchy renames its file.

### Step 1: add the plugin

Add the plugin. The Omarchy installer clones the repository and never runs anything as root:

```bash
omarchy plugin add <repository-url> --enable
```

### Step 2: install the controller

Run the installer from the cloned plugin directory. It needs root because it writes to `/usr/local/bin` and `/etc`:

```bash
sudo ~/.config/omarchy/plugins/io.github.bramvera.haptic-touchpad/controller/install
```

The installer refuses to continue if no matching touchpad is present. On success it prints the current settings and the uninstall command and the widget appears in the right section of the bar. Right-click the icon if it was already showing "controller unavailable".


## Usage

- Left-click the icon to open the panel. Right-click to refresh.
- Pick **Light**, **Medium**, or **Firm**, set the intensity, and press **Apply settings**.
- Approve the Polkit dialog.

Keyboard: arrow keys change the values, Enter applies, Escape closes.

The touchpad firmware cannot report its current values, so the panel shows the values that were last saved.

Without the panel, the same settings can be changed from a terminal. The controller keeps them in `/etc/asus-b9406-haptic-touchpad.conf` and the boot service re-applies that file:

```bash
sudo asus-b9406-hapticctl --click-force 2 --haptic-intensity 80          # try without saving
sudo asus-b9406-hapticctl --save --click-force 3 --haptic-intensity 100  # apply and save
```

## Troubleshooting

**The panel says the controller is unavailable.** Check the binary and service:

```bash
asus-b9406-hapticctl --status --json
systemctl status asus-b9406-haptic-touchpad.service
```

If either fails, run `controller/install` again.

**No Polkit dialog appears.** Make sure the session is unlocked and the shell is running:

```bash
omarchy-shell shell ping
```

**Light and Firm feel similar.** They only move the click threshold, so the difference is subtle. To confirm intensity works, compare 0% and 100%.

**Settings do not survive a reboot.** Suspend and resume are fine: the firmware keeps both values across sleep, verified on the B9406CAA. A full power cycle resets them, which is what the boot service is for. Check its log:

```bash
journalctl -b -u asus-b9406-haptic-touchpad.service
```

## Removal

Two steps, in either order. Omarchy removes the plugin files; the uninstaller removes the controller and boot service it installed:

```bash
omarchy plugin remove io.github.bramvera.haptic-touchpad
sudo asus-b9406-haptic-touchpad-uninstall
```

The uninstaller is placed in `/usr/local/bin` during installation, so it still works after the plugin directory is gone. The saved settings file `/etc/asus-b9406-haptic-touchpad.conf` is kept.

## Development

```bash
bin/validate
```

This runs the model unit tests, `omarchy plugin validate`, `qmllint`, and syntax checks for the controller and install scripts. Saving a file under `~/.config/omarchy/plugins/` hot-reloads the plugin. Changing `entryPoints` in the manifest needs `omarchy-restart-shell`.

IPC:

```bash
omarchy-shell io.github.bramvera.haptic-touchpad toggle
omarchy-shell io.github.bramvera.haptic-touchpad refresh
omarchy-shell io.github.bramvera.haptic-touchpad status
```

## License

MIT
