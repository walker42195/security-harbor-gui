import 'package:http/http.dart' as http;

export 'http_client_factory_web.dart' if (dart.library.io) 'http_client_factory_io.dart';

/// Typalias bara för dokumentationens skull vid importstället.
typedef HttpClientFactory = http.Client Function(Map<String, String> trustedFingerprints);
