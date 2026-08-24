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
// Returnerar (fingeravtryck, felmeddelande) — ETT av de två är alltid
// null. Ett fel returneras numera EXPLICIT (i stället för att bara ge
// null och låta anroparen anta "servern är nere") sedan en riktig bugg
// hittades 2026-08-24: om proben av någon anledning misslyckas TYST (utan
// att onBadCertificate hinner fyra i `captured`, t.ex. ett plattforms-
// specifikt nätverksfel på en viss Android-enhet/VPN-kombination) tolkade
// checkServerCertificate() detta som "skipped" och lät inloggningen
// fortsätta ändå — men då är certifikatet ALDRIG markerat som betrott i
// _trustedFingerprints, så den RIKTIGA anslutningens egen
// badCertificateCallback avvisar det självsignerade certifikatet tyst.
// Resultatet var ett förvirrande "Inloggning misslyckades" helt utan
// förklaring, utan att någon certifikat-dialog någonsin visades.
Future<(String?, String?)> probeCertificateSha256(String host, int port) async {
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
  } catch (e) {
    return (null, e.toString());
  }

  final cert = captured;
  if (cert == null) return (null, 'Anslutningen avbröts innan certifikatet kunde läsas (ingen ytterligare information tillgänglig).');
  return (sha256.convert(cert.der).toString(), null);
}

Future<String?> getTrustedFingerprint(String hostPort) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('$_prefsPrefix$hostPort');
}

Future<void> setTrustedFingerprint(String hostPort, String fingerprint) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('$_prefsPrefix$hostPort', fingerprint);
}
