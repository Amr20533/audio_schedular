import 'package:audio_scheduler/models/prayer_choice.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import '../controllers/app_controller.dart';

const _brandColor = Color(0xFFAC643B);
 
const _arabicNames = {
  PrayerChoice.fajr: 'الفجر',
  PrayerChoice.dhuhr: 'الظهر',
  PrayerChoice.asr: 'العصر',
  PrayerChoice.maghrib: 'المغرب',
  PrayerChoice.isha: 'العشاء',
};
 
/// Pure display + a "Refresh now" convenience button. All 5 prayers are
/// already auto-armed by the controller on every app launch — this card
/// never needs to be touched for the schedule to work.
class NextPrayerCard extends StatefulWidget {
  const NextPrayerCard({super.key, required this.controller});
 
  final AppController controller;
 
  @override
  State<NextPrayerCard> createState() => _NextPrayerCardState();
}
 
class _NextPrayerCardState extends State<NextPrayerCard> {
  Timer? _ticker;
 
  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }
 
  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
 
  String _formatCountdown(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
 
  @override
  Widget build(BuildContext context) {
    final next = widget.controller.nextUpcomingPrayer();
    final remaining = next == null ? null : next.time.difference(DateTime.now());
 
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _brandColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Next Prayer', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          if (next != null) ...[
            Text(
              _arabicNames[next.prayer] ?? next.prayer.name,
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              TimeOfDay.fromDateTime(next.time).format(context),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              _formatCountdown(remaining!.isNegative ? Duration.zero : remaining),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'All 5 prayers are scheduled automatically.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.controller.refreshAdhanSchedule,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Refresh now'),
              ),
            ),
          ] else
            const Text('Calculating…', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
