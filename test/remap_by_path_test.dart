import 'package:flutter_test/flutter_test.dart';
import 'package:hammm_music/providers/player_provider.dart';

void main() {
  group('remapIdsByPath', () {
    final library = {'/music/a.mp3': 101, '/music/b.mp3': 102};

    test('mapeia ID antigo para o novo quando o caminho ainda existe', () {
      final remap = remapIdsByPath(
        [1, 2],
        {1: '/music/a.mp3', 2: '/music/b.mp3'},
        library,
      );
      expect(remap, {1: 101, 2: 102});
    });

    test('ignora IDs que continuam válidos', () {
      expect(remapIdsByPath([101], {101: '/music/a.mp3'}, library), isEmpty);
    });

    test('ignora IDs sem caminho salvo ou com arquivo que sumiu', () {
      final remap = remapIdsByPath(
        [1, 2],
        {2: '/music/apagado.mp3'},
        library,
      );
      expect(remap, isEmpty);
    });
  });
}
