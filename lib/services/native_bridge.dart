import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Talks to the Kotlin side. Every call takes a [scheduleId] ("audio" or
/// "adhan") so the two schedules stay fully independent on the native side.
class NativeBridge {
  static const MethodChannel _channel = MethodChannel('adhan/native');

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  Future<DateTime?> sync({
    required bool enabled,
    required TimeOfDay start,
    TimeOfDay? stop,
    required List<String> paths,
    required String scheduleId,
    String label = 'Adhan',
    int reminderMinutes = 10,
  }) async {
    if (!_supported) return null;
    final millis = await _channel.invokeMethod<int>('sync', {
      'enabled': enabled,
      'hour': start.hour,
      'minute': start.minute,
      'stopHour': stop?.hour ?? -1,
      'stopMinute': stop?.minute ?? 0,
      'paths': paths,
      'label': label,
      'reminderMinutes': reminderMinutes,
      'scheduleId': scheduleId,
    });
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Fires the "prayer is approaching" reminder notification immediately,
  /// bypassing the actual scheduled time — for testing.
  Future<void> testReminderNotification() async {
    if (_supported) await _channel.invokeMethod('testReminderNotification');
  }

  Future<void> playNow({String scheduleId = 'audio'}) async {
    if (_supported) await _channel.invokeMethod('playNow', {'scheduleId': scheduleId});
  }

  Future<void> stop() async {
    if (_supported) await _channel.invokeMethod('stop');
  }

  Future<void> openBatterySettings() async {
    if (Platform.isAndroid) await _channel.invokeMethod('openBatterySettings');
  }
}