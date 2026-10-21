import 'package:flutter/material.dart';
import '../controller.dart';
import '../data/models.dart';
import 'components.dart';

void showSettings(BuildContext context, AppController c) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final theme = Theme.of(context);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Make yourself at home',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 28),
                  DownloadEngine(controller: c),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  Text('Appearance', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_outlined),
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {c.themeMode},
                      onSelectionChanged: (v) => c.setTheme(v.first),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Default MP3 quality',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 128, label: Text('128 kbps')),
                        ButtonSegment(value: 192, label: Text('192 kbps')),
                      ],
                      selected: {c.bitrate},
                      onSelectionChanged: (v) => c.setBitrate(v.first),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Higher bitrate uses more space. Source quality still sets the limit.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined),
                    title: const Text('Manage categories'),
                    subtitle: Text('${c.categories.length} custom categories'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => manageCategories(context, c),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.offline_pin_outlined),
                    title: const Text('Stored on this phone'),
                    subtitle: Text(
                      '${c.songs.length} ${c.songs.length == 1 ? 'song' : 'songs'} · ${fileSize(c.songs.fold<int>(0, (sum, s) => sum + s.bytes))}\nUninstalling oto removes its library. Use Export MP3 to keep a separate copy.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'oto 0.2.0 · Made for your own listening.',
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

void manageCategories(BuildContext context, AppController c) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => AnimatedBuilder(
      animation: c,
      builder: (context, _) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your categories',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (c.categories.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Create categories for your moods, moments, and favorites.',
                          ),
                        ),
                      ...c.categories.map(
                        (name) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(name),
                          leading: const Icon(Icons.folder_outlined),
                          trailing: IconButton(
                            tooltip: 'Delete category $name',
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Delete “$name”?'),
                                  content: const Text(
                                    'Songs will stay in your library. Only this category will be removed.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete category'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await c.deleteCategory(name);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New category'),
                    onPressed: () async {
                      final name = await textDialog(
                        context,
                        title: 'New category',
                        label: 'Category name',
                      );
                      if (name != null) await c.addCategory(name);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class DownloadEngine extends StatelessWidget {
  const DownloadEngine({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Downloads on this phone', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'Audio downloads and MP3 conversion happen on your phone. No backend link is needed.',
        ),
        const SizedBox(height: 16),
        Text(
          'Download engine · ${c.engineVersion}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: c.updating || c.activeCount > 0 || c.checking
              ? null
              : c.updateEngine,
          icon: c.updating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.system_update_alt_rounded),
          label: Text(
            c.updating ? 'Updating engine…' : 'Check for engine updates',
          ),
        ),
        if (c.engineStatus != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Semantics(
              liveRegion: true,
              child: Text(c.engineStatus!, style: theme.textTheme.bodySmall),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'If a link stops working, update the engine and retry. Downloads continue with an Android notification when you leave oto.',
          style: theme.textTheme.bodySmall,
        ),
        if (c.activeCount > 0)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Finish or cancel active downloads before updating.'),
          ),
      ],
    );
  }
}
