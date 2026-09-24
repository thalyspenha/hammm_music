import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hammm_music/theme/app_theme.dart';

void main() {
  group('readableAccent', () {
    test('mantém cor que já contrasta com o fundo', () {
      const color = Color(0xFFFFBE0B); // âmbar claro
      expect(readableAccent(color), color);
    });

    test('clareia cor escura até o contraste mínimo', () {
      const dark = Color(0xFF3A0A0A); // vermelho bem escuro
      expect(contrastRatio(dark, AppTheme.background),
          lessThan(minAccentContrast));
      final fixed = readableAccent(dark);
      expect(contrastRatio(fixed, AppTheme.background),
          greaterThanOrEqualTo(minAccentContrast));
    });

    test('preserva o matiz ao clarear', () {
      const dark = Color(0xFF0A2A0A); // verde escuro
      final fixed = readableAccent(dark);
      expect(HSLColor.fromColor(fixed).hue,
          closeTo(HSLColor.fromColor(dark).hue, 1));
    });

    test('preto vira uma cor legível (sem laço infinito)', () {
      final fixed = readableAccent(Colors.black);
      expect(contrastRatio(fixed, AppTheme.background),
          greaterThanOrEqualTo(minAccentContrast));
    });
  });

  group('accentFromPalette', () {
    test('descarta cinzas (sem saturação)', () {
      expect(accentFromPalette(const Color(0xFF202020)), isNull);
      expect(accentFromPalette(Colors.black), isNull);
    });

    test('retorna null para cor ausente', () {
      expect(accentFromPalette(null), isNull);
    });

    test('mantém cor saturada, ajustando o contraste', () {
      final c = accentFromPalette(const Color(0xFF3A0A0A))!;
      expect(contrastRatio(c, AppTheme.background),
          greaterThanOrEqualTo(minAccentContrast));
    });
  });
}
