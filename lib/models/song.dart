import 'package:audio_service/audio_service.dart';
import 'package:on_audio_query/on_audio_query.dart';

class Song {
  static const unknownArtist = 'Artista Desconhecido';

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
      artist: model.artist ?? unknownArtist,
      album: model.album ?? 'Álbum Desconhecido',
      duration: model.duration ?? 0,
      path: model.data,
    );
  }

  // O MediaStore usa "<unknown>" quando o arquivo não tem tag de artista.
  bool get hasKnownArtist =>
      artist.isNotEmpty && artist != unknownArtist && artist != '<unknown>';

  MediaItem toMediaItem() {
    return MediaItem(
      id: path,
      title: title,
      artist: artist,
      album: album,
      duration: Duration(milliseconds: duration),
    );
  }

  String get formattedDuration =>
      formatDuration(Duration(milliseconds: duration));

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Formata uma duração como `mm:ss`, ou `h:mm:ss` a partir de 1 hora.
String formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) return '${d.inHours}:$minutes:$seconds';
  return '$minutes:$seconds';
}
