# security-harbor-gui

> 🇸🇪 Svensk version: [README.md](README.md)

Flutter-based admin interface for [Security Harbor](https://security.novabase.se/) — a firewall and network appliance system for Linux. Built for Linux Desktop (Arch/Debian/Ubuntu) and Android.

## Installation

**Linux Desktop — directly from GitHub (one line):**

```bash
curl -fsSL https://raw.githubusercontent.com/walker42195/security-harbor-gui/main/install.sh | bash
```

Automatically fetches the latest [Release](https://github.com/walker42195/security-harbor-gui/releases/latest), unpacks it, and installs it. Runs as a regular user (NOT sudo) — it only installs into your own home directory, no system changes.

**Linux Desktop — manually (e.g. if you've already downloaded the tarball):**

```bash
curl -fsSL -o security-harbor-gui-linux.tar.gz \
  https://github.com/walker42195/security-harbor-gui/releases/latest/download/security-harbor-gui-linux.tar.gz
mkdir -p security-harbor-gui && tar -xzf security-harbor-gui-linux.tar.gz -C security-harbor-gui
cd security-harbor-gui && ./install.sh
```

Both variants install the app to `~/.local/share/security-harbor-gui`, symlink `~/.local/bin/security-harbor-gui`, and create a `.desktop` shortcut. Update to a newer version by running the install command again — `install.sh` is idempotent and just overwrites the existing installation.

**Android:** download and install `security-harbor.apk` from [security.novabase.se](https://security.novabase.se/).

## Known Issues

### Flickering window (Chromebook/Crostini, some VMs)

If the window appears but graphics/icons/graphs flicker or periodically disappear, it's because Flutter's OpenGL rendering doesn't play well with a virtualized GPU (e.g. VirGL in Crostini, or other virtio-gpu-based environments). Run the app with forced software rendering and the X11 backend instead of Wayland:

```bash
GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1 security-harbor-gui
```

If that's stable, you can make it permanent, e.g. by adding these environment variables to the `Exec=` line in the `.desktop` file (`~/.local/share/applications/security-harbor-gui.desktop`):

```
Exec=env GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1 /home/<user>/.local/share/security-harbor-gui/security_harbor_gui
```

### Missing shared libraries in Crostini/minimal Debian containers

A minimal Crostini container often lacks the Mesa/EGL libraries Flutter's Linux engine requires. If the app crashes immediately with `Couldn't open libEGL.so.1` or `Couldn't open libGLESv2.so.2`:

```bash
sudo apt update
sudo apt install -y libegl1 libgl1 libglu1-mesa libgles2 libgtk-3-0
```

## Development

Standard Flutter commands:

```bash
flutter pub get
flutter run                  # run on a connected device
flutter build linux --release
flutter build apk --release
```

See `../security-harbor-marketing/deploy.sh` for the complete build and deployment flow (builds both the Linux and Android packages and publishes them on security.novabase.se).
