#!/bin/bash
# Security Harbor GUI - paketera och signera desktop-appen (Flutter Linux) för
# självuppdatering. Bygger en tarboll av linux-bundlen, signerar den (Ed25519,
# samma nyckel som agenten) och skriver ett manifest.json. Ladda upp
# desktop-tarbollen, .sig och manifest.json som GitHub Release-assets på
# gui-repot (releases/latest/download/... som update_service_io.dart hämtar).
#
# Webb-GUI:t byggs och buntas INTE här — det följer med agentens release
# (agentens build_release.sh kör flutter build web).
set -e

cd "$(dirname "$0")"

VERSION="$(grep -E '^version:' pubspec.yaml | head -1 | sed -E 's/version:[[:space:]]*//; s/\+.*//' | tr -d ' \r')"
[ -n "$VERSION" ] || { echo "kunde inte läsa version ur pubspec.yaml"; exit 1; }

SIGN_KEY="${SIGN_KEY:-$HOME/.config/security-harbor/release-signing.key}"
# Signeringsverktyget (Go) bor i agent-repot.
AGENT_DIR="${AGENT_DIR:-../security-harbor-agent}"
RELEASE_BASE="${RELEASE_BASE:-https://github.com/walker42195/security-harbor-gui/releases/download/v$VERSION}"

echo "=== 1. Bygger desktop-appen (flutter build linux --release), v$VERSION ==="
flutter build linux --release

BUNDLE="build/linux/x64/release/bundle"
[ -d "$BUNDLE" ] || { echo "hittar inte $BUNDLE"; exit 1; }

echo "=== 2. Paketerar bundlen som tarboll ==="
TARBALL="security-harbor-gui-linux.tar.gz"
rm -f "$TARBALL"
tar -czf "$TARBALL" -C "$BUNDLE" .
echo "-> $TARBALL"

echo "=== 3. Signerar (Ed25519) och skriver manifest.json ==="
if [ ! -f "$SIGN_KEY" ]; then
  echo "VARNING: signeringsnyckel saknas ($SIGN_KEY) - hoppar över signering/manifest." >&2
  exit 0
fi
SIGN_BIN="$(mktemp)"
( cd "$AGENT_DIR" && go build -o "$SIGN_BIN" ./cmd/security-harbor-sign )
SIG="$("$SIGN_BIN" -key "$SIGN_KEY" -in "$TARBALL")"
rm -f "$SIGN_BIN"
SHA="$(sha256sum "$TARBALL" | awk '{print $1}')"
cat > manifest.json <<EOF
{
  "desktop": {
    "version": "$VERSION",
    "url": "$RELEASE_BASE/$TARBALL",
    "sha256": "$SHA",
    "sig": "$SIG"
  }
}
EOF
echo "-> $TARBALL.sig, manifest.json"
echo "=== Klart: ladda upp $TARBALL, $TARBALL.sig och manifest.json som release-assets ==="
