import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/config_model.dart';
import '../services/api_service.dart';

enum ApplyStatus { idle, unconfirmed, confirming, error }

const String _prefsUrlKey = 'firewall_url';

class ConfigProvider extends ChangeNotifier {
  final ApiService api = ApiService();

  bool isAuthenticated = false;
  bool isLoading = false;
  // Sant tills den sparade brandvägg-URL:en (om någon) hunnit läsas in från
  // disk — LoginScreen väntar med att rendera fältet förifyllt tills dess.
  bool isInitializing = true;
  bool hasUnappliedChanges = false;
  String? errorMessage;
  String? statusMessage;

  ConfigModel? runningConfig;
  ConfigModel? candidateConfig;
  Map<String, dynamic>? systemStatus;

  ApplyStatus applyStatus = ApplyStatus.idle;
  int rollbackSecondsRemaining = 0;
  Timer? _rollbackCountdownTimer;

  // Fas 8 — flera användare/roller. isAdmin styr t.ex. om GUI:t visar
  // skriv-knappar/användarhantering; den FAKTISKA behörighetskontrollen
  // sker alltid på agenten (authMiddlewareAdmin), detta är bara för UX.
  bool get isAdmin => api.role == 'admin';

  // OBS: Inget hop-kodat lösenord/auto-login här. Appen distribueras
  // publikt (APK/Linux-paket på security.novabase.se) — ett hårdkodat
  // lösenord i klientkoden hade skickats ut till VARJE nedladdning,
  // oavsett vilken server de sedan pekar appen mot. Bara URL:en (aldrig
  // lösenordet) sparas lokalt vid lyckad inloggning, se _saveUrl.

  ConfigProvider() {
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_prefsUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      api.setBaseUrl(savedUrl);
    }
    isInitializing = false;
    notifyListeners();
  }

  Future<void> _saveUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsUrlKey, url);
  }

  Future<void> changeAgentUrl(String newUrl) async {
    api.setBaseUrl(newUrl);
  }

  Future<void> login(String user, String pass) async {
    isLoading = true;
    errorMessage = null;
    statusMessage = 'Ansluter till brandvägg...';
    notifyListeners();

    final success = await api.login(user, pass);
    if (success) {
      isAuthenticated = true;
      statusMessage = 'Inloggad';
      await _saveUrl(api.baseUrl);
      await fetchAll();
    } else {
      isAuthenticated = false;
      errorMessage = 'Inloggning misslyckades mot ${api.baseUrl}';
      statusMessage = null;
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> logout() async {
    isAuthenticated = false;
    api.token = null;
    runningConfig = null;
    candidateConfig = null;
    systemStatus = null;
    notifyListeners();
  }

  Future<void> fetchAll() async {
    systemStatus = await api.getSystemStatus();
    runningConfig = await api.getRunningConfig();
    candidateConfig = await api.getCandidateConfig();
    notifyListeners();
  }

  Future<void> updateCandidate(ConfigModel newConfig) async {
    isLoading = true;
    statusMessage = 'Sparar ändringar i kandidatkonfiguration...';
    notifyListeners();

    final success = await api.setCandidateConfig(newConfig);
    if (success) {
      candidateConfig = newConfig;
      hasUnappliedChanges = true;
      statusMessage = null;
    } else {
      errorMessage = 'Kunde inte spara ändring i kandidat';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> applyChanges() async {
    if (candidateConfig == null) return false;
    isLoading = true;
    statusMessage = 'Applicerar nftables-regler på brandväggsservern...';
    notifyListeners();

    final success = await api.applyConfig();
    if (success) {
      applyStatus = ApplyStatus.unconfirmed;
      hasUnappliedChanges = false;
      statusMessage = null;
      _startRollbackTimer(30);
      isLoading = false;
      notifyListeners();
      return true;
    } else {
      errorMessage = 'Applicering misslyckades på brandväggen';
      statusMessage = null;
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> confirmChanges() async {
    isLoading = true;
    statusMessage = 'Bekräftar och committar konfiguration...';
    notifyListeners();

    final success = await api.confirmConfig();
    if (success) {
      _stopRollbackTimer();
      applyStatus = ApplyStatus.idle;
      hasUnappliedChanges = false;
      statusMessage = null;
      await fetchAll();
      isLoading = false;
      notifyListeners();
      return true;
    } else {
      errorMessage = 'Bekräftelse misslyckades';
      statusMessage = null;
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> rollbackChanges() async {
    isLoading = true;
    statusMessage = 'Återställer till senast kända säkra konfiguration...';
    notifyListeners();

    final success = await api.rollbackConfig();
    _stopRollbackTimer();
    applyStatus = ApplyStatus.idle;
    hasUnappliedChanges = false;
    statusMessage = null;
    await fetchAll();
    isLoading = false;
    notifyListeners();
    return success;
  }

  void _startRollbackTimer(int seconds) {
    _stopRollbackTimer();
    rollbackSecondsRemaining = seconds;
    _rollbackCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (rollbackSecondsRemaining > 1) {
        rollbackSecondsRemaining--;
        notifyListeners();
      } else {
        _stopRollbackTimer();
        applyStatus = ApplyStatus.idle;
        hasUnappliedChanges = false;
        fetchAll();
      }
    });
  }

  void _stopRollbackTimer() {
    _rollbackCountdownTimer?.cancel();
    _rollbackCountdownTimer = null;
    rollbackSecondsRemaining = 0;
  }
}
