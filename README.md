# Haptic Touchpad

An Omarchy bar widget for the ASUS ExpertBook B9406CAA PixArt `093A:4F05` haptic touchpad. It controls the click-force threshold and haptic feedback intensity, then persists both settings for startup.

## Requirements

- Omarchy with plugin support
- ASUS ExpertBook B9406CAA with the supported PixArt touchpad
- The root-owned `asus-b9406-hapticctl` controller from [`asus-expertbook-linux`](https://github.com/burakgon/asus-expertbook-linux)

Install the controller before enabling the plugin:

```bash
cd ~/asus-expertbook-linux
sudo ./patch.sh install haptic-click-control
```

The plugin reads status without privilege. Apply uses Polkit to run the fixed root-owned controller at `/usr/local/bin/asus-b9406-hapticctl`; it never runs plugin code as root.

## Install

From a published repository:

```bash
omarchy plugin add https://github.com/bramvera/omarchy-haptic-touchpad --enable
```

For local development:

```bash
omarchy plugin add file://$HOME/dev/omaplugins/haptic-touchpad --enable
```

Left-click the `TP` bar widget to open the controls. Right-click refreshes status. Pick Light, Medium, or Firm, adjust intensity, and select **Apply settings**. Omarchy will show a Polkit approval dialog.

The firmware does not expose reliable setting readback. The panel therefore shows the validated settings saved in `/etc/asus-b9406-haptic-touchpad.conf`, while Apply also sends the values to the device immediately.

## Develop and validate

Changes hot reload from the installed plugin copy. Validate the source tree with:

```bash
bin/validate
```

The validation script runs the model tests, `omarchy plugin validate`, and Qt 6 `qmllint` with Omarchy's runtime imports.

Useful IPC checks:

```bash
omarchy-shell shell summon io.github.bramvera.haptic-touchpad '{}'
omarchy-shell shell hide io.github.bramvera.haptic-touchpad
omarchy-shell io.github.bramvera.haptic-touchpad status
```

Remove the plugin with:

```bash
omarchy plugin remove io.github.bramvera.haptic-touchpad
```

## Security

Omarchy plugins run unsandboxed in the desktop shell. Review the plugin before installing it. This plugin constructs process calls as argument arrays and accepts only the fixed installed controller path and validated numeric ranges.

## License

MIT
