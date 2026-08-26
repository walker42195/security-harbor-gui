import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:security_harbor_gui/theme.dart';

/// WCAG 2.1 relativ luminans.
double _luminance(Color c) {
  double channel(double v) {
    v = v / 255.0;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel((c.r * 255).roundToDouble()) +
      0.7152 * channel((c.g * 255).roundToDouble()) +
      0.0722 * channel((c.b * 255).roundToDouble());
}

/// Lägger [fg] ovanpå [bg] enligt sin alfa.
///
/// Nödvändigt eftersom det mörka temat använder Materials genomskinliga
/// nyanser (Colors.white70, white38). Utan komposition har de SAMMA
/// RGB-värde som vitt, och kontrastberäkningen hade gett identiska siffror
/// för text, textMuted och textFaint — ett test som ser ut att mäta något
/// men i praktiken bara jämför vitt mot ytan.
Color _composite(Color fg, Color bg) {
  final a = fg.a;
  if (a >= 1.0) return fg;
  return Color.from(
    alpha: 1.0,
    red: fg.r * a + bg.r * (1 - a),
    green: fg.g * a + bg.g * (1 - a),
    blue: fg.b * a + bg.b * (1 - a),
  );
}

/// Kontrastkvot mellan två färger, 1:1 till 21:1. [a] läggs ovanpå [b].
double contrast(Color a, Color b) {
  final la = _luminance(_composite(a, b)), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // Det ljusa temat skickades först utan att kontrasten mätts, och
  // accentfärgerna (Materials *Accent-nyanser, gjorda för mörk bakgrund) blev
  // närmast osynliga mot vitt. De här testerna gör att det inte kan hända
  // igen — varken i ljust eller mörkt läge.
  for (final mode in AppThemeMode.values) {
    group('kontrast i ${mode.name}', () {
      setUp(() => AppTheme.mode = mode);
      tearDown(() => AppTheme.mode = AppThemeMode.dark);

      test('brödtext mot ytan klarar 4.5:1', () {
        expect(contrast(AppColors.text, AppColors.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(AppColors.text, AppColors.bg), greaterThanOrEqualTo(4.5));
      });

      test('sekundär text klarar 4.5:1', () {
        expect(contrast(AppColors.textMuted, AppColors.surface), greaterThanOrEqualTo(4.5));
      });

      // Svag text är avsiktligt nedtonad, men måste fortfarande gå att läsa.
      test('svag text klarar 3:1', () {
        expect(contrast(AppColors.textFaint, AppColors.surface), greaterThanOrEqualTo(3.0));
      });

      test('statusfärgerna klarar 3:1 mot ytan', () {
        final palette = {
          'accent': AppColors.accent,
          'ok': AppColors.ok,
          'warn': AppColors.warn,
          'danger': AppColors.danger,
          'caution': AppColors.caution,
          'info': AppColors.info,
        };
        palette.forEach((name, color) {
          expect(contrast(color, AppColors.surface), greaterThanOrEqualTo(3.0),
              reason: '$name mot surface i ${mode.name}');
        });
      });

      // Knapptext ovanpå en statusfärgad bakgrund. Det var precis den här
      // kombinationen som gick sönder: svart text låg kvar medan bakgrunden
      // mörknade i ljust läge.
      test('knapptext mot statusfärgad bakgrund klarar 4.5:1', () {
        final backgrounds = {
          'accent': AppColors.accent,
          'ok': AppColors.ok,
          'warn': AppColors.warn,
          'danger': AppColors.danger,
          'caution': AppColors.caution,
        };
        backgrounds.forEach((name, bg) {
          expect(contrast(AppColors.onStatus, bg), greaterThanOrEqualTo(4.5),
              reason: 'onStatus mot $name i ${mode.name}');
        });
        expect(contrast(AppColors.onAccent, AppColors.accent),
            greaterThanOrEqualTo(4.5));
      });

      test('ramen syns mot ytan', () {
        expect(contrast(AppColors.border, AppColors.surface), greaterThanOrEqualTo(1.2));
      });
    });
  }

  // Kontrastkvot är ett LUMINANS-mått och säger ingenting om huruvida rött
  // går att skilja från grönt — två färger kan ha nästan identisk luminans
  // och ändå vara uppenbart olika. Det som går att kontrollera meningsfullt
  // är att statusfärgerna faktiskt är olika värden, och att de inte råkar
  // kollapsa till samma i något läge. Att skilja dem åt VISUELLT bärs
  // dessutom inte bara av färgen: raderna har egna ikoner och texten
  // ACCEPT/DENY.
  test('statusfärgerna kollapsar inte till samma värde', () {
    for (final mode in AppThemeMode.values) {
      AppTheme.mode = mode;
      final palette = <String, Color>{
        'accent': AppColors.accent,
        'ok': AppColors.ok,
        'warn': AppColors.warn,
        'danger': AppColors.danger,
        'caution': AppColors.caution,
        'info': AppColors.info,
      };
      final unique = palette.values.map((c) => c.toARGB32()).toSet();
      expect(unique.length, palette.length,
          reason: 'två statusfärger är identiska i ${mode.name}: $palette');
    }
    AppTheme.mode = AppThemeMode.dark;
  });
}
