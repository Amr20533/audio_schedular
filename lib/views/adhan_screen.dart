import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../widgets/next_prayer_card.dart';

/// Countdown card, hardcoded for Egypt, plus a small debug section to test
/// the two notification types without waiting for the real scheduled time.
class AdhanScreen extends StatelessWidget {
  const AdhanScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Adhan')),
          body: controller.loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    NextPrayerCard(controller: controller),
                    const SizedBox(height: 16),
                    _DebugNotificationButtons(controller: controller),
                  ],
                ),
        );
      },
    );
  }
}

class _DebugNotificationButtons extends StatelessWidget {
  const _DebugNotificationButtons({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Test notifications', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Fires each notification right now, without waiting for the actual scheduled time.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: controller.testReminderNotification,
                  icon: const Icon(Icons.notifications_outlined),
                  label: const Text('Test reminder'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.testAdhanPlayback,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Test Adhan playback'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}