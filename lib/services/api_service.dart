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
