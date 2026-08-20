import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/config_model.dart';
import 'http_client_factory.dart';
import 'tls_trust.dart' as tls_trust;

/// Resultatet av en TOFU-certifikatkontroll (se ApiService.checkServerCertificate).
enum TlsTrustStatus { trustedMatch, newUnknown, mismatch, skipped }

class TlsCheckResult {
  final TlsTrustStatus status;
  final String? fingerprint; // Vid newUnknown: det nya. Vid mismatch: det NYA (aktuella).
  final String? expectedFingerprint; // Endast vid mismatch: det tidigare sparade.
  TlsCheckResult(this.status, {this.fingerprint, this.expectedFingerprint});
}

class ApiService {
  String baseUrl;
  String? token;

  // Trust-on-first-use: fingeravtrycket måste finnas SYNKRONT i minnet
  // eftersom badCertificateCallback (i http_client_factory_io.dart) är en
  // synkron callback — den kan inte invänta en SharedPreferences-läsning.
  // _client fångar EXAKT den här map-instansen via referens, så att
  // uppdatera den (trustFingerprint) räcker — ingen ombyggnad av klienten
  // behövs.
  final Map<String, String> _trustedFingerprints = {};
  late final http.Client _client = createHttpClient(_trustedFingerprints);

  // Ingen riktig servers LAN-IP som standardvärde här — appen distribueras
  // publikt, och ett hop-kodat internt IP hade läckt nätverkstopologi till
  // varje nedladdning. Användaren anger sin egen brandväggs adress i
  // Settings-vyn. https:// som standard eftersom Management-API:t numera
  // alltid kräver TLS (Fas 8+, se pkg/api/server.go).
  ApiService({this.baseUrl = 'https://localhost:8443'}) {
    // På web är GUI:t alltid samma-origin med agenten (serveras direkt
    // från dess --webui-dir) — ignorera en ev. sparad/inskriven URL helt
    // och använd relativa anrop, annars skulle t.ex. Settings-fältet
    // kunna peka fel och orsaka onödiga CORS-problem.
    if (kIsWeb) baseUrl = '';
  }

  void setBaseUrl(String newUrl) {
    if (kIsWeb) return;
    var formatted = newUrl.trim();
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'https://$formatted';
    }
    if (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    baseUrl = formatted;
    token = null;
  }

  /// Kontrollerar brandväggens TLS-certifikat mot ett tidigare sparat
  /// fingeravtryck (trust-on-first-use). Ska anropas INNAN login() vid
  /// varje ny anslutning till en https://-URL på icke-web-plattformar —
  /// på web sköter webbläsaren sin egen certifikatvarning och detta hoppas
  /// helt över (returnerar `skipped`).
  Future<TlsCheckResult> checkServerCertificate() async {
    if (kIsWeb || !baseUrl.startsWith('https://')) {
      return TlsCheckResult(TlsTrustStatus.skipped);
    }
    final uri = Uri.parse(baseUrl);
    final host = uri.host;
    final port = uri.hasPort ? uri.port : 443;
    final hostPort = '$host:$port';

    final actual = await tls_trust.probeCertificateSha256(host, port);
    if (actual == null) {
      // Kunde inte hämta certifikatet (t.ex. servern är nere) — låt
      // det faktiska anropet i login() ge det riktiga felmeddelandet.
      return TlsCheckResult(TlsTrustStatus.skipped);
    }

    final expected = await tls_trust.getTrustedFingerprint(hostPort);
    if (expected == null) {
      return TlsCheckResult(TlsTrustStatus.newUnknown, fingerprint: actual);
    }
    if (expected != actual) {
      return TlsCheckResult(TlsTrustStatus.mismatch, fingerprint: actual, expectedFingerprint: expected);
    }
    _trustedFingerprints[hostPort] = actual;
    return TlsCheckResult(TlsTrustStatus.trustedMatch, fingerprint: actual);
  }

