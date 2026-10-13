import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';

class ScheduleCard extends StatelessWidget {
  const ScheduleCard({super.key, required this.controller});
 
  final AppController controller;
 
  Future<void> _pickStart(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: controller.settings.startTime,
    );
    if (picked != null) await controller.setStart(picked);
  }
 
  Future<void> _pickStop(BuildContext context) async {
    final start = controller.settings.startTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: controller.settings.stopTime ??
          start.replacing(hour: (start.hour + 2) % 24),
    );
    if (picked != null) await controller.setStop(picked);
  }
 
  String _nextRunText(BuildContext context) {
    if (!controller.settings.enabled) return 'Turned off';
    final next = controller.nextRun;
    if (next == null) return 'Not scheduled';
    final date = MaterialLocalizations.of(context).formatMediumDate(next);
    final time = TimeOfDay.fromDateTime(next).format(context);
    return 'Next run: $date, $time';
  }
 
  @override
  Widget build(BuildContext context) {
    final s = controller.settings;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Play automatically every day'),
            subtitle: Text(_nextRunText(context)),
            value: s.enabled,
            onChanged: controller.setEnabled,
          ),
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('Start time'),
            trailing: Text(
              s.startTime.format(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _pickStart(context),
          ),
          ListTile(
            leading: const Icon(Icons.stop_circle_outlined),
            title: const Text('Stop time (optional)'),
            subtitle: const Text('If set, the playlist repeats until then'),
            trailing: s.stopTime == null
                ? const Text('Off')
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.stopTime!.format(context)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => controller.setStop(null),
                      ),
                    ],
                  ),
            onTap: () => _pickStop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.icon(
                  onPressed:
                      controller.tracks.isEmpty ? null : controller.playNow,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play now'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.stopNow,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
                TextButton.icon(
                  onPressed: controller.openBatterySettings,
                  icon: const Icon(Icons.battery_saver),
                  label: const Text('Battery'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
