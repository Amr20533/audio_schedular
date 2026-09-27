import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/schedule_settings.dart';
import '../models/track.dart';
import '../services/native_bridge.dart';
import '../services/storage_services.dart';

/// Single source of truth for the UI. Every change is saved and pushed to
/// the native layer so the daily alarm always matches what you see.
class AppController extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final NativeBridge _native = NativeBridge();

  List<Track> tracks = [];
  ScheduleSettings settings = ScheduleSettings.defaults();
  DateTime? nextRun;
  bool loading = true;
  bool importing = false;

  Future<void> init() async {
    tracks = await _storage.loadTracks();
    settings = await _storage.loadSettings();
    loading = false;
    notifyListeners();
    await _sync(); // re-arm the alarm on every launch
  }

  Future<void> _sync() async {
    try {
      nextRun = await _native.sync(
        enabled: settings.enabled,
        start: settings.startTime,
        stop: settings.stopTime,
        paths: tracks.map((t) => t.path).toList(),
      );
    } catch (e) {
      debugPrint('Native sync failed: $e');
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await _storage.saveTracks(tracks);
    await _storage.saveSettings(settings);
    await _sync();
  }

  // ---- playlist ----------------------------------------------------------

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
    await _persist();
  }

  Future<void> removeTrack(Track track) async {
    tracks = tracks.where((t) => t.id != track.id).toList();
    notifyListeners();
    await _storage.deleteFile(track);
    await _persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = [...tracks];
    list.insert(newIndex, list.removeAt(oldIndex));
    tracks = list;
    notifyListeners();
    await _persist();
  }

  // ---- schedule ----------------------------------------------------------

  Future<void> setEnabled(bool value) async {
    settings = settings.copyWith(enabled: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setStart(TimeOfDay time) async {
    settings = settings.copyWith(startTime: time);
    notifyListeners();
    await _persist();
  }

  Future<void> setStop(TimeOfDay? time) async {
    settings = time == null
        ? settings.copyWith(clearStop: true)
        : settings.copyWith(stopTime: time);
    notifyListeners();
    await _persist();
  }

  // ---- manual controls ---------------------------------------------------

  Future<void> playNow() => _native.playNow();
  Future<void> stopNow() => _native.stop();
  Future<void> openBatterySettings() => _native.openBatterySettings();
}