import 'package:flutter/material.dart';

class ScheduleSettings {
  const ScheduleSettings({
    required this.enabled,
    required this.startTime,
    this.stopTime,
  });

  factory ScheduleSettings.defaults() => const ScheduleSettings(
        enabled: false,
        startTime: TimeOfDay(hour: 8, minute: 0),
      );

  final bool enabled;
  final TimeOfDay startTime;
  final TimeOfDay? stopTime;

  ScheduleSettings copyWith({
    bool? enabled,
    TimeOfDay? startTime,
    TimeOfDay? stopTime,
    bool clearStop = false,
  }) =>
      ScheduleSettings(
        enabled: enabled ?? this.enabled,
        startTime: startTime ?? this.startTime,
        stopTime: clearStop ? null : (stopTime ?? this.stopTime),
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'startHour': startTime.hour,
        'startMinute': startTime.minute,
        'stopHour': stopTime?.hour,
        'stopMinute': stopTime?.minute,
      };

  factory ScheduleSettings.fromJson(Map<String, dynamic> j) => ScheduleSettings(
        enabled: j['enabled'] as bool? ?? false,
        startTime: TimeOfDay(
          hour: j['startHour'] as int? ?? 8,
          minute: j['startMinute'] as int? ?? 0,
        ),
        stopTime: j['stopHour'] == null
            ? null
            : TimeOfDay(
                hour: j['stopHour'] as int,
                minute: j['stopMinute'] as int? ?? 0,
              ),
      );
}