
class Track {
  const Track({required this.id, required this.name, required this.path});

  final String id;
  final String name;
  final String path; // absolute path inside app-private storage

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'path': path};

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
      );
}