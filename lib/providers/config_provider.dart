import 'dart:async';
import 'package:flutter/material.dart';
import '../models/config_model.dart';
import '../services/api_service.dart';

enum ApplyStatus { idle, unconfirmed, confirming, error }

class ConfigProvider extends ChangeNotifier {
  final ApiService api = ApiService();

  bool isAuthenticated = false;
  bool isLoading = false;
  String? errorMessage;

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
    notifyListeners();

    final success = await api.login(user, pass);
    if (success) {
      isAuthenticated = true;
      await fetchAll();
    } else {
      isAuthenticated = false;
      errorMessage = 'Inloggning misslyckades mot ${api.baseUrl}';
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
    final success = await api.setCandidateConfig(newConfig);
    if (success) {
      candidateConfig = newConfig;
      notifyListeners();
    }
  }

  Future<void> applyChanges() async {
    if (candidateConfig == null) return;
    isLoading = true;
    notifyListeners();

    final success = await api.applyConfig();
    if (success) {
      applyStatus = ApplyStatus.unconfirmed;
      _startRollbackTimer(30);
    } else {
      errorMessage = 'Applicering misslyckades';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> confirmChanges() async {
    isLoading = true;
    notifyListeners();

    final success = await api.confirmConfig();
    if (success) {
      _stopRollbackTimer();
      applyStatus = ApplyStatus.idle;
      await fetchAll();
    } else {
      errorMessage = 'Bekräftelse misslyckades';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> rollbackChanges() async {
    isLoading = true;
    notifyListeners();

    final success = await api.rollbackConfig();
    if (success) {
      _stopRollbackTimer();
      applyStatus = ApplyStatus.idle;
      await fetchAll();
    }

    isLoading = false;
    notifyListeners();
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
