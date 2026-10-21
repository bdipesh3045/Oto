import 'package:flutter/material.dart';
import '../controller.dart';
import 'components.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({
    super.key,
    required this.controller,
    required this.onLibrary,
    required this.onAdd,
  });
  final AppController controller;
  final VoidCallback onLibrary, onAdd;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    final jobs = [...c.jobs]
      ..sort((a, b) => (b.active ? 1 : 0).compareTo(a.active ? 1 : 0));
    return CustomScrollView(
      key: const PageStorageKey('downloads'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('On their way', style: theme.textTheme.headlineLarge),
                const SizedBox(height: 10),
                Text(
                  c.activeCount == 0
                      ? 'A little patience. A lot of listening.'
                      : '${c.activeCount} ${c.activeCount == 1 ? 'song' : 'songs'} getting ready for offline listening.',
                  style: theme.textTheme.bodyLarge!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (jobs.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.download_for_offline_outlined,
              title: 'Nothing in the queue',
              body: 'Find a song you love. We’ll handle the rest.',
              action: 'Find a song',
              onAction: onAdd,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            sliver: SliverList.separated(
              itemCount: jobs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final job = jobs[i];
                return Container(
                  padding: const EdgeInsets.all(18),
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
                          Artwork(url: job.info.thumbnail, size: 52),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  job.info.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${job.info.artist} · ${job.bitrate} kbps',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (!job.active)
                            IconButton(
                              tooltip: 'Dismiss download history',
                              onPressed: () => c.dismiss(job),
                              icon: const Icon(Icons.close_rounded),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (job.active) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: {'downloading', 'saving'}.contains(job.state)
                                ? job.progress / 100
                                : null,
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              job.label,
                              style: theme.textTheme.labelLarge!.copyWith(
                                color: job.state == 'failed'
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          if (job.active)
                            TextButton(
                              onPressed: () => c.cancel(job),
                              child: const Text('Cancel'),
                            ),
                          if (job.retryable)
                            TextButton.icon(
                              onPressed: c.enqueuing
                                  ? null
                                  : () => c.retry(job),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          if (job.state == 'completed')
                            TextButton(
                              onPressed: onLibrary,
                              child: const Text('Library'),
                            ),
                        ],
                      ),
                      if (job.active)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'You can leave oto. Android will keep this download running; if it is stopped, tap Retry here.',
                          ),
                        ),
                      if (job.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            job.error!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
