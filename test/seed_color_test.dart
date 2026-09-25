import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hammm_music/theme/app_theme.dart';

void main() {
  group('seedColorFromPixels', () {
    test('sem pixels devolve null', () async {
      expect(await seedColorFromPixels([]), isNull);
    });

    test('capa cinza devolve null', () async {
      final pixels = List.filled(400, 0xFF808080);
      expect(await seedColorFromPixels(pixels), isNull);
    });

    test('capa de uma cor viva devolve essa cor', () async {
      final pixels = List.filled(400, 0xFFE53935);
      expect(await seedColorFromPixels(pixels), const Color(0xFFE53935));
    });

    test('prefere a cor viva a um fundo cinza majoritário', () async {
      final pixels = [
        ...List.filled(700, 0xFF303030),
        ...List.filled(300, 0xFF1E88E5),
      ];
      expect(await seedColorFromPixels(pixels), const Color(0xFF1E88E5));
    });
  });
}
