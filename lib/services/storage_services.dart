import 'dart:convert';
import 'package:audio_scheduler/services/prayer_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/schedule_settings.dart';
import '../models/track.dart';

class StorageService {
  static const _tracksKey = 'tracks_v1';
  static const _settingsKey = 'settings_v1';
  static const _prayerKey = 'prayer_settings_v1';
  static const _autoPrayerKey = 'auto_prayer_v1';
  static const _triedAutoLocationKey = 'tried_auto_location_v1';
  static const _adhanSettingsKey = 'adhan_schedule_v1';
 
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
 
  Future<PrayerSettings> loadPrayerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prayerKey);
    if (raw == null) return PrayerSettings.defaults();
    return PrayerSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
 
  Future<void> savePrayerSettings(PrayerSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prayerKey, jsonEncode(s.toJson()));
  }
 
  /// Whether the app should recompute and re-apply the prayer time
  /// automatically every time it's opened (set true once the person taps
  /// "Use this time" in the Prayer Time card; set false if they go back to
  /// manually picking a fixed time in the Schedule card).
  Future<bool> loadAutoPrayerTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoPrayerKey) ?? false;
  }
 
  Future<void> saveAutoPrayerTime(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPrayerKey, value);
  }
 
  /// Whether the app has already attempted the automatic first-launch
  /// location lookup — attempted once only, so a denial doesn't keep
  /// re-prompting the person on every app open. They can still trigger it
  /// manually any time via the "Use my location" button.
  Future<bool> loadTriedAutoLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_triedAutoLocationKey) ?? false;
  }
 
  Future<void> saveTriedAutoLocation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_triedAutoLocationKey, value);
  }
 
  /// The Adhan schedule's own enabled/start/stop — completely separate
  /// storage from the Home screen's [ScheduleSettings], so one can never
  /// overwrite the other.
  Future<ScheduleSettings> loadAdhanSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_adhanSettingsKey);
    if (raw == null) return ScheduleSettings.defaults();
    return ScheduleSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
 
  Future<void> saveAdhanSchedule(ScheduleSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adhanSettingsKey, jsonEncode(s.toJson()));
  }
 
  /// A single fixed-path copy of the bundled Adhan audio, separate from the
  /// user's editable Home playlist. Written once; later calls reuse the
  /// same file instead of creating duplicates.
  Future<String> ensureAdhanFile(List<int> bytes) async {
    final dir = await _tracksDir();
    final path = p.join(dir.path, 'adhan_fixed.mp3');
    final f = File(path);
    if (!await f.exists()) {
      await f.writeAsBytes(bytes);
    }
    return path;
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
 
  /// Writes raw [bytes] into private storage as a new [Track]. Used for the
  /// bundled test tone / bundled Adhan, which skip file_picker entirely.
  Future<Track> importBytes(List<int> bytes, String fileName) async {
    final dir = await _tracksDir();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final dest = p.join(dir.path, '${id}_$fileName');
    await File(dest).writeAsBytes(bytes);
    return Track(
      id: id,
      name: p.basenameWithoutExtension(fileName),
      path: dest,
    );
  }
 
  Future<void> deleteFile(Track track) async {
    final f = File(track.path);
    if (await f.exists()) await f.delete();
  }
}
