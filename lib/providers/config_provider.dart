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
    var savedUrl = prefs.getString(_prefsUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      // Migrera automatiskt en tidigare sparad http://-URL till https://
      // — Management-API:t kräver numera alltid TLS (Fas 8+), så en gammal
      // installation ska inte behöva mata in adressen manuellt igen bara
      // för att skemat ändrats.
      if (savedUrl.startsWith('http://')) {
        savedUrl = 'https://${savedUrl.substring('http://'.length)}';
        await prefs.setString(_prefsUrlKey, savedUrl);
      }
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
    api.role = null;
    api.username = null;
    runningConfig = null;
    candidateConfig = null;
    systemStatus = null;
    notifyListeners();
  }

  /// Uppdaterar ENDAST systemStatus (CPU/RAM/uptime m.m.) utan att röra
  /// running/candidate-configen — anropas periodiskt från Dashboard så
  /// siffrorna faktiskt lever, se _pollBandwidth i dashboard_screen.dart.
  Future<void> refreshSystemStatus() async {
    if (!isAuthenticated) return;
    systemStatus = await api.getSystemStatus();
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

  /// Kastar bort alla ännu icke-applicerade ändringar i kandidat-
  /// konfigurationen och återställer den till den nu körande (running)
  /// konfigurationen. Används t.ex. om man råkat ta bort en regel men
  /// ännu inte tryckt Applicera — inget har då nått brandväggen, så det
  /// räcker att skriva tillbaka running som ny kandidat. (Detta är INTE
  /// samma sak som Rollback, som återställer en REDAN applicerad men
  /// obekräftad ändring.)
  Future<bool> discardChanges() async {
    isLoading = true;
    statusMessage = 'Återställer ändringar...';
    notifyListeners();

    final running = await api.getRunningConfig();
    if (running == null) {
      errorMessage = 'Kunde inte hämta körande konfiguration';
      statusMessage = null;
      isLoading = false;
      notifyListeners();
      return false;
    }

    final ok = await api.setCandidateConfig(running);
    if (ok) {
      runningConfig = running;
      candidateConfig = running;
      hasUnappliedChanges = false;
      statusMessage = null;
      errorMessage = null;
    } else {
      errorMessage = 'Kunde inte återställa ändringar';
      statusMessage = null;
    }
    isLoading = false;
    notifyListeners();
    return ok;
  }

  Future<bool> applyChanges() async {
    if (candidateConfig == null) return false;
    isLoading = true;
    statusMessage = 'Applicerar nftables-regler på brandväggsservern...';
    notifyListeners();

    final err = await api.applyConfig();
    if (err == null) {
      applyStatus = ApplyStatus.unconfirmed;
      hasUnappliedChanges = false;
      statusMessage = null;
      errorMessage = null;
      _startRollbackTimer(30);
      isLoading = false;
      notifyListeners();
      return true;
    } else {
      errorMessage = err;
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
