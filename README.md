# Haptic Touchpad

An [Omarchy](https://omarchy.org) bar widget for the PixArt `093A:4F05` haptic touchpad. It sets how hard you press before the touchpad clicks and how strong the click feedback feels. Settings apply immediately and are restored at startup.

Verified on the ASUS ExpertBook B9406CAA. Other laptops must have the same touchpad controller; see [COMPATIBILITY.md](COMPATIBILITY.md).

## Settings

| Setting | Values | Effect |
|---|---|---|
| Click force | Light, Medium, Firm | Pressure needed to trigger a click. Firm helps avoid accidental clicks. |
| Haptic intensity | 0–100% | Strength of the vibration produced by a click. |

## Requirements

- A PixArt `093A:4F05` touchpad (see [COMPATIBILITY.md](COMPATIBILITY.md) to check)
- Omarchy with plugin support
- The `haptic-click-control` module from [asus-expertbook-linux](https://github.com/burakgon/asus-expertbook-linux), version 1.1.0 or newer

The module installs a root-owned controller, `asus-b9406-hapticctl`, and a systemd service that restores the saved values at boot. The plugin only reads status and asks Polkit for approval when you apply settings. Plugin code never runs as root.

## Installation

Install the controller from a checkout of `asus-expertbook-linux`:

```bash
sudo ./patch.sh install haptic-click-control
```

On the B9406CAA also install `touchpad-fix`, which is a separate cursor-movement quirk for that model:

```bash
sudo ./patch.sh install touchpad-fix
```

Check that the controller works:

```bash
asus-b9406-hapticctl --status --json
systemctl is-active asus-b9406-haptic-touchpad.service
```

The first command prints JSON with `"ok": true` and the second prints `active`.

Then add the plugin:

```bash
omarchy plugin add <repository-url> --enable
```

The widget appears in the right section of the bar.

## Usage

- Left-click the icon to open the panel. Right-click to refresh.
- Pick **Light**, **Medium**, or **Firm**, set the intensity, and press **Apply settings**.
- Approve the Polkit dialog.

Keyboard: arrow keys change the values, Enter applies, Escape closes.

The touchpad firmware cannot report its current values, so the panel shows the values that were last saved.

## Troubleshooting

**The panel says the controller is unavailable.** Check the binary and service:

```bash
asus-b9406-hapticctl --status --json
systemctl status asus-b9406-haptic-touchpad.service
```

**The panel shows `unrecognized arguments: --json`.** The controller is older than 1.1.0. Reinstall it from an up-to-date checkout.

**No Polkit dialog appears.** Make sure the session is unlocked and the shell is running:

```bash
omarchy-shell shell ping
```

**Light and Firm feel identical.** Keep the intensity fixed while comparing click force. Click force changes the trigger threshold; intensity changes the feedback strength.

## Removal

```bash
omarchy plugin remove io.github.bramvera.haptic-touchpad
sudo ./patch.sh uninstall haptic-click-control   # from the asus-expertbook-linux checkout
```

Uninstalling the module stops boot-time restores but leaves `/etc/asus-b9406-haptic-touchpad.conf` in place.

## Development

```bash
bin/validate
```

This runs the model unit tests, `omarchy plugin validate`, and `qmllint`. Saving a file under `~/.config/omarchy/plugins/` hot-reloads the plugin.

IPC:

```bash
omarchy-shell io.github.bramvera.haptic-touchpad toggle
omarchy-shell io.github.bramvera.haptic-touchpad refresh
omarchy-shell io.github.bramvera.haptic-touchpad status
```

## License

MIT
