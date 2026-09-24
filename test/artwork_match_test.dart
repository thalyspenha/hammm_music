import 'package:flutter_test/flutter_test.dart';
import 'package:hammm_music/providers/player_provider.dart';

Map<String, dynamic> _result(String artist, String track) => {
      'artistName': artist,
      'trackName': track,
      'artworkUrl100': 'https://example.com/$track/100x100bb.jpg',
    };

void main() {
  group('pickArtworkUrl', () {
    test('retorna a URL em 500x500 quando artista e título batem', () {
      final url = pickArtworkUrl(
        [_result('Queen', 'Bohemian Rhapsody')],
        artist: 'Queen',
        title: 'Bohemian Rhapsody',
      );
      expect(url, 'https://example.com/Bohemian Rhapsody/500x500bb.jpg');
    });

    test('ignora resultados de outro artista e pega o primeiro que bate', () {
      final url = pickArtworkUrl(
        [
          _result('Cover Band', 'Bohemian Rhapsody'),
          _result('Queen', 'Bohemian Rhapsody (Remastered 2011)'),
        ],
        artist: 'Queen',
        title: 'Bohemian Rhapsody',
      );
      expect(url, contains('Remastered'));
    });

    test('compara sem diferenciar caixa, pontuação e "feat."', () {
      final url = pickArtworkUrl(
        [_result('Anitta feat. Outro', 'Envolver')],
        artist: 'ANITTA',
        title: 'envolver!',
      );
      expect(url, isNotNull);
    });

    test('retorna null quando nenhum resultado bate', () {
      final url = pickArtworkUrl(
        [_result('Outro Artista', 'Outra Faixa')],
        artist: 'Queen',
        title: 'Bohemian Rhapsody',
      );
      expect(url, isNull);
    });

    test('ignora resultados com campos ausentes', () {
      final url = pickArtworkUrl(
        [
          {'artistName': 'Queen', 'trackName': 'Bohemian Rhapsody'},
        ],
        artist: 'Queen',
        title: 'Bohemian Rhapsody',
      );
      expect(url, isNull);
    });
  });
}
