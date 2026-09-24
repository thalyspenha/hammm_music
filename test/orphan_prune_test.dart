import 'package:flutter_test/flutter_test.dart';
import 'package:hammm_music/providers/player_provider.dart';

void main() {
  group('orphanIdsToPrune', () {
    test('remove IDs que não existem mais na biblioteca', () {
      expect(orphanIdsToPrune({1, 2, 3, 4}, {1, 2, 3, 10}), {4});
    });

    test('não poda quando a biblioteca veio vazia', () {
      expect(orphanIdsToPrune({1, 2, 3}, {}), isEmpty);
    });

    test('não poda quando mais da metade dos IDs sumiu de uma vez', () {
      expect(orphanIdsToPrune({1, 2, 3, 4}, {1, 99}), isEmpty);
    });

    test('poda exatamente metade (limite inclusivo)', () {
      expect(orphanIdsToPrune({1, 2, 3, 4}, {1, 2}), {3, 4});
    });

    test('nada a podar quando não há referências', () {
      expect(orphanIdsToPrune({}, {1, 2}), isEmpty);
    });
  });
}
