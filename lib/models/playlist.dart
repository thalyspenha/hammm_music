import 'dart:convert';

class Playlist {
  final String id;
  String name;
  List<int> songIds;
  // Caminho do arquivo de cada música (songId → path). Permite reconciliar a
  // playlist quando o MediaStore reindexa a biblioteca e os IDs mudam. Pode
  // faltar para músicas adicionadas antes deste campo existir.
  Map<int, String> songPaths;

  Playlist({
    required this.id,
    required this.name,
    List<int>? songIds,
    Map<int, String>? songPaths,
  })  : songIds = songIds ?? [],
        songPaths = songPaths ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songIds': songIds,
        'songPaths': songPaths.map((k, v) => MapEntry(k.toString(), v)),
      };

  // Tolerante a dados corrompidos: ignora IDs/caminhos inválidos em vez de
  // falhar a playlist inteira.
  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        songIds: (json['songIds'] as List? ?? const [])
            .whereType<num>()
            .map((n) => n.toInt())
            .toList(),
        songPaths: decodeIdPathMap(json['songPaths']),
      );

  static String encodeList(List<Playlist> playlists) =>
      jsonEncode(playlists.map((p) => p.toJson()).toList());

  static List<Playlist> decodeList(String raw) {
    final list = jsonDecode(raw) as List;
    return list.map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
  }
}

/// Decodifica um mapa JSON `{"songId": "path"}`, descartando entradas
/// inválidas. Retorna vazio para qualquer valor que não seja um mapa.
Map<int, String> decodeIdPathMap(Object? raw) {
  if (raw is! Map) return {};
  final result = <int, String>{};
  raw.forEach((key, value) {
    final id = int.tryParse(key.toString());
    if (id != null && value is String) result[id] = value;
  });
  return result;
}
