import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/config_model.dart';

class ApiService {
  String baseUrl;
  String? token;

  ApiService({this.baseUrl = 'http://10.0.0.163:8443'});

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

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>?> getSystemStatus() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/v1/system'), headers: _headers);
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
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

  Future<bool> applyConfig() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/v1/config/apply'), headers: _headers);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> confirmConfig() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/v1/config/confirm'), headers: _headers);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rollbackConfig() async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/api/v1/config/rollback'), headers: _headers);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
