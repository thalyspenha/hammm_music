import 'package:flutter_test/flutter_test.dart';
import 'package:hammm_music/models/song.dart';

void main() {
  group('Song', () {
    test('formattedDuration formata mm:ss com zero à esquerda', () {
      final song = Song(
        id: 1,
        title: 'Faixa',
        artist: 'Artista',
        album: 'Álbum',
        duration: 65000, // 1min 5s
        path: '/music/faixa.mp3',
      );
      expect(song.formattedDuration, '01:05');
    });

    test('formattedDuration lida com duração zero', () {
      final song = Song(
        id: 2,
        title: 'Faixa',
        artist: 'Artista',
        album: 'Álbum',
        duration: 0,
        path: '/music/faixa.mp3',
      );
      expect(song.formattedDuration, '00:00');
    });

    test('formattedDuration lida com mais de uma hora (remainder de minutos)',
        () {
      final song = Song(
        id: 3,
        title: 'Faixa',
        artist: 'Artista',
        album: 'Álbum',
        duration: 3725000, // 1h02min05s
        path: '/music/faixa.mp3',
      );
      expect(song.formattedDuration, '02:05');
    });

    test('igualdade e hashCode são baseados apenas no id', () {
      final a = Song(
        id: 7,
        title: 'Título A',
        artist: 'Artista A',
        album: 'Álbum A',
        duration: 1000,
        path: '/a.mp3',
      );
      final b = Song(
        id: 7,
        title: 'Título B (diferente)',
        artist: 'Artista B',
        album: 'Álbum B',
        duration: 9999,
        path: '/b.mp3',
      );
      final c = Song(
        id: 8,
        title: 'Título A',
        artist: 'Artista A',
        album: 'Álbum A',
        duration: 1000,
        path: '/a.mp3',
      );

      expect(a, equals(b)); // mesmo id, campos diferentes -> ainda igual
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c))); // id diferente -> diferente
    });

    test('toMediaItem mapeia campos corretamente', () {
      final song = Song(
        id: 10,
        title: 'Minha Música',
        artist: 'Meu Artista',
        album: 'Meu Álbum',
        duration: 180000,
        path: '/music/minha.mp3',
      );
      final item = song.toMediaItem();

      expect(item.id, '/music/minha.mp3');
      expect(item.title, 'Minha Música');
      expect(item.artist, 'Meu Artista');
      expect(item.album, 'Meu Álbum');
      expect(item.duration, const Duration(milliseconds: 180000));
    });

    test('hasKnownArtist é falso para placeholders de artista', () {
      Song withArtist(String artist) => Song(
            id: 1,
            title: 'Faixa',
            artist: artist,
            album: 'Álbum',
            duration: 60000,
            path: '/music/faixa.mp3',
          );
      expect(withArtist('Queen').hasKnownArtist, isTrue);
      expect(withArtist(Song.unknownArtist).hasKnownArtist, isFalse);
      expect(withArtist('<unknown>').hasKnownArtist, isFalse);
      expect(withArtist('').hasKnownArtist, isFalse);
    });
  });
}
