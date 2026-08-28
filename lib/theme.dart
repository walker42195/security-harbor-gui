/// Färgpalett och temaväxling.
///
/// GUI:t hade färgerna hårdkodade på 1332 ställen i 19 filer — bakgrunden
/// `0xFF0F172A`, kortytan `0xFF1E293B`, ramen `0xFF334155` och `Colors.white`
/// för text. Ett ljust tema krävde därför att varje sådant ställe blev
/// utbytbart.
///
/// Lösningen är statiska getters som läser [AppTheme.mode]. Alternativet —
/// `Theme.of(context)` överallt — hade krävt en BuildContext på ställen som
/// inte har någon, och hade dessutom brutit varje `const`-konstruktor i
/// trädet. Med getters räcker det att byta ut värdet; anropsstället ser
/// likadant ut.
///
/// Priset är att getters inte är `const`. Där en färg låg i ett
/// `const`-uttryck har det `const` tagits bort — det är en ren
/// prestandadetalj i en app som ändå bygger om vid varje temabyte.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Vilket tema som är aktivt.
enum AppThemeMode {
  dark,
  light,
  crimsonLight,
  modernLight,
  tokyoNight,
  oledBlack,
}

extension AppThemeModeExt on AppThemeMode {
  Color get themeColor {
    switch (this) {
      case AppThemeMode.dark:
        return const Color(0xFF18FFFF);
      case AppThemeMode.light:
        return const Color(0xFF0B6E4F);
      case AppThemeMode.crimsonLight:
        return const Color(0xFFDC2626);
      case AppThemeMode.modernLight:
        return const Color(0xFF2563EB);
      case AppThemeMode.tokyoNight:
        return const Color(0xFF7AA2F7);
      case AppThemeMode.oledBlack:
        return const Color(0xFF00E5FF);
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeMode.dark:
        return Icons.nightlight_round;
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.crimsonLight:
        return Icons.shield_outlined;
      case AppThemeMode.modernLight:
        return Icons.wb_sunny_outlined;
      case AppThemeMode.tokyoNight:
        return Icons.brightness_2_outlined;
      case AppThemeMode.oledBlack:
        return Icons.contrast;
    }
  }

  String get translationKey {
    switch (this) {
      case AppThemeMode.dark:
        return 'theme.dark';
      case AppThemeMode.light:
        return 'theme.light';
      case AppThemeMode.crimsonLight:
        return 'theme.crimson_light';
      case AppThemeMode.modernLight:
        return 'theme.modern_light';
      case AppThemeMode.tokyoNight:
        return 'theme.tokyo_night';
      case AppThemeMode.oledBlack:
        return 'theme.oled_black';
    }
  }

  String get description {
    switch (this) {
      case AppThemeMode.dark:
        return 'Mörk klassisk marinblå stil';
      case AppThemeMode.light:
        return 'Klassisk varm gräddvit med mintknappar';
      case AppThemeMode.crimsonLight:
        return 'Krispig vit yta med djupröda accenter';
      case AppThemeMode.modernLight:
        return 'Krispig vit SaaS med kungsblå accenter';
      case AppThemeMode.tokyoNight:
        return 'Mörk nattpalett med pastell & lavendel';
      case AppThemeMode.oledBlack:
        return 'Kolsvart OLED med neonaccenter';
    }
  }
}

/// Global temastyrning. Notifierar så att hela appen byggs om vid byte.
class AppTheme extends ChangeNotifier {
  AppTheme._();
  static final AppTheme instance = AppTheme._();

  static const _prefsKey = 'app_theme_mode';

  /// Nuvarande läge. Statiskt så att [AppColors] kan läsa det utan context.
  static AppThemeMode mode = AppThemeMode.dark;

  static bool get isDark =>
      mode == AppThemeMode.dark ||
      mode == AppThemeMode.tokyoNight ||
      mode == AppThemeMode.oledBlack;

  /// Läser sparat val vid uppstart. Mörkt är standard.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null) {
        mode = AppThemeMode.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => saved == 'light' ? AppThemeMode.light : AppThemeMode.dark,
        );
        notifyListeners();
      }
    } catch (_) {
      // Kan inte läsa inställningen: behåll standard.
    }
  }

  Future<void> toggle() => setMode(isDark ? AppThemeMode.modernLight : AppThemeMode.dark);

  Future<void> setMode(AppThemeMode next) async {
    if (mode == next) return;
    mode = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, next.name);
    } catch (_) {
      // Valet gäller ändå för den här sessionen.
    }
  }
}

/// Färgerna som byter med temat.
class AppColors {
  const AppColors._();

  static AppThemeMode get _m => AppTheme.mode;
  static bool get _d => AppTheme.isDark;

