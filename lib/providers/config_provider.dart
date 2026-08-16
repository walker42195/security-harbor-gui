import 'dart:async';
import 'package:flutter/material.dart';
import '../models/config_model.dart';
import '../services/api_service.dart';

enum ApplyStatus { idle, unconfirmed, confirming, error }

class ConfigProvider extends ChangeNotifier {
  final ApiService api = ApiService();

  bool isAuthenticated = false;
  bool isLoading = false;
  bool hasUnappliedChanges = false;
  String? errorMessage;
  String? statusMessage;

  ConfigModel? runningConfig;
  ConfigModel? candidateConfig;
  Map<String, dynamic>? systemStatus;

  ApplyStatus applyStatus = ApplyStatus.idle;
  int rollbackSecondsRemaining = 0;
  Timer? _rollbackCountdownTimer;

  ConfigProvider() {
    // Auto-login med dev credentials
    login('admin', 'SecurityHarbor2026!');
  }

  Future<void> changeAgentUrl(String newUrl) async {
    api.setBaseUrl(newUrl);
    await login('admin', 'SecurityHarbor2026!');
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
      await fetchAll();
    } else {
      isAuthenticated = false;
      errorMessage = 'Inloggning misslyckades mot ${api.baseUrl}';
      statusMessage = null;
    }

    isLoading = false;
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
