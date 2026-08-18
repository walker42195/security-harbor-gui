# security-harbor-gui

Flutter-baserat administrationsgränssnitt för [Security Harbor](https://security.novabase.se/) — ett brandväggs- och nätverksappliance-system för Linux. Byggs för Linux Desktop (Arch/Debian/Ubuntu) och Android.

## Installation

**Linux Desktop:**

```bash
tar -xzf security-harbor-gui-linux-x64.tar.gz -C ~/security-harbor-gui
cd ~/security-harbor-gui && ./install.sh
```

Detta installerar appen i `~/.local/share/security-harbor-gui`, symlänkar `~/.local/bin/security-harbor-gui` och skapar en `.desktop`-genväg.

**Android:** ladda ner och installera `security-harbor.apk` från [security.novabase.se](https://security.novabase.se/).

## Kända problem

### Fönstret flimrar / blinkar (Chromebook/Crostini, vissa VM:ar)

Om fönstret dyker upp men grafik/ikoner/grafer flimrar eller försvinner periodiskt beror det på att Flutters OpenGL-rendering inte samspelar bra med en virtualiserad GPU (t.ex. VirGL i Crostini, eller andra virtio-gpu-baserade miljöer). Kör appen med tvingad mjukvaru-rendering och X11-backend istället för Wayland:

```bash
GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1 security-harbor-gui
```

Om det är stabilt går det att göra permanent, t.ex. genom att lägga till dessa miljövariabler i `.desktop`-filens `Exec=`-rad (`~/.local/share/applications/security-harbor-gui.desktop`):

```
Exec=env GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1 /home/<användare>/.local/share/security-harbor-gui/security_harbor_gui
```

### Saknade delade bibliotek i Crostini/minimala Debian-behållare

En minimal Crostini-container saknar ofta Mesa/EGL-biblioteken som Flutters Linux-motor kräver. Om appen kraschar direkt med `Couldn't open libEGL.so.1` eller `Couldn't open libGLESv2.so.2`:

```bash
sudo apt update
sudo apt install -y libegl1 libgl1 libglu1-mesa libgles2 libgtk-3-0
```

## Utveckling

Standard Flutter-kommandon:

```bash
flutter pub get
flutter run                  # kör på ansluten enhet
flutter build linux --release
flutter build apk --release
```

Se `../security-harbor-marketing/deploy.sh` för det fullständiga bygg- och driftsättningsflödet (bygger både Linux- och Android-paket och publicerar dem på security.novabase.se).
