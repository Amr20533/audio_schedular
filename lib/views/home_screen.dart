import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../widgets/schedule_card.dart';
import '../widgets/track_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Daily Audio Player')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: controller.importing ? null : controller.addTracks,
            icon: const Icon(Icons.library_add),
            label: const Text('Add audio'),
          ),
          body: controller.loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    ScheduleCard(controller: controller),
                    if (controller.importing) const LinearProgressIndicator(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Playlist (${controller.tracks.length}) · long-press to reorder',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ),
                    Expanded(child: _playlist()),
                  ],
                ),
        );
      },
    );
  }

  Widget _playlist() {
    if (controller.tracks.isEmpty) {
      return const Center(child: Text('No audio yet. Tap “Add audio”.'));
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: controller.tracks.length,
      onReorderItem: controller.reorder,
      itemBuilder: (context, i) {
        final track = controller.tracks[i];
        return TrackTile(
          key: ValueKey(track.id),
          index: i,
          track: track,
          onDelete: () => controller.removeTrack(track),
        );
      },
    );
  }
}