  /// Sidbakgrund.
  static Color get bg {
    switch (_m) {
      case AppThemeMode.dark:
        return const Color(0xFF0F172A);
      case AppThemeMode.light:
        return const Color(0xFFF2F0E9);
      case AppThemeMode.crimsonLight:
      case AppThemeMode.modernLight:
        return const Color(0xFFFFFFFF);
      case AppThemeMode.tokyoNight:
        return const Color(0xFF1A1B26);
      case AppThemeMode.oledBlack:
        return const Color(0xFF000000);
    }
  }

  /// Kort- och panelyta.
  static Color get surface {
    switch (_m) {
      case AppThemeMode.dark:
        return const Color(0xFF1E293B);
      case AppThemeMode.light:
        return const Color(0xFFFBFAF6);
      case AppThemeMode.crimsonLight:
        return const Color(0xFFFFFFFF);
      case AppThemeMode.modernLight:
        return const Color(0xFFF8FAFC);
      case AppThemeMode.tokyoNight:
        return const Color(0xFF24283B);
      case AppThemeMode.oledBlack:
        return const Color(0xFF0C0D0E);
    }
  }

  /// Ytan en nivå djupare (kodrutor, inbäddade listor).
  static Color get surfaceDeep {
    switch (_m) {
      case AppThemeMode.dark:
        return const Color(0xFF0F172A);
      case AppThemeMode.light:
        return const Color(0xFFEDEBE2);
      case AppThemeMode.crimsonLight:
        return const Color(0xFFF8FAFC);
      case AppThemeMode.modernLight:
        return const Color(0xFFF1F5F9);
      case AppThemeMode.tokyoNight:
        return const Color(0xFF16161E);
      case AppThemeMode.oledBlack:
        return const Color(0xFF000000);
    }
  }

  /// Navigations-sidebar yta.
  static Color get sidebarBg => surface;

  /// Ramar och avdelare.
  static Color get border {
    switch (_m) {
      case AppThemeMode.dark:
        return const Color(0xFF334155);
      case AppThemeMode.light:
        return const Color(0xFFD6D3C8);
      case AppThemeMode.crimsonLight:
      case AppThemeMode.modernLight:
        return const Color(0xFFCBD5E1);
      case AppThemeMode.tokyoNight:
        return const Color(0xFF3B4261);
      case AppThemeMode.oledBlack:
        return const Color(0xFF22262B);
    }
  }

  /// Svag avdelare.
  static Color get divider => _d ? Colors.white10 : const Color(0xFFE2E8F0);

  /// Brödtext.
  static Color get text {
    switch (_m) {
      case AppThemeMode.dark:
        return Colors.white;
      case AppThemeMode.light:
        return const Color(0xFF1A1A1A);
      case AppThemeMode.crimsonLight:
      case AppThemeMode.modernLight:
        return const Color(0xFF0F172A);
      case AppThemeMode.tokyoNight:
        return const Color(0xFFC0CAF5);
      case AppThemeMode.oledBlack:
        return const Color(0xFFFFFFFF);
    }
  }

  /// Sekundär text.
  static Color get textMuted {
    switch (_m) {
      case AppThemeMode.dark:
        return Colors.white70;
      case AppThemeMode.light:
        return const Color(0xFF4A4A45);
      case AppThemeMode.crimsonLight:
      case AppThemeMode.modernLight:
        return const Color(0xFF475569);
      case AppThemeMode.tokyoNight:
        return const Color(0xFF9AA5CE);
      case AppThemeMode.oledBlack:
        return const Color(0xFFAAAAAA);
    }
  }

  /// Svag text.
  static Color get textFaint {
    switch (_m) {
      case AppThemeMode.dark:
        return Colors.white38;
      case AppThemeMode.light:
        return const Color(0xFF6B6B62);
      case AppThemeMode.crimsonLight:
      case AppThemeMode.modernLight:
        return const Color(0xFF64748B);
      case AppThemeMode.tokyoNight:
        return const Color(0xFF7A84AA);
      case AppThemeMode.oledBlack:
        return const Color(0xFF777777);
    }
  }

  /// Platshållartext i inmatningsfält.
  static Color get hint {
    switch (_m) {
      case AppThemeMode.light:
        return const Color(0xFF8A8A80);
      default:
        return textFaint;
    }
  }

  /// Accent för TEXT och ikoner.
  static Color get accent {
    switch (_m) {
      case AppThemeMode.dark:
        return Colors.cyanAccent;
      case AppThemeMode.light:
        return const Color(0xFF0B6E4F);
      case AppThemeMode.crimsonLight:
        return const Color(0xFFB91C1C); // Crimson 700
      case AppThemeMode.modernLight:
        return const Color(0xFF0369A1); // Sky 700
      case AppThemeMode.tokyoNight:
        return const Color(0xFF7DCFFF); // Tokyo Cyan
      case AppThemeMode.oledBlack:
        return const Color(0xFF00E5FF); // Electric Cyan
    }
  }

