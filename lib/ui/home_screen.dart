import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller.dart';
import '../data/models.dart';
import 'components.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onLibrary,
    required this.onDownloads,
  });
  final AppController controller;
  final VoidCallback onLibrary, onDownloads;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final link = TextEditingController();
  @override
  void dispose() {
    link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);
    final preview = c.preview;
    final saved =
        preview != null && c.songs.any((s) => s.id == preview.videoId);
    final queued =
        preview != null &&
        c.jobs.any((j) => j.info.videoId == preview.videoId && j.active);
    return ListView(
      key: const PageStorageKey('home'),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Text(
          'Good songs.\nYours to keep.',
          style: theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: 14),
        Text(
          'Bring a song home. Listen wherever life takes you.',
          style: theme.textTheme.bodyLarge!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          key: const Key('youtube-link'),
          controller: link,
          enabled: !c.checking,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.search,
          onSubmitted: c.checking ? null : (_) => c.inspect(link.text),
          onChanged: (_) {
            if (c.preview != null) setState(() => c.preview = null);
          },
          decoration: InputDecoration(
            labelText: 'YouTube link',
            hintText: 'https://youtu.be/…',
            prefixIcon: const Icon(Icons.link_rounded),
            suffixIcon: IconButton(
              tooltip: 'Paste link',
              onPressed: c.checking
                  ? null
                  : () async {
                      final data = await Clipboard.getData(
                        Clipboard.kTextPlain,
                      );
                      if (data?.text != null && mounted) {
                        link.text = data!.text!.trim();
                        setState(() => c.preview = null);
                      }
                    },
              icon: const Icon(Icons.content_paste_rounded),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('find-song'),
            onPressed: c.checking
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    c.inspect(link.text);
                  },
            icon: c.checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded),
            label: Text(c.checking ? 'Finding your song…' : 'Find song'),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          c.checking
              ? 'Looking up this video on your phone.'
              : 'YouTube & YouTube Music · Individual videos up to 20 minutes',
          style: theme.textTheme.bodySmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        if (preview != null) ...[
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Artwork(url: preview.thumbnail, size: 80),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preview.title,
                            style: theme.textTheme.titleMedium,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            preview.artist,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${clockTime(preview.duration)} · MP3',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!saved && !queued) ...[
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
                    'Encoding quality; limited by the source audio.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: c.enqueuing
                        ? null
                        : saved
                        ? widget.onLibrary
                        : queued
                        ? widget.onDownloads
                        : () async {
                            if (await c.enqueue(preview)) widget.onDownloads();
                          },
                    icon: Icon(
                      saved
                          ? Icons.library_music_rounded
                          : queued
                          ? Icons.downloading_rounded
                          : Icons.download_rounded,
                    ),
                    label: Text(
                      saved
                          ? 'Open library'
                          : queued
                          ? 'View download'
                          : c.enqueuing
                          ? 'Adding to queue…'
                          : 'Download MP3',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 36),
        Row(
          children: [
            Expanded(
              child: Text('Recently kept', style: theme.textTheme.titleLarge),
            ),
            if (c.songs.isNotEmpty)
              TextButton(
                onPressed: widget.onLibrary,
                child: const Text('View all'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (c.songs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.headphones_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your next favorite belongs here.',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Paste a link above to start your offline collection.',
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ...c.songs
              .take(3)
              .map(
                (song) => SongTile(
                  song: song,
                  controller: c,
                  onPlay: () => c.play(song, c.songs),
                  onMore: () => songOptions(context, c, song),
                ),
              ),
      ],
    );
  }
}
