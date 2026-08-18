import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;

/// Bygger en http.Client vars TLS-tillit avgörs av trust-on-first-use:
/// certifikatet accepteras bara om dess SHA-256-fingeravtryck matchar det
/// som redan sparats för host:port (se tls_trust.dart/ApiService). Kartan
/// måste vara synkront tillgänglig eftersom badCertificateCallback är en
/// SYNKRON callback — den kan inte invänta en SharedPreferences-läsning.
http.Client createHttpClient(Map<String, String> trustedFingerprints) {
  final inner = HttpClient()
    ..badCertificateCallback = (cert, host, port) {
      final fp = sha256.convert(cert.der).toString();
      return trustedFingerprints['$host:$port'] == fp;
    };
  return io_client.IOClient(inner);
}
