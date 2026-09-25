import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule_settings.dart';
import '../models/track.dart';

/// Persists the playlist + settings, and copies picked audio files into
/// app-private storage so they keep playing even if the originals move.
class StorageService {
  static const _tracksKey = 'tracks_v1';
  static const _settingsKey = 'settings_v1';

  Future<Directory> _tracksDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'tracks'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<Track>> loadTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tracksKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .where((t) => File(t.path).existsSync())
        .toList();
  }

  Future<void> saveTracks(List<Track> tracks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _tracksKey, jsonEncode(tracks.map((t) => t.toJson()).toList()));
  }

  Future<ScheduleSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return ScheduleSettings.defaults();
    return ScheduleSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(ScheduleSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(s.toJson()));
  }

  /// Copies [sourcePath] into private storage and returns the new [Track].
  Future<Track> importFile(String sourcePath, String displayName) async {
    final dir = await _tracksDir();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final dest = p.join(dir.path, '${id}_${p.basename(sourcePath)}');
    await File(sourcePath).copy(dest);

    // The picker hands us a cached copy; remove it, but never touch a
    // user's original file.
    try {
      final tmp = await getTemporaryDirectory();
      if (p.isWithin(tmp.path, sourcePath)) await File(sourcePath).delete();
    } catch (_) {}

    return Track(
      id: id,
      name: p.basenameWithoutExtension(displayName),
      path: dest,
    );
  }

  Future<void> deleteFile(Track track) async {
    final f = File(track.path);
    if (await f.exists()) await f.delete();
  }
}