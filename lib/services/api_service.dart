import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/config_model.dart';

class ApiService {
  String baseUrl;
  String? token;

  ApiService({this.baseUrl = 'http://10.0.0.163:8443'});

  void setBaseUrl(String newUrl) {
    var formatted = newUrl.trim();
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'http://$formatted';
    }
    if (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    baseUrl = formatted;
    token = null;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<bool> login(String username, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        token = data['token'];
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSystemStatus() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/system'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
  }

  Future<List<dynamic>> discoverInterfaces() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/interfaces/discover'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return [];
  }

  Future<List<ConntrackModel>> getConntrack() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/diagnostics/conntrack'), headers: _headers);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((e) => ConntrackModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<FirewallLogModel>> getFirewallLog() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/diagnostics/firewall-log'), headers: _headers);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((e) => FirewallLogModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> getWireGuardServerInfo() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/vpn/wireguard/server-info'), headers: _headers);
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
      final res = await http.post(Uri.parse('$baseUrl/api/v1/vpn/wireguard/generate-peer-keys'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
    return null;
  }

  Future<String?> getOpenVPNCACertPem() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/vpn/openvpn/ca-info'), headers: _headers);
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
      final res = await http.post(
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
      final res = await http.post(
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
      final res = await http.post(
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
      final res = await http.get(Uri.parse('$baseUrl/api/v1/dns/blocklist-domains?id=$blocklistId'), headers: _headers);
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
      final res = await http.get(Uri.parse('$baseUrl/api/v1/policies/hit-counts'), headers: _headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data.map((k, v) => MapEntry(k, (v as Map<String, dynamic>).map((k2, v2) => MapEntry(k2, v2 as int))));
      }
    } catch (_) {}
    return {};
  }

  Future<String> ping(String host) async {
    try {
      final res = await http.post(
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

  Future<String> traceroute(String host) async {
    try {
      final res = await http.post(
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
      final res = await http.get(Uri.parse('$baseUrl/api/v1/config/running'), headers: _headers);
      if (res.statusCode == 200) {
        return ConfigModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  Future<ConfigModel?> getCandidateConfig() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/config/candidate'), headers: _headers);
      if (res.statusCode == 200) {
        return ConfigModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  Future<bool> setCandidateConfig(ConfigModel config) async {
    try {
      final res = await http.post(
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

  Future<bool> applyConfig() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/v1/config/apply'), headers: _headers);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> applyCandidate() => applyConfig();

  Future<bool> confirmConfig() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/v1/config/confirm'), headers: _headers);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> confirmApply() => confirmConfig();

  Future<bool> rollbackConfig() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/v1/config/rollback'), headers: _headers);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rollback() => rollbackConfig();

  Future<List<Map<String, dynamic>>> fetchBandwidthStats() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/diagnostics/bandwidth'), headers: _headers);
      if (res.statusCode == 200) {
        final List dynamicList = jsonDecode(res.body);
        return dynamicList.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }
}
