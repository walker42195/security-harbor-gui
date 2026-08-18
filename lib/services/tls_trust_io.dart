import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _prefsPrefix = 'tls_trust_';

/// Öppnar en TLS-handskakning mot host:port ENDAST för att läsa
/// serverns certifikat — vi avvisar den avsiktligt (returnerar false i
/// onBadCertificate) eftersom vi bara vill peka på fingeravtrycket, inte
/// faktiskt använda anslutningen. Detta är den enda inbyggda vägen i
/// dart:io att komma åt ett självsignerat certifikat innan man bestämt
/// sig för att lita på det (trust-on-first-use).
Future<String?> probeCertificateSha256(String host, int port) async {
  X509Certificate? captured;
  try {
    final socket = await SecureSocket.connect(
      host,
      port,
      onBadCertificate: (cert) {
        captured = cert;
        return false;
      },
      timeout: const Duration(seconds: 5),
    );
    // Skulle inte kunna hända (onBadCertificate returnerade false ovan
    // borde avbryta handskakningen), men stäng ändå om vi mot förmodan
    // hamnar här.
    socket.destroy();
  } on HandshakeException {
    // Förväntat — vi avvisade avsiktligt certifikatet ovan.
  } catch (_) {
    return null;
  }

  final cert = captured;
  if (cert == null) return null;
  return sha256.convert(cert.der).toString();
}

Future<String?> getTrustedFingerprint(String hostPort) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('$_prefsPrefix$hostPort');
}

Future<void> setTrustedFingerprint(String hostPort, String fingerprint) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('$_prefsPrefix$hostPort', fingerprint);
}
