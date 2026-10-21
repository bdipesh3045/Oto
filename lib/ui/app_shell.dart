import 'package:flutter/material.dart';
import '../controller.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'downloads_screen.dart';
import 'player.dart';
import 'settings.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);
    if (c.message != null) {
      final message = c.message!;
      c.clearMessage();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      });
    }
    if (c.loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Opening your library…'),
            ],
          ),
        ),
      );
    }
    if (c.startupError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 40),
                  const SizedBox(height: 16),
                  Text(c.startupError!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  const Text(
                    'Close oto and reopen it to try again.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final content = IndexedStack(
      index: index,
      children: [
        HomeScreen(
          controller: c,
          onLibrary: () => setState(() => index = 2),
          onDownloads: () => setState(() => index = 1),
        ),
        DownloadsScreen(
          controller: c,
          onLibrary: () => setState(() => index = 2),
          onAdd: () => setState(() => index = 0),
        ),
        LibraryScreen(controller: c, onAdd: () => setState(() => index = 0)),
      ],
    );
    Widget destinationIcon(IconData icon) =>
        icon == Icons.downloading_rounded && c.activeCount > 0
        ? Badge(label: Text('${c.activeCount}'), child: Icon(icon))
        : Icon(icon);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.music_note_rounded,
                color: theme.colorScheme.onPrimary,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'oto',
              style: theme.textTheme.headlineMedium!.copyWith(fontSize: 30),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings and appearance',
            onPressed: () => showSettings(context, c),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: index,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: (v) => setState(() => index = v),
                destinations: [
                  const NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: destinationIcon(Icons.downloading_rounded),
                    label: const Text('Downloads'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.library_music_outlined),
                    selectedIcon: Icon(Icons.library_music_rounded),
                    label: Text('Library'),
                  ),
                ],
              ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 840),
                        child: content,
                      ),
                    ),
                  ),
                  if (c.current != null) MiniPlayer(controller: c),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              animationDuration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              onDestinationSelected: (v) => setState(() => index = v),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: destinationIcon(Icons.downloading_rounded),
                  label: 'Downloads',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded),
                  label: 'Library',
                ),
              ],
            ),
    );
  }
}
