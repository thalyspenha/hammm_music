import 'package:flutter_test/flutter_test.dart';
import 'package:hammm_music/models/playlist.dart';

void main() {
  group('Playlist', () {
    test('toJson/fromJson roundtrip preserva id, nome e songIds', () {
      final playlist = Playlist(
        id: '123',
        name: 'Minha Playlist',
        songIds: [1, 2, 3],
      );

      final json = playlist.toJson();
      final restored = Playlist.fromJson(json);

      expect(restored.id, playlist.id);
      expect(restored.name, playlist.name);
      expect(restored.songIds, playlist.songIds);
    });

    test('construtor sem songIds inicia lista vazia', () {
      final playlist = Playlist(id: '1', name: 'Vazia');
      expect(playlist.songIds, isEmpty);
    });

    test('encodeList/decodeList roundtrip preserva múltiplas playlists', () {
      final playlists = [
        Playlist(id: 'a', name: 'Rock', songIds: [1, 2]),
        Playlist(id: 'b', name: 'Chill', songIds: []),
        Playlist(id: 'c', name: 'Favoritas', songIds: [5, 6, 7]),
      ];

      final encoded = Playlist.encodeList(playlists);
      final decoded = Playlist.decodeList(encoded);

      expect(decoded.length, 3);
      for (var i = 0; i < playlists.length; i++) {
        expect(decoded[i].id, playlists[i].id);
        expect(decoded[i].name, playlists[i].name);
        expect(decoded[i].songIds, playlists[i].songIds);
      }
    });

    test('decodeList de lista vazia retorna lista vazia', () {
      final decoded = Playlist.decodeList(Playlist.encodeList([]));
      expect(decoded, isEmpty);
    });

    test('name e songIds são mutáveis após criação (usado por rename/add)',
        () {
      final playlist = Playlist(id: '1', name: 'Original');
      playlist.name = 'Renomeada';
      playlist.songIds.add(42);

      expect(playlist.name, 'Renomeada');
      expect(playlist.songIds, [42]);
    });
  });
}
