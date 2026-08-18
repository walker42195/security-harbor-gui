// Web-varianten av tls_trust — webbläsaren sköter TLS-tillit själv (den
// visar sin egen certifikatvarning för ett självsignerat certifikat, som
// inte går att kringgå eller läsa av programmatiskt från Dart). Dessa
// funktioner anropas aldrig i praktiken på web (se ApiService: hoppar
// över hela TOFU-flödet när kIsWeb är sant), men måste ändå finnas här
// så att `dart:io`-importen i tls_trust_io.dart aldrig behöver kompileras
// in i en web-build.
Future<String?> probeCertificateSha256(String host, int port) async => null;

Future<String?> getTrustedFingerprint(String hostPort) async => null;

Future<void> setTrustedFingerprint(String hostPort, String fingerprint) async {}
