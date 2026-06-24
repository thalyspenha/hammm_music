import 'package:audio_service/audio_service.dart';
import 'package:on_audio_query/on_audio_query.dart';

class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final int duration; // milliseconds
  final String path;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.path,
  });

  factory Song.fromSongModel(SongModel model) {
    return Song(
      id: model.id,
      title: model.title,
      artist: model.artist ?? 'Artista Desconhecido',
      album: model.album ?? 'Álbum Desconhecido',
      duration: model.duration ?? 0,
      path: model.data,
    );
  }

  MediaItem toMediaItem() {
    return MediaItem(
      id: path,
      title: title,
      artist: artist,
      album: album,
      duration: Duration(milliseconds: duration),
    );
  }

  String get formattedDuration {
    final d = Duration(milliseconds: duration);
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
