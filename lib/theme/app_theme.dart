import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Contraste mínimo (razão WCAG) da cor de destaque sobre o fundo do app.
/// 4.5 cobre texto; ícones precisariam só de 3.
const minAccentContrast = 4.5;

/// Abaixo desta saturação (HSL) a cor extraída da capa é tratada como cinza:
/// clareada, ficaria parecida com o cinza dos ícones inativos.
const minAccentSaturation = 0.15;

/// Cor de destaque a partir da cor dominante da capa: `null` quando não há
/// cor ou ela é praticamente cinza (a UI cai para `songAccentColor()`);
/// senão a cor ajustada por [readableAccent].
Color? accentFromPalette(Color? color) {
  if (color == null) return null;
  if (HSLColor.fromColor(color).saturation < minAccentSaturation) return null;
  return readableAccent(color);
}

/// Razão de contraste WCAG entre duas cores (1 a 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Clareia [color] (mantendo matiz e saturação) até atingir
/// [minAccentContrast] contra [background]. Cores extraídas de capas escuras
/// deixariam ícones e textos de destaque quase invisíveis no tema escuro.
Color readableAccent(Color color, {Color background = AppTheme.background}) {
  if (contrastRatio(color, background) >= minAccentContrast) return color;
  var hsl = HSLColor.fromColor(color);
  while (hsl.lightness < 1.0) {
    hsl = hsl.withLightness(math.min(1.0, hsl.lightness + 0.05));
    if (contrastRatio(hsl.toColor(), background) >= minAccentContrast) break;
  }
  return hsl.toColor();
}

class AppTheme {
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF111118);
  static const Color card = Color(0xFF18181F);
  static const Color accent = Color(0xFF7C6AFF);
  static const Color textPrimary = Color(0xFFEEEEFF);
  static const Color textSecondary = Color(0xFF7777AA);
  static const Color divider = Color(0xFF22222E);
  static const Color accentLight = Color(0xFF9B8BFF);
  static const Color favorite = Color(0xFFF72585);
  static const Color destructive = Colors.redAccent;
  static const Color vinyl = Color(0xFF111111);

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
        onPrimary: textPrimary,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: divider,
        thumbColor: textPrimary,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        trackHeight: 2.5,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 14),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13),
        labelSmall: TextStyle(
          color: textSecondary,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
