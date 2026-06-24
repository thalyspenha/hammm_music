import 'dart:convert';

class Playlist {
  final String id;
  String name;
  List<int> songIds;

  Playlist({
    required this.id,
    required this.name,
    List<int>? songIds,
  }) : songIds = songIds ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songIds': songIds,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        songIds: (json['songIds'] as List).cast<int>(),
      );

  static String encodeList(List<Playlist> playlists) =>
      jsonEncode(playlists.map((p) => p.toJson()).toList());

  static List<Playlist> decodeList(String raw) {
    final list = jsonDecode(raw) as List;
    return list.map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
  }
}