  /// Sparar (eller uppdaterar, vid ett medvetet godkänt certifikatbyte)
  /// fingeravtrycket som betrott för den aktuella baseUrl.
  Future<void> trustFingerprint(String fingerprint) async {
    if (kIsWeb || !baseUrl.startsWith('https://')) return;
    final uri = Uri.parse(baseUrl);
    final hostPort = '${uri.host}:${uri.hasPort ? uri.port : 443}';
    _trustedFingerprints[hostPort] = fingerprint;
    await tls_trust.setTrustedFingerprint(hostPort, fingerprint);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // "admin" eller "viewer" (Fas 8 — flera användare/roller). Sätts av
  // login() från serverns svar.
  String? role;
  // Den faktiskt inloggade användaren — sätts av login() från serverns
  // svar (inte bara ekot av vad man skrev in i fältet).
  String? username;

  Future<bool> login(String usernameInput, String password) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': usernameInput, 'password': password}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        token = data['token'];
        role = data['role'];
        username = data['user'];
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Byter lösenord för DEN INLOGGADE ANVÄNDAREN SJÄLV — kräver nuvarande
  /// lösenord (Fas 8).
  Future<String?> changePassword(String currentPassword, String newPassword) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/auth/change-password'),
        headers: _headers,
        body: jsonEncode({'current_password': currentPassword, 'new_password': newPassword}),
      );
      if (res.statusCode == 200) return null;
      return res.body.isNotEmpty ? res.body : 'Misslyckades byta lösenord';
    } catch (e) {
      return 'Misslyckades byta lösenord: $e';
    }
  }

  /// Skapar en lösenfras-krypterad backup av hela persistenslagret
  /// (Fas 10). Returnerar base64-strängen vid lyckat anrop, annars null +
  /// ett felmeddelande.
  Future<({String? backupB64, String? error})> createBackup(String passphrase) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/system/backup'),
        headers: _headers,
        body: jsonEncode({'passphrase': passphrase}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (backupB64: data['backup_b64'] as String?, error: null);
      }
      return (backupB64: null, error: res.body.isNotEmpty ? res.body : 'Backup misslyckades');
    } catch (e) {
      return (backupB64: null, error: 'Fel: $e');
    }
  }

  /// Återställer en backup. Brandväggen startar om automatiskt vid lyckad
  /// återställning (systemd Restart=always) - anropet kan därför få en
  /// avbruten/timeout-liknande respons även vid framgång.
  Future<String?> restoreBackup(String backupB64, String passphrase) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/system/restore'),
        headers: _headers,
        body: jsonEncode({'backup_b64': backupB64, 'passphrase': passphrase}),
      );
      if (res.statusCode == 200) return null;
      return res.body.isNotEmpty ? res.body : 'Återställning misslyckades';
    } catch (e) {
      return null; // Anslutningen kan brytas när agenten startar om - inte nödvändigtvis ett fel.
    }
  }

  /// Fabriksåterställer brandväggen (Fas 10) - tar bort ALL konfiguration.
  /// Kräver det inloggade admin-kontots nuvarande lösenord som extra spärr.
  Future<String?> factoryReset(String password) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/system/factory-reset'),
        headers: _headers,
        body: jsonEncode({'password': password}),
      );
      if (res.statusCode == 200) return null;
      return res.body.isNotEmpty ? res.body : 'Fabriksåterställning misslyckades';
    } catch (e) {
      return null; // Anslutningen kan brytas när agenten startar om - inte nödvändigtvis ett fel.
    }
  }

  /// Listar alla administrationsanvändare (admin-only, Fas 8).
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/auth/users'), headers: _headers);
      if (res.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(res.body));
      }
    } catch (_) {}
    return [];
  }

  /// Skapar en ny användare (admin-only). role är "admin" eller "viewer".
  Future<String?> createUser(String username, String password, String role) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/auth/users/create'),
        headers: _headers,
        body: jsonEncode({'username': username, 'password': password, 'role': role}),
      );
      if (res.statusCode == 200) return null;
      return res.body.isNotEmpty ? res.body : 'Misslyckades skapa användare';
    } catch (e) {
      return 'Misslyckades skapa användare: $e';
    }
  }

  Future<String?> deleteUser(String id) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/auth/users/delete'),
        headers: _headers,
        body: jsonEncode({'id': id}),
      );
      if (res.statusCode == 200) return null;
      return res.body.isNotEmpty ? res.body : 'Misslyckades ta bort användare';
    } catch (e) {
      return 'Misslyckades ta bort användare: $e';
    }
  }

  /// Admin sätter ett nytt lösenord för en ANNAN användare (utan att
  /// behöva känna till dennes nuvarande lösenord).
  Future<String?> resetUserPassword(String id, String newPassword) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/auth/users/reset-password'),
        headers: _headers,
        body: jsonEncode({'id': id, 'new_password': newPassword}),
      );
      if (res.statusCode == 200) return null;
      return res.body.isNotEmpty ? res.body : 'Misslyckades återställa lösenord';
    } catch (e) {
      return 'Misslyckades återställa lösenord: $e';
    }
  }

  Future<Map<String, dynamic>?> getSystemStatus() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/system'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> discoverInterfaces() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/interfaces/discover'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return [];
  }

  Future<List<ConntrackModel>> getConntrack() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/diagnostics/conntrack'), headers: _headers);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((e) => ConntrackModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<FirewallLogModel>> getFirewallLog() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/diagnostics/firewall-log'), headers: _headers);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((e) => FirewallLogModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<SecurityEventModel>> getSecurityEvents() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/diagnostics/security-events'), headers: _headers);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((e) => SecurityEventModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<DhcpLeaseModel>> getDhcpLeases() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/dhcp/leases'), headers: _headers);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((e) => DhcpLeaseModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> getWireGuardServerInfo() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/vpn/wireguard/server-info'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
  }

  /// Genererar ett engångsnyckelpar åt en ny VPN-klient. Returnerar
  /// {private_key, public_key} — den privata nyckeln lagras ALDRIG på
  /// brandväggen, bara den publika ska sparas i candidate-konfigurationen.
  Future<Map<String, String>?> generateWireGuardPeerKeys() async {
    try {
      final res = await _client.post(Uri.parse('$baseUrl/api/v1/vpn/wireguard/generate-peer-keys'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    return null;
  }

  Future<String?> getOpenVPNCACertPem() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/vpn/openvpn/ca-info'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data['ca_cert_pem'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Signerar ett nytt OpenVPN-klientcertifikat med brandväggens CA och
  /// returnerar {cert_pem, serial, ovpn_config}. ovpn_config innehåller
  /// klientens privata nyckel inline och visas EN gång i GUI:t — den lagras
  /// ALDRIG på brandväggen (bara cert_pem/serial ska sparas i
  /// candidate-konfigurationens OpenVPN.clients).
  Future<Map<String, String>?> generateOpenVPNClient(String name) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/vpn/openvpn/generate-client'),
        headers: _headers,
        body: jsonEncode({'name': name}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    return null;
  }

  /// Triggar en omedelbar uppdatering av ett Object med automatisk källa
  /// (hot-lista/GeoIP, Fas 5) istället för att vänta på nästa periodiska
  /// tillfälle (var 15:e minut på agentsidan).
  Future<bool> refreshObjectSource(String objectId) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/objects/refresh-source'),
        headers: _headers,
        body: jsonEncode({'object_id': objectId}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Triggar en omedelbar uppdatering av EN DNS-domänblocklista (Fas 6,
  /// flera kan vara aktiva samtidigt — matchas på DNSBlocklistSource.id).
  Future<bool> refreshDNSBlocklist(String blocklistId) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/dns/refresh-blocklist'),
        headers: _headers,
        body: jsonEncode({'blocklist_id': blocklistId}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Läser den cachade domänlistan för EN blocklist-källa — så att GUI:t
  /// kan visa (inte bara räkna) vad som faktiskt är blockerat.
  Future<List<String>> getDNSBlocklistDomains(String blocklistId) async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/dns/blocklist-domains?id=$blocklistId'), headers: _headers);
      if (res.statusCode == 200) {
        return List<String>.from(jsonDecode(res.body) ?? []);
      }
    } catch (_) {}
    return [];
  }

  /// Läser LIVE paket-/bytesräknare för brandväggens regler (Fas 7 — Hit
  /// counters), summerade per Policy-namn. Kommer direkt ur den skarpa
  /// nftables-ruleseten, inte något agenten själv räknar/lagrar.
  Future<Map<String, Map<String, int>>> getHitCounts() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/policies/hit-counts'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data.map((k, v) => MapEntry(k, (v as Map<String, dynamic>).map((k2, v2) => MapEntry(k2, v2 as int))));
      }
    } catch (_) {}
    return {};
  }

  Future<String> ping(String host) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/diagnostics/ping'),
        headers: _headers,
        body: jsonEncode({'host': host}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['output'] ?? '';
      }
    } catch (e) {
      return 'Fel: $e';
    }
    return 'Ingen kontakt';
  }

  /// Kör nmap mot host med valfri kombination av skanningstyper.
  Future<String> nmap(String host, {bool synScan = false, bool fullTcp = false, bool udpScan = false, bool osDetect = false}) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/diagnostics/nmap'),
        headers: _headers,
        body: jsonEncode({
          'host': host,
          'syn_scan': synScan,
          'full_tcp': fullTcp,
          'udp_scan': udpScan,
          'os_detect': osDetect,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['output'] ?? '';
      }
      return res.body.isNotEmpty ? res.body : 'nmap misslyckades';
    } catch (e) {
      return 'Fel: $e';
    }
  }

  Future<String> tcpdumpCapture(String iface, {String filter = '', int packetCount = 200, int durationSec = 10}) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/diagnostics/tcpdump'),
        headers: _headers,
        body: jsonEncode({
          'interface': iface,
          'filter': filter,
          'packet_count': packetCount,
          'duration_sec': durationSec,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['output'] ?? '';
      }
      return res.body.isNotEmpty ? res.body : 'Paketfångst misslyckades';
    } catch (e) {
      return 'Fel: $e';
    }
  }

  Future<String> traceroute(String host) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/diagnostics/traceroute'),
        headers: _headers,
        body: jsonEncode({'host': host}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['output'] ?? '';
      }
    } catch (e) {
      return 'Fel: $e';
    }
    return 'Ingen kontakt';
  }

  Future<ConfigModel?> getRunningConfig() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/config/running'), headers: _headers);
      if (res.statusCode == 200) {
        return ConfigModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  Future<ConfigModel?> getCandidateConfig() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/config/candidate'), headers: _headers);
      if (res.statusCode == 200) {
        return ConfigModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  Future<bool> setCandidateConfig(ConfigModel config) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl/api/v1/config/candidate'),
        headers: _headers,
        body: jsonEncode(config.toJson()),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateCandidate(ConfigModel config) => setCandidateConfig(config);

  /// Returnerar null vid lyckad applicering, annars felmeddelandet från
  /// servern (t.ex. ett valideringsfel om en policys zon inte matchar
  /// något gränssnitt) - ropas av ConfigProvider.applyChanges så GUI:t kan
  /// visa VAD som gick fel, inte bara att något gjorde det.
  Future<String?> applyConfig() async {
    try {
      final res = await _client.post(Uri.parse('$baseUrl/api/v1/config/apply'), headers: _headers);
      if (res.statusCode == 200) return null;
      return res.body.isNotEmpty ? res.body : 'Applicering misslyckades på brandväggen (HTTP ${res.statusCode})';
    } catch (e) {
      return 'Fel: $e';
    }
  }

  Future<String?> applyCandidate() => applyConfig();

  Future<bool> confirmConfig() async {
    try {
      final res = await _client.post(Uri.parse('$baseUrl/api/v1/config/confirm'), headers: _headers);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> confirmApply() => confirmConfig();

  Future<bool> rollbackConfig() async {
    try {
      final res = await _client.post(Uri.parse('$baseUrl/api/v1/config/rollback'), headers: _headers);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rollback() => rollbackConfig();

  Future<List<Map<String, dynamic>>> fetchBandwidthStats() async {
    try {
      final res = await _client.get(Uri.parse('$baseUrl/api/v1/diagnostics/bandwidth'), headers: _headers);
      if (res.statusCode == 200) {
        final List dynamicList = jsonDecode(res.body);
        return dynamicList.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }
}
