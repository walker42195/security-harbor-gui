import 'package:http/http.dart' as http;

/// Web-varianten: webbläsarens fetch/XHR-lager sköter TLS-tillit helt på
/// egen hand (visar sin egen certifikatvarning för ett självsignerat
/// certifikat) — det finns ingen `badCertificateCallback`-motsvarighet att
/// koppla in på web, så trustedFingerprints ignoreras här.
http.Client createHttpClient(Map<String, String> trustedFingerprints) => http.Client();
