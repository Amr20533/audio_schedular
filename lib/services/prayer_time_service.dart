import 'package:adhan/adhan.dart';
import 'package:audio_scheduler/models/prayer_choice.dart';
import 'package:audio_scheduler/services/prayer_settings.dart';

class PrayerTimesService {
  CalculationParameters _paramsFor(String method) {
    switch (method) {
      case 'egyptian':
        return CalculationMethod.egyptian.getParameters();
      case 'karachi':
        return CalculationMethod.karachi.getParameters();
      case 'umm_al_qura':
        return CalculationMethod.umm_al_qura.getParameters();
      case 'dubai':
        return CalculationMethod.dubai.getParameters();
      case 'qatar':
        return CalculationMethod.qatar.getParameters();
      case 'kuwait':
        return CalculationMethod.kuwait.getParameters();
      case 'moonsighting_committee':
        return CalculationMethod.moon_sighting_committee.getParameters();
      case 'singapore':
        return CalculationMethod.singapore.getParameters();
      case 'north_america':
        return CalculationMethod.north_america.getParameters();
      case 'muslim_world_league':
      default:
        return CalculationMethod.muslim_world_league.getParameters();
    }
  }
 
  /// The next upcoming occurrence of [settings.prayer]: today's time if it
  /// hasn't happened yet, otherwise tomorrow's.
  DateTime nextOccurrence(PrayerSettings settings) {
    final coords = Coordinates(settings.latitude, settings.longitude);
    final params = _paramsFor(settings.calculationMethod)
      ..madhab = settings.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
 
    final now = DateTime.now();
    final today = PrayerTimes(coords, DateComponents.from(now), params);
    final todayValue = _valueFor(today, settings.prayer);
    if (todayValue.isAfter(now)) return todayValue;
 
    final tomorrow = PrayerTimes(
      coords,
      DateComponents.from(now.add(const Duration(days: 1))),
      params,
    );
    return _valueFor(tomorrow, settings.prayer);
  }
 
  /// The single soonest prayer across all five — whichever one is actually
  /// coming up next, not a manually picked one.
  ({PrayerChoice prayer, DateTime time}) nextUpcoming(PrayerSettings settings) {
    final coords = Coordinates(settings.latitude, settings.longitude);
    final params = _paramsFor(settings.calculationMethod)
      ..madhab = settings.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
 
    final now = DateTime.now();
    final today = PrayerTimes(coords, DateComponents.from(now), params);
    final todaysList = [
      (prayer: PrayerChoice.fajr, time: today.fajr),
      (prayer: PrayerChoice.dhuhr, time: today.dhuhr),
      (prayer: PrayerChoice.asr, time: today.asr),
      (prayer: PrayerChoice.maghrib, time: today.maghrib),
      (prayer: PrayerChoice.isha, time: today.isha),
    ];
 
    final upcoming = todaysList.where((p) => p.time.isAfter(now)).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (upcoming.isNotEmpty) return upcoming.first;
 
    // Everything today has passed — the next one is tomorrow's Fajr.
    final tomorrow = PrayerTimes(
      coords,
      DateComponents.from(now.add(const Duration(days: 1))),
      params,
    );
    return (prayer: PrayerChoice.fajr, time: tomorrow.fajr);
  }
 
  /// All five prayer times for today, in one shot — used to auto-arm every
  /// prayer at once rather than requiring one manually chosen prayer.
  Map<PrayerChoice, DateTime> allTimesToday(PrayerSettings settings) {
    final coords = Coordinates(settings.latitude, settings.longitude);
    final params = _paramsFor(settings.calculationMethod)
      ..madhab = settings.madhab == 'hanafi' ? Madhab.hanafi : Madhab.shafi;
    final today = PrayerTimes(coords, DateComponents.from(DateTime.now()), params);
    return {
      PrayerChoice.fajr: today.fajr,
      PrayerChoice.dhuhr: today.dhuhr,
      PrayerChoice.asr: today.asr,
      PrayerChoice.maghrib: today.maghrib,
      PrayerChoice.isha: today.isha,
    };
  }
 
  DateTime _valueFor(PrayerTimes times, PrayerChoice choice) {
    switch (choice) {
      case PrayerChoice.fajr:
        return times.fajr;
      case PrayerChoice.dhuhr:
        return times.dhuhr;
      case PrayerChoice.asr:
        return times.asr;
      case PrayerChoice.maghrib:
        return times.maghrib;
      case PrayerChoice.isha:
        return times.isha;
    }
  }
}
