# Haptic Touchpad for PixArt 093A:4F05

An Omarchy bar widget for the PixArt `093A:4F05` haptic touchpad, first verified in the ASUS ExpertBook B9406CAA. It controls the physical click threshold and haptic feedback strength, applies both immediately, and restores the selected values at startup.

> [!IMPORTANT]
> Compatibility is based on the touchpad hardware and HID report descriptor, not a laptop marketing name. **B9406CAA is currently the only model verified with exact device `093A:4F05`.** Other ASUS laptops advertise haptic touchpads, but that alone does not prove they use this controller.

[Read the compatibility evidence](COMPATIBILITY.md), then [follow the installation tutorial](TUTORIAL.md) for hardware checks, controller setup, plugin installation, testing, troubleshooting, and removal.

## What it controls

| Setting | Values | Effect |
|---|---:|---|
| Click force | Light, Medium, Firm | Changes how much physical pressure triggers a click. Firm helps prevent accidental clicks. |
| Haptic intensity | 0–100% | Changes the strength of the vibration produced for a click. |

These controls are independent. Click force changes the trigger threshold; haptic intensity changes how strong the feedback feels after the threshold is crossed.

## How it works

The solution has two parts:

1. The Omarchy plugin provides the `TP` bar widget and settings panel.
2. The root-owned `asus-b9406-hapticctl` controller validates values, sends HID feature reports to the exact PixArt device, and saves the selected values for a systemd service to restore at boot.

The plugin reads status without privilege. **Apply settings** invokes only `/usr/local/bin/asus-b9406-hapticctl` through Polkit with validated numeric arguments. Plugin-owned code never runs as root.

## Requirements

- PixArt internal HID touchpad `093A:4F05`
- A matching HID report descriptor; the verified descriptor is 964 bytes with SHA-256 `6f5470f0c99a355d00a380a4c3c0f5fd6fad1982ce2b18496a161172bdd297d4`
- Omarchy with plugin support
- `haptic-click-control` version **1.1.0 or newer** from that checkout
- On B9406CAA, `touchpad-fix` from the compatible `asus-expertbook-linux` checkout

The companion `haptic-click-control` module currently exists in the patched checkout used to develop this plugin and has not yet been merged into the upstream [`burakgon/asus-expertbook-linux`](https://github.com/burakgon/asus-expertbook-linux) repository. A public plugin release should wait until both repositories are published at stable URLs.

## Quick installation on B9406CAA

If both source trees are already present locally:

```bash
cd ~/asus-expertbook-linux
sudo ./patch.sh install touchpad-fix
sudo ./patch.sh install haptic-click-control

omarchy plugin add file://$HOME/dev/omaplugins/haptic-touchpad --enable --yes
```

Verify the controller before opening the panel:

```bash
asus-b9406-hapticctl --status --json
systemctl is-active asus-b9406-haptic-touchpad.service
```

The first command must return JSON with `"ok": true`; the second must print `active`.

## Using the widget

- Left-click `TP` to open the panel.
- Right-click `TP` to refresh controller status.
- Choose **Light**, **Medium**, or **Firm**.
- Adjust haptic intensity.
- Select **Apply settings** and approve the Polkit dialog.

The bar tooltip and panel show the saved requested values. The firmware rejects HID `GET_FEATURE`, so Linux cannot read the values back from the device itself. Apply still validates, saves, and transmits both settings.

## Development

Validate the project with:

```bash
bin/validate
```

This runs the JavaScript model tests, `omarchy plugin validate`, and Qt 6 `qmllint` with Omarchy’s runtime imports.

Useful IPC checks:

```bash
omarchy-shell shell summon io.github.bramvera.haptic-touchpad '{}'
omarchy-shell io.github.bramvera.haptic-touchpad status
omarchy-shell shell hide io.github.bramvera.haptic-touchpad
```

## Security

Omarchy plugins run unsandboxed in the desktop shell. Review the source before installation. This plugin builds process calls as argument arrays, accepts only the fixed controller path, and rejects click-force or intensity values outside the supported ranges.

## License

MIT
