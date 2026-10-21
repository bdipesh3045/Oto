import 'dart:io';
import 'package:flutter/material.dart';
import '../controller.dart';
import '../data/models.dart';

class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    this.path = '',
    this.url = '',
    this.size = 56,
    this.radius = 12,
  });
  final String path, url;
  final double size, radius;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = ColoredBox(
      color: colors.surfaceContainerHigh,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: size.clamp(24, 80) * 0.55,
          color: colors.primary,
        ),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: path.isNotEmpty
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_, _, _) => fallback,
              )
            : url.startsWith('https://')
            ? Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
              )
            : fallback,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String title, body;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.controller,
    required this.onPlay,
    required this.onMore,
  });
  final Song song;
  final AppController controller;
  final VoidCallback onPlay, onMore;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = controller.current?.id == song.id;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      leading: Artwork(path: song.artwork),
      minLeadingWidth: 56,
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall!.copyWith(
          color: selected ? theme.colorScheme.primary : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${song.artist} · ${clockTime(song.duration)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (song.favorite)
            Icon(
              Icons.favorite_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          IconButton(
            tooltip: 'Options for ${song.title}',
            onPressed: onMore,
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      onTap: onPlay,
    );
  }
}

Future<String?> textDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  int maxLength = 30,
}) async {
  final text = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: text,
        autofocus: true,
        maxLength: maxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (text.text.trim().isNotEmpty) {
              Navigator.pop(context, text.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  // The route retains its TextField during the dismissal animation.
  Future<void>.delayed(const Duration(milliseconds: 400), text.dispose);
  return result;
}

Future<void> songOptions(
  BuildContext context,
  AppController c,
  Song song,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Artwork(path: song.artwork),
              title: Text(
                song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${song.artist}\nMP3 · ${song.bitrate} kbps · ${fileSize(song.bytes)}',
              ),
            ),
            const Divider(),
            for (final option in [
              (
                'favorite',
                song.favorite ? 'Remove from favorites' : 'Add to favorites',
                song.favorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
              ('categories', 'Edit categories', Icons.folder_outlined),
              ('rename', 'Rename song', Icons.edit_outlined),
              ('export', 'Export MP3', Icons.save_alt_rounded),
              ('delete', 'Delete from phone', Icons.delete_outline_rounded),
            ])
              ListTile(
                leading: Icon(option.$3),
                title: Text(option.$2),
                onTap: () => Navigator.pop(context, option.$1),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case 'favorite':
      await c.favorite(song);
    case 'rename':
      final name = await textDialog(
        context,
        title: 'Rename song',
        label: 'Song title',
        initial: song.title,
        maxLength: 150,
      );
      if (name != null) await c.rename(song, name);
    case 'categories':
      await categoryPicker(context, c, song);
    case 'export':
      await c.export(song);
    case 'delete':
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete this song?'),
          content: Text(
            '“${song.title}” will be removed from the library and this phone. Exported copies will remain.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep song'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) await c.delete(song);
    default:
      break;
  }
}

Future<void> categoryPicker(
  BuildContext context,
  AppController c,
  Song song,
) async {
  final chosen = song.categories.toSet();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File it your way',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text('A song can belong to more than one category.'),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final name in c.categories)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(name),
                            value: chosen.contains(name),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                chosen.add(name);
                              } else {
                                chosen.remove(name);
                              }
                            }),
                          ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.create_new_folder_outlined),
                          title: const Text('New category'),
                          onTap: () async {
                            final name = await textDialog(
                              context,
                              title: 'New category',
                              label: 'Category name',
                            );
                            if (name != null) {
                              await c.addCategory(name);
                              if (context.mounted) setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await c.categorize(song, chosen.toList());
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Text('Save categories'),
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
