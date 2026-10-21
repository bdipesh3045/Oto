import 'package:flutter/material.dart';
import '../controller.dart';
import '../data/models.dart';
import 'components.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.controller,
    required this.onAdd,
  });
  final AppController controller;
  final VoidCallback onAdd;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final search = TextEditingController();
  String? category, artist;
  bool favorites = false, lastWeek = false;
  DurationFilter duration = DurationFilter.any;
  SongSort sort = SongSort.newest;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);
    if (category != null && !c.categories.contains(category)) category = null;
    if (artist != null && !c.songs.any((s) => s.artist == artist)) {
      artist = null;
    }
    final query = LibraryQuery(
      search: search.text,
      category: category,
      favorites: favorites,
      artist: artist,
      duration: duration,
      lastWeek: lastWeek,
      sort: sort,
    );
    final songs = query.apply(c.songs);
    return CustomScrollView(
      key: const PageStorageKey('library'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your music', style: theme.textTheme.headlineLarge),
                const SizedBox(height: 10),
                Text(
                  '${c.songs.length} ${c.songs.length == 1 ? 'song' : 'songs'} · Yours, even offline',
                  style: theme.textTheme.bodyLarge!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search songs or artists',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: search.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Clear search',
                            onPressed: () => setState(search.clear),
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('All songs'),
                        selected: category == null && !favorites,
                        onSelected: (_) => setState(() {
                          category = null;
                          favorites = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        avatar: Icon(
                          Icons.favorite_outline_rounded,
                          size: 17,
                          color: theme.colorScheme.primary,
                        ),
                        label: const Text('Favorites'),
                        selected: favorites,
                        onSelected: (_) => setState(() {
                          favorites = !favorites;
                          category = null;
                        }),
                      ),
                      for (final name in c.categories) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(name),
                          selected: category == name,
                          onSelected: (_) => setState(() {
                            category = category == name ? null : name;
                            favorites = false;
                          }),
                        ),
                      ],
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 18),
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
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => filters(context),
                      icon: Badge(
                        isLabelVisible: query.filterCount > 0,
                        label: Text('${query.filterCount}'),
                        child: const Icon(Icons.filter_list_rounded, size: 20),
                      ),
                      label: const Text('Filter'),
                    ),
                    PopupMenuButton<SongSort>(
                      tooltip: 'Sort songs',
                      initialValue: sort,
                      onSelected: (value) => setState(() => sort = value),
                      icon: const Icon(Icons.swap_vert_rounded),
                      itemBuilder: (_) => SongSort.values
                          .map(
                            (s) => CheckedPopupMenuItem(
                              value: s,
                              checked: sort == s,
                              child: Text(switch (s) {
                                SongSort.newest => 'Recently added',
                                SongSort.title => 'Song title',
                                SongSort.artist => 'Artist',
                                SongSort.duration => 'Duration',
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (songs.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: c.songs.isEmpty
                  ? Icons.library_music_outlined
                  : Icons.search_off_rounded,
              title: c.songs.isEmpty
                  ? 'A collection of your own'
                  : 'No songs match just yet',
              body: c.songs.isEmpty
                  ? 'Keep the songs you come back to.\nYour downloaded music will live here.'
                  : 'Try another search or clear your filters.',
              action: c.songs.isEmpty
                  ? 'Add your first song'
                  : 'Clear search & filters',
              onAction: c.songs.isEmpty
                  ? widget.onAdd
                  : () => setState(() {
                      search.clear();
                      category = null;
                      favorites = false;
                      artist = null;
                      duration = DurationFilter.any;
                      lastWeek = false;
                    }),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList.builder(
              itemCount: songs.length,
              itemBuilder: (context, i) => SongTile(
                key: ValueKey(songs[i].id),
                song: songs[i],
                controller: c,
                onPlay: () => c.play(songs[i], songs),
                onMore: () => songOptions(context, c, songs[i]),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> filters(BuildContext context) async {
    var selectedArtist = artist;
    var selectedDuration = duration;
    var recent = lastWeek;
    final artists =
        widget.controller.songs.map((s) => s.artist).toSet().toList()..sort();
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Find your mood',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => update(() {
                          selectedArtist = null;
                          selectedDuration = DurationFilter.any;
                          recent = false;
                        }),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    key: ValueKey(selectedArtist),
                    initialValue: selectedArtist ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Artist'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All artists'),
                      ),
                      ...artists.map(
                        (name) => DropdownMenuItem(
                          value: name,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        update(() => selectedArtist = v == '' ? null : v),
                  ),
                  const SizedBox(height: 24),
                  const Text('Song length'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: DurationFilter.values
                        .map(
                          (v) => ChoiceChip(
                            label: Text(switch (v) {
                              DurationFilter.any => 'Any length',
                              DurationFilter.underFour => 'Under 4 min',
                              DurationFilter.fourPlus => '4 min or longer',
                            }),
                            selected: selectedDuration == v,
                            onSelected: (_) =>
                                update(() => selectedDuration = v),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Added in the last 7 days'),
                    value: recent,
                    onChanged: (v) => update(() => recent = v),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheet, true),
                      child: const Text('Apply filters'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (applied == true && mounted) {
      setState(() {
        artist = selectedArtist;
        duration = selectedDuration;
        lastWeek = recent;
      });
    }
  }
}
