
import 'package:audio_scheduler/models/prayer_choice.dart';

/// Location + calculation choices used to compute real prayer times.
/// Latitude/longitude default to the Kaaba, Mecca — replace with your own
/// location (look it up on Google Maps if unsure).
class PrayerSettings {
  const PrayerSettings({
    required this.latitude,
    required this.longitude,
    required this.calculationMethod,
    required this.madhab,
    required this.prayer,
  });

  factory PrayerSettings.defaults() => const PrayerSettings(
        latitude: 21.4225,
        longitude: 39.8262,
        calculationMethod: 'muslim_world_league',
        madhab: 'shafi',
        prayer: PrayerChoice.fajr,
      );

  final double latitude;
  final double longitude;

  /// One of: muslim_world_league, egyptian, karachi, umm_al_qura, dubai,
  /// qatar, kuwait, moonsighting_committee, singapore, north_america.
  final String calculationMethod;

  /// 'shafi' (earlier Asr) or 'hanafi' (later Asr).
  final String madhab;

  final PrayerChoice prayer;

  PrayerSettings copyWith({
    double? latitude,
    double? longitude,
    String? calculationMethod,
    String? madhab,
    PrayerChoice? prayer,
  }) =>
      PrayerSettings(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        calculationMethod: calculationMethod ?? this.calculationMethod,
        madhab: madhab ?? this.madhab,
        prayer: prayer ?? this.prayer,
      );

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'calculationMethod': calculationMethod,
        'madhab': madhab,
        'prayer': prayer.name,
      };

  factory PrayerSettings.fromJson(Map<String, dynamic> j) => PrayerSettings(
        latitude: (j['latitude'] as num?)?.toDouble() ?? 21.4225,
        longitude: (j['longitude'] as num?)?.toDouble() ?? 39.8262,
        calculationMethod:
            j['calculationMethod'] as String? ?? 'muslim_world_league',
        madhab: j['madhab'] as String? ?? 'shafi',
        prayer: PrayerChoice.values.firstWhere(
          (p) => p.name == j['prayer'],
          orElse: () => PrayerChoice.fajr,
        ),
      );
}