  /// Text ovanpå accentfärgade knappar/badgar.
  static Color get onAccent => _d ? Colors.black : Colors.white;

  /// PRIMÄRKNAPPENS bakgrund.
  static Color get accentBg {
    switch (_m) {
      case AppThemeMode.dark:
        return Colors.cyanAccent;
      case AppThemeMode.light:
        return const Color(0xFF3DDC97);
      case AppThemeMode.crimsonLight:
        return const Color(0xFFDC2626);
      case AppThemeMode.modernLight:
        return const Color(0xFF2563EB);
      case AppThemeMode.tokyoNight:
        return const Color(0xFF7AA2F7);
      case AppThemeMode.oledBlack:
        return const Color(0xFF00E676);
    }
  }

  static Color get onAccentBg {
    switch (_m) {
      case AppThemeMode.dark:
      case AppThemeMode.tokyoNight:
      case AppThemeMode.oledBlack:
      case AppThemeMode.light:
        return Colors.black;
      case AppThemeMode.crimsonLight:
      case AppThemeMode.modernLight:
        return Colors.white;
    }
  }

  /// SEKUNDÄRKNAPPENS bakgrund.
  static Color get warnBg => _d ? Colors.amberAccent : const Color(0xFFFFE500);
  static Color get onWarnBg => Colors.black;

  /// Betydelsebärande statusfärger.
  static Color get ok {
    switch (_m) {
      case AppThemeMode.dark:
        return Colors.tealAccent;
      case AppThemeMode.tokyoNight:
        return const Color(0xFF9ECE6A);
      case AppThemeMode.oledBlack:
        return const Color(0xFF00E676);
      case AppThemeMode.light:
      case AppThemeMode.crimsonLight:
      case AppThemeMode.modernLight:
        return const Color(0xFF15803D);
    }
  }

  static Color get warn {
    switch (_m) {
      case AppThemeMode.dark:
        return Colors.amberAccent;
      case AppThemeMode.tokyoNight:
        return const Color(0xFFE0AF68);
      case AppThemeMode.oledBlack:
        return const Color(0xFFFFD600);
      case AppThemeMode.light:
      case AppThemeMode.crimsonLight:
      case AppThemeMode.modernLight:
        return const Color(0xFF8A6A00);
    }
  }

  /// Kategoripalett för cirkeldiagram (enhets-dashboarden). Färgerna ska gå
  /// att skilja åt bredvid varandra i både ljust och mörkt tema, och används
  /// cykliskt om det finns fler skivor än färger.
  static const List<Color> piePalette = [
    Color(0xFF4FC3F7), Color(0xFF81C784), Color(0xFFFFB74D), Color(0xFFE57373),
    Color(0xFFBA68C8), Color(0xFF4DD0E1), Color(0xFFFFF176), Color(0xFFA1887F),
    Color(0xFF90A4AE), Color(0xFFF06292),
  ];

  /// Reserverad för "Övriga"-skivan, som ska läsas som en samlingspost och
  /// aldrig förväxlas med en enskild enhet.
  static const Color pieOther = Color(0xFF546E7A);

  static Color get danger => _d ? Colors.redAccent : const Color(0xFFB3261E);

  /// Orange — "reject" och återställningsknappen. Egen färg, inte samma som
  /// [warn]: skillnaden mellan en varning och ett aktivt avslag ska synas.
  static Color get caution => _d ? Colors.orangeAccent : const Color(0xFFB4530A);

  /// Blått — DNAT/port forward.
  static Color get info => _d ? Colors.lightBlueAccent : const Color(0xFF1D4ED8);

  /// Tonad bakgrund för de LÅSTA default-deny-raderna i policylistan.
  static Color get dangerSurface =>
      _d ? const Color(0xFF2A1518) : const Color(0xFFFBE9E7);

  // Tonade banderollbakgrunder.
  static Color get warnSurface =>
      _d ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
  static Color get dangerBanner =>
      _d ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
  static Color get infoSurface =>
      _d ? const Color(0xFF0284C7) : const Color(0xFFDBEAFE);
  static Color get cautionSurface =>
      _d ? const Color(0xFF9A3412) : const Color(0xFFFFEDD5);

  /// Text ovanpå en statusfärgad knapp.
  static Color get onStatus => _d ? Colors.black : Colors.white;

  /// ThemeData för MaterialApp.
  static ThemeData themeData() {
    final base = _d ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      canvasColor: surface,
      cardColor: surface,
      dividerColor: border,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        surface: surface,
        error: danger,
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _d ? const Color(0xFF334155) : const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: 0.3),
      ),
    );
  }
}
