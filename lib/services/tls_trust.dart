// Trust-on-first-use-hantering för brandväggens självsignerade
// HTTPS-certifikat. Väljer implementation vid kompileringstillfället:
// `dart:io`-varianten (SecureSocket, riktig fingeravtrycksjämförelse) på
// desktop/Android, webb-stubben (no-op) i en `flutter build web`, eftersom
// `dart:io` inte går att kompilera in i en web-build och webbläsaren ändå
// sköter TLS-tillit på egen hand där.
export 'tls_trust_stub.dart' if (dart.library.io) 'tls_trust_io.dart';
