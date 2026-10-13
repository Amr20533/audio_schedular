import 'package:audio_scheduler/models/prayer_choice.dart';
import 'package:audio_scheduler/services/prayer_settings.dart';
import 'package:audio_scheduler/services/prayer_time_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/schedule_settings.dart';
import '../models/track.dart';
import '../services/native_bridge.dart';
import '../services/storage_services.dart';

class AppController extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final NativeBridge _native = NativeBridge();
  final PrayerTimesService _prayerTimes = PrayerTimesService();
 
  // Fixed — Cairo, Egyptian calculation method. No location picker.
  static const _egyptSettings = PrayerSettings(
    latitude: 30.0444,
    longitude: 31.2357,
    calculationMethod: 'egyptian',
    madhab: 'shafi',
    prayer: PrayerChoice.fajr, // unused placeholder; all 5 are scheduled regardless
  );
 
  // ---- "audio" pipeline (Home screen) ----
  List<Track> tracks = [];
  ScheduleSettings settings = ScheduleSettings.defaults();
  DateTime? nextRun;
 
  // ---- "adhan" pipeline (Adhan screen) ----
  String? adhanTrackPath;
  Map<PrayerChoice, DateTime> todayAdhanTimes = {};
 
  bool loading = true;
  bool importing = false;
 
  Future<void> init() async {
    tracks = await _storage.loadTracks();
    settings = await _storage.loadSettings();
 
    await _ensureAdhanFile();
    await refreshAdhanSchedule(); // auto-arms all 5 prayers — no button needed
 
    loading = false;
    notifyListeners();
    await _syncAudio();
  }
 
  Future<void> _ensureAdhanFile() async {
    try {
      final data = await rootBundle.load('assets/audio/adhan.mp3');
      adhanTrackPath = await _storage.ensureAdhanFile(data.buffer.asUint8List());
    } catch (e) {
      debugPrint('Could not load bundled Adhan file: $e');
    }
  }
 
  // ===================== "audio" pipeline (Home) =====================
 
  Future<void> _syncAudio() async {
    try {
      nextRun = await _native.sync(
        enabled: settings.enabled,
        start: settings.startTime,
        stop: settings.stopTime,
        paths: tracks.map((t) => t.path).toList(),
        scheduleId: 'audio',
        label: 'Audio',
      );
    } catch (e) {
      debugPrint('Audio native sync failed: $e');
    }
    notifyListeners();
  }
 
  Future<void> _persistAudio() async {
    await _storage.saveTracks(tracks);
    await _storage.saveSettings(settings);
    await _syncAudio();
  }
 
  Future<void> addTracks() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null) return;
 
    importing = true;
    notifyListeners();
    try {
      for (final f in result.files) {
        final path = f.path;
        if (path == null) continue;
        tracks = [...tracks, await _storage.importFile(path, f.name)];
      }
    } finally {
      importing = false;
    }
    await _persistAudio();
  }
 
  Future<void> removeTrack(Track track) async {
    tracks = tracks.where((t) => t.id != track.id).toList();
    notifyListeners();
    await _storage.deleteFile(track);
    await _persistAudio();
  }
 
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = [...tracks];
    list.insert(newIndex, list.removeAt(oldIndex));
    tracks = list;
    notifyListeners();
    await _persistAudio();
  }
 
  Future<void> setEnabled(bool value) async {
    settings = settings.copyWith(enabled: value);
    notifyListeners();
    await _persistAudio();
  }
 
  Future<void> setStart(TimeOfDay time) async {
    settings = settings.copyWith(startTime: time);
    notifyListeners();
    await _persistAudio();
  }
 
  Future<void> setStop(TimeOfDay? time) async {
    settings = time == null
        ? settings.copyWith(clearStop: true)
        : settings.copyWith(stopTime: time);
    notifyListeners();
    await _persistAudio();
  }
 
  Future<void> playNow() => _native.playNow(scheduleId: 'audio');
  Future<void> stopNow() => _native.stop();
  Future<void> openBatterySettings() => _native.openBatterySettings();
 
  // ===================== "adhan" pipeline (Adhan screen) =====================
 
  /// Computes all 5 prayer times for today and arms all 5 native alarms at
  /// once. Called automatically on every app launch — also callable
  /// manually (e.g. a "Refresh now" button) to force an immediate re-sync,
  /// but that's a convenience, not a requirement.
  Future<void> refreshAdhanSchedule() async {
    if (adhanTrackPath == null) return;
    todayAdhanTimes = _prayerTimes.allTimesToday(_egyptSettings);
 
    for (final entry in todayAdhanTimes.entries) {
      final name = entry.key.name;
      final label = name[0].toUpperCase() + name.substring(1);
      try {
        await _native.sync(
          enabled: true,
          start: TimeOfDay.fromDateTime(entry.value),
          stop: null,
          paths: [adhanTrackPath!],
          scheduleId: 'adhan_$name',
          label: label,
          reminderMinutes: 10,
        );
      } catch (e) {
        debugPrint('Auto-schedule failed for $name: $e');
      }
    }
    notifyListeners();
  }
 
  /// For the Adhan screen's countdown card — read-only.
  ({PrayerChoice prayer, DateTime time})? nextUpcomingPrayer() {
    try {
      return _prayerTimes.nextUpcoming(_egyptSettings);
    } catch (_) {
      return null;
    }
  }
 
  Future<void> testReminderNotification() => _native.testReminderNotification();
  Future<void> testAdhanPlayback() => _native.playNow(scheduleId: 'adhan_fajr');
}
