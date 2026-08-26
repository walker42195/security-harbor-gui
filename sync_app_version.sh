#!/bin/bash
# Genererar lib/app_version.dart ur pubspec.yaml.
#
# kGuiVersion var tidigare en handunderhållen konstant som skulle "hållas i
# synk med pubspec.yaml". Den invarianten höll inte: den bumpades senast för
# 2.2.0 och följde aldrig med till 2.3.0 eller 2.3.1, som bara ändrade
# pubspec. Följden blev att desktop-appen rapporterade 2.2.0 hur många gånger
# den än uppdaterades — självuppdateringen installerade rätt bunt, men
# versionspanelen visade fortfarande "Nu: 2.2.0 • Senaste: 2.3.1" och erbjöd
# samma uppdatering i all oändlighet (rapporterat 2026-08-26).
#
# Körs av build_release.sh i BÅDA repona: gui-repot bygger desktop-appen,
# agent-repot bygger webb-GUI:t ur samma källkod.
set -e

cd "$(dirname "$0")"

VERSION="$(grep -E '^version:' pubspec.yaml | head -1 | sed -E 's/version:[[:space:]]*//; s/\+.*//' | tr -d ' \r')"
[ -n "$VERSION" ] || { echo "kunde inte läsa version ur pubspec.yaml" >&2; exit 1; }

cat > lib/app_version.dart <<DART
/// Desktop- och webb-GUI:ts version.
///
/// GENERERAD AV sync_app_version.sh UR pubspec.yaml - redigera inte för hand.
/// Bumpa \`version:\` i pubspec.yaml i stället; build_release.sh regenererar
/// den här filen vid varje release. Agenten versioneras separat (VERSION-filen
/// i agent-repot).
const String kGuiVersion = '$VERSION';
DART

echo "-> lib/app_version.dart = $VERSION"
