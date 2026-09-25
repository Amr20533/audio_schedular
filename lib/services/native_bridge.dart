import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Talks to the Kotlin side (alarm + playback service) over a MethodChannel.
class NativeBridge {
  static const MethodChannel _channel = MethodChannel('adhan/native');

  /// Hands the current schedule + playlist to Android and (re)arms the alarm.
  /// Returns the next start time, or null when disabled.
  Future<DateTime?> sync({
    required bool enabled,
    required TimeOfDay start,
    TimeOfDay? stop,
    required List<String> paths,
  }) async {
    if (!Platform.isAndroid) return null;
    final millis = await _channel.invokeMethod<int>('sync', {
      'enabled': enabled,
      'hour': start.hour,
      'minute': start.minute,
      'stopHour': stop?.hour ?? -1,
      'stopMinute': stop?.minute ?? 0,
      'paths': paths,
    });
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> playNow() async {
    if (Platform.isAndroid) await _channel.invokeMethod('playNow');
  }

  Future<void> stop() async {
    if (Platform.isAndroid) await _channel.invokeMethod('stop');
  }

  Future<void> openBatterySettings() async {
    if (Platform.isAndroid) await _channel.invokeMethod('openBatterySettings');
  }
}