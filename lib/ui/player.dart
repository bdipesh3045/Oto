import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../controller.dart';
import '../data/models.dart';
import 'components.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final song = controller.current;
    if (song == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showPlayer(context, controller),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Row(
                  children: [
                    Artwork(path: song.artwork, size: 44, radius: 9),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: controller.playing ? 'Pause' : 'Play',
                      onPressed: controller.togglePlay,
                      icon: controller.busyPlayer
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              controller.playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                    ),
                    IconButton(
                      tooltip: 'Next song',
                      onPressed: controller.player?.hasNext == true
                          ? controller.next
                          : null,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<Duration>(
                valueListenable: controller.position,
                builder: (_, value, _) => LinearProgressIndicator(
                  minHeight: 2,
                  value:
                      (value.inMilliseconds /
                              math.max(
                                1,
                                (controller.player?.duration?.inMilliseconds ??
                                    song.duration * 1000),
                              ))
                          .clamp(0.0, 1.0),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showPlayer(BuildContext context, AppController controller) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => FullPlayer(controller: controller)),
  );
}

class FullPlayer extends StatelessWidget {
  const FullPlayer({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final c = controller;
      final song = c.current;
      final theme = Theme.of(context);
      if (song == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Now playing')),
          body: const Center(child: Text('Choose a song from your library.')),
        );
      }
      final width = math.min(MediaQuery.sizeOf(context).width - 64, 360.0);
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back to library',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          title: const Text('Now playing'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Song options',
              onPressed: () => songOptions(context, c, song),
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Artwork(
                        path: song.artwork,
                        size: width,
                        radius: 16,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                song.artist,
                                style: theme.textTheme.bodyLarge!.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: song.favorite
                              ? 'Remove from favorites'
                              : 'Add to favorites',
                          onPressed: () => c.favorite(song),
                          color: theme.colorScheme.primary,
                          icon: Icon(
                            song.favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SeekBar(controller: c, fallbackDuration: song.duration),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: 'Shuffle',
                          isSelected: c.player?.shuffleModeEnabled ?? false,
                          onPressed: c.shuffle,
                          icon: const Icon(Icons.shuffle_rounded),
                        ),
                        IconButton(
                          tooltip: 'Previous song',
                          iconSize: 36,
                          onPressed: c.previous,
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                        SizedBox.square(
                          dimension: 72,
                          child: IconButton.filled(
                            tooltip: c.playing ? 'Pause' : 'Play',
                            onPressed: c.togglePlay,
                            icon: c.busyPlayer
                                ? SizedBox.square(
                                    dimension: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  )
                                : Icon(
                                    c.playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 40,
                                  ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next song',
                          iconSize: 36,
                          onPressed: c.player?.hasNext == true ? c.next : null,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                        IconButton(
                          tooltip: switch (c.player?.loopMode) {
                            LoopMode.one => 'Repeat one song',
                            LoopMode.all => 'Repeat queue',
                            _ => 'Repeat off',
                          },
                          isSelected: c.player?.loopMode != LoopMode.off,
                          onPressed: c.repeat,
                          icon: Icon(
                            c.player?.loopMode == LoopMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MP3 · ${song.bitrate} kbps · On this phone',
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Playback queue',
                          onPressed: () => showQueue(context, c),
                          icon: const Icon(Icons.queue_music_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class SeekBar extends StatefulWidget {
  const SeekBar({
    super.key,
    required this.controller,
    required this.fallbackDuration,
  });
  final AppController controller;
  final int fallbackDuration;
  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? dragging;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: widget.controller.position,
    builder: (context, position, _) {
      final duration =
          widget.controller.player?.duration ??
          Duration(seconds: widget.fallbackDuration);
      final max = math.max(1.0, duration.inMilliseconds.toDouble());
      final value =
          dragging ?? position.inMilliseconds.toDouble().clamp(0.0, max);
      return Column(
        children: [
          Slider(
            padding: const EdgeInsets.symmetric(vertical: 12),
            min: 0,
            max: max,
            value: value.clamp(0, max),
            semanticFormatterCallback: (v) => clockTime(v ~/ 1000),
            onChanged: (v) => setState(() => dragging = v),
            onChangeEnd: (v) async {
              await widget.controller.seek(Duration(milliseconds: v.round()));
              if (mounted) setState(() => dragging = null);
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(clockTime(value ~/ 1000)),
              Text(clockTime(duration.inSeconds)),
            ],
          ),
        ],
      );
    },
  );
}

void showQueue(BuildContext context, AppController c) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Text(
                'Up next',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: c.queue.length,
                itemBuilder: (context, index) {
                  final song = c.queue[index];
                  return ListTile(
                    leading: Artwork(path: song.artwork, size: 44),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: c.current?.id == song.id,
                    trailing: Text(clockTime(song.duration)),
                    onTap: () async {
                      await c.run(() async {
                        await c.player?.seek(Duration.zero, index: index);
                      });
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
