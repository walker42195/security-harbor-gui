#!/bin/bash
# Security Harbor GUI (desktop) - installer.
#
# Två körsätt:
#   1) Från en redan uppackad release-tarboll (security-harbor-gui-linux.tar.gz,
#      se build_release.sh) - den byggda "bundle"-katalogen ligger bredvid
#      skriptet.
#   2) Fristående, hämtad direkt från GitHub (self-bootstrap): om appens
#      binär INTE ligger bredvid skriptet laddar det ner senaste GitHub
#      Release-tarbollen automatiskt och fortsätter därifrån. Gör ett
#      riktigt en-rads-installationskommando möjligt:
#
#        curl -fsSL https://raw.githubusercontent.com/walker42195/security-harbor-gui/main/install.sh | bash
#
# Körs som VANLIG användare (inte root/sudo) - installerar bara i den egna
# hemkatalogen, ingen systemändring.
#
# Idempotent: kan köras om (t.ex. efter en manuell tarboll-uppdatering) utan
# att förstöra något - kopierar bara om filerna på nytt.
set -e

if [ "$(id -u)" -eq 0 ]; then
  echo "Kör INTE som root/sudo - detta installerar bara i din egen hemkatalog." >&2
  exit 1
fi

GITHUB_REPO="walker42195/security-harbor-gui"
INSTALL_DIR="$HOME/.local/share/security-harbor-gui"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"

# --- Self-bootstrap: hämta från GitHub om bundlen inte finns lokalt ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_DIR="$SCRIPT_DIR"
if [ ! -f "$SCRIPT_DIR/security_harbor_gui" ]; then
  echo "=== 0. Hämtar senaste release från GitHub (self-bootstrap) ==="
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  ARCHIVE_URL="https://github.com/${GITHUB_REPO}/releases/latest/download/security-harbor-gui-linux.tar.gz"
  if ! curl -fsSL "$ARCHIVE_URL" -o "$TMP_DIR/gui.tar.gz"; then
    echo "Kunde inte hämta $ARCHIVE_URL" >&2
    echo "(kräver att repot är publikt och att en release med den bifogade filen finns)" >&2
    exit 1
  fi
  mkdir -p "$TMP_DIR/bundle"
  tar -xzf "$TMP_DIR/gui.tar.gz" -C "$TMP_DIR/bundle"
  BUNDLE_DIR="$TMP_DIR/bundle"
  echo "-> Uppackat till $BUNDLE_DIR"
fi

if [ ! -f "$BUNDLE_DIR/security_harbor_gui" ]; then
  echo "Hittar inte $BUNDLE_DIR/security_harbor_gui - trasig bunt/release" >&2
  exit 1
fi

echo "=== 1. Installerar appen i $INSTALL_DIR ==="
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp -a "$BUNDLE_DIR/." "$INSTALL_DIR/"

echo "=== 2. Symlänkar $BIN_DIR/security-harbor-gui ==="
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/security_harbor_gui" "$BIN_DIR/security-harbor-gui"

echo "=== 3. Skapar skrivbordsgenväg ==="
mkdir -p "$DESKTOP_DIR"
ICON_PATH="$INSTALL_DIR/data/flutter_assets/assets/logo.png"
cat > "$DESKTOP_DIR/security-harbor-gui.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Security Harbor
Comment=Administrationsgränssnitt för Security Harbor
Exec=$BIN_DIR/security-harbor-gui
Icon=$ICON_PATH
Terminal=false
Categories=Network;Security;
EOF

echo ""
echo "=== Klart ==="
echo "Starta med: security-harbor-gui (om $BIN_DIR finns i din PATH), eller sök"
echo "efter \"Security Harbor\" i din applikationsmeny."
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "OBS: $BIN_DIR finns inte i din PATH - lägg till den i din shells profil (t.ex. ~/.bashrc)." ;;
esac
