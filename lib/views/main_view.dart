import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import 'adhan_screen.dart';
import 'home_screen.dart';

/// Hosts both screens behind a bottom nav bar, sharing one AppController so
/// the playlist/schedule state stays consistent no matter which tab is
/// showing. IndexedStack keeps both screens alive (not rebuilt) when you
/// switch tabs, so scroll position etc. is preserved.
class MainView extends StatefulWidget {
  const MainView({super.key, required this.controller});

  final AppController controller;

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(controller: widget.controller),
          AdhanScreen(controller: widget.controller),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.mosque_outlined),
            selectedIcon: Icon(Icons.mosque),
            label: 'Adhan',
          ),
        ],
      ),
    );
  }
}