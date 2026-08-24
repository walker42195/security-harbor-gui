/// Desktop-appens version. Hålls i synk med `version:` i pubspec.yaml och
/// bumpas vid varje desktop-release (gui-repots build_release.sh signerar och
/// publicerar en matchande GitHub Release). Agenten och webb-GUI:t versioneras
/// separat (se agentens VERSION-fil).
const String kGuiVersion = '1.2.2';
