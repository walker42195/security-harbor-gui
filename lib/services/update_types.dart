// Delade typer för desktop-appens självuppdatering (se update_service.dart).

/// Resultatet av en versionskontroll mot gui-repots release-manifest.
class DesktopUpdate {
  final String current;
  final String available;
  final bool updateAvailable;

  /// Nedladdnings-URL, sha256 och signatur för desktop-bunten (från manifestet).
  final String? url;
  final String? sha256;
  final String? sig;

  const DesktopUpdate({
    required this.current,
    required this.available,
    required this.updateAvailable,
    this.url,
    this.sha256,
    this.sig,
  });
}
