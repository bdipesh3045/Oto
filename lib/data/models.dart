import 'dart:convert';

String youtubeUrl(String value) {
  final text = value.trim();
  final uri = Uri.tryParse(text);
  const hosts = {
    'youtube.com',
    'www.youtube.com',
    'music.youtube.com',
    'm.youtube.com',
    'youtu.be',
  };
  if (text.length > 2048 ||
      uri == null ||
      !{'https', 'http'}.contains(uri.scheme) ||
      !hosts.contains(uri.host.toLowerCase()) ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443 && uri.port != 80)) {
    throw const FormatException(
      'Paste a valid YouTube or YouTube Music video link.',
    );
  }
  final parts = uri.pathSegments;
  final id = uri.host == 'youtu.be' && parts.isNotEmpty
      ? parts.first
      : parts.isNotEmpty && parts.first == 'watch'
      ? uri.queryParameters['v']
      : parts.length > 1 && {'shorts', 'embed', 'live'}.contains(parts.first)
      ? parts[1]
      : null;
  if (id == null || !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
    throw const FormatException(
      'Use a link to one video, rather than a playlist or channel.',
    );
  }
  return 'https://www.youtube.com/watch?v=$id';
}

String clockTime(int seconds) {
  final minutes = seconds ~/ 60;
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}

String fileSize(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

class TrackInfo {
  const TrackInfo({
    required this.videoId,
    required this.url,
    required this.title,
    required this.artist,
    required this.duration,
    this.thumbnail = '',
  });
  final String videoId, url, title, artist, thumbnail;
  final int duration;
  factory TrackInfo.fromMap(Map<String, dynamic> m) => TrackInfo(
    videoId: m['videoId'] as String,
    url: m['url'] as String,
    title: m['title'] as String,
    artist: m['artist'] as String,
    duration: (m['duration'] as num).toInt(),
    thumbnail: m['thumbnail'] as String? ?? '',
  );
  Map<String, dynamic> toMap() => {
    'videoId': videoId,
    'url': url,
    'title': title,
    'artist': artist,
    'duration': duration,
    'thumbnail': thumbnail,
  };
}

class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.url,
    required this.duration,
    required this.path,
    required this.downloadedAt,
    required this.bitrate,
    required this.bytes,
    this.artwork = '',
    this.favorite = false,
    this.categories = const [],
  });
  final String id, title, artist, url, path, artwork;
  final int duration, bitrate, bytes;
  final DateTime downloadedAt;
  final bool favorite;
  final List<String> categories;
  factory Song.fromMap(Map<String, dynamic> m) => Song(
    id: m['id'] as String,
    title: m['title'] as String,
    artist: m['artist'] as String,
    url: m['url'] as String,
    duration: (m['duration'] as num).toInt(),
    path: m['path'] as String,
    artwork: m['artwork'] as String? ?? '',
    downloadedAt: DateTime.fromMillisecondsSinceEpoch(
      (m['downloadedAt'] as num).toInt(),
    ),
    bitrate: (m['bitrate'] as num).toInt(),
    bytes: (m['bytes'] as num).toInt(),
    favorite: m['favorite'] == 1,
    categories: (jsonDecode(m['categories'] as String? ?? '[]') as List)
        .cast<String>(),
  );
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'artist': artist,
    'url': url,
    'duration': duration,
    'path': path,
    'artwork': artwork,
    'downloadedAt': downloadedAt.millisecondsSinceEpoch,
    'bitrate': bitrate,
    'bytes': bytes,
    'favorite': favorite ? 1 : 0,
    'categories': jsonEncode(categories),
  };
  Song copyWith({String? title, bool? favorite, List<String>? categories}) =>
      Song(
        id: id,
        title: title ?? this.title,
        artist: artist,
        url: url,
        duration: duration,
        path: path,
        artwork: artwork,
        downloadedAt: downloadedAt,
        bitrate: bitrate,
        bytes: bytes,
        favorite: favorite ?? this.favorite,
        categories: categories ?? this.categories,
      );
}

class DownloadJob {
  DownloadJob(this.data);
  final Map<String, dynamic> data;
  String get id => data['jobId'] as String;
  TrackInfo get info => TrackInfo.fromMap(data);
  String get state => data['state'] as String;
  int get bitrate => (data['bitrate'] as num).toInt();
  double get progress =>
      (data['progress'] as num? ?? 0).toDouble().clamp(0, 100);
  String? get error => data['error'] as String?;
  bool get active => {
    'queued',
    'preparing',
    'downloading',
    'converting',
    'saving',
  }.contains(state);
  bool get retryable => {'failed', 'cancelled', 'interrupted'}.contains(state);
  String get label => switch (state) {
    'queued' => 'In queue',
    'preparing' => 'Preparing audio',
    'downloading' => 'Downloading audio',
    'converting' => 'Converting to MP3',
    'saving' => 'Saving MP3 to your phone',
    'completed' => 'Saved to your library',
    'cancelled' => 'Cancelled',
    'interrupted' => 'Interrupted',
    _ => 'Download failed',
  };
}

enum SongSort { newest, title, artist, duration }

enum DurationFilter { any, underFour, fourPlus }

class LibraryQuery {
  const LibraryQuery({
    this.search = '',
    this.category,
    this.favorites = false,
    this.artist,
    this.duration = DurationFilter.any,
    this.lastWeek = false,
    this.sort = SongSort.newest,
  });
  final String search;
  final String? category, artist;
  final bool favorites, lastWeek;
  final DurationFilter duration;
  final SongSort sort;
  int get filterCount =>
      (artist != null ? 1 : 0) +
      (duration != DurationFilter.any ? 1 : 0) +
      (lastWeek ? 1 : 0);
  List<Song> apply(List<Song> songs, {DateTime? now}) {
    final term = search.trim().toLowerCase();
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 7));
    final result = songs
        .where(
          (s) =>
              (term.isEmpty ||
                  '${s.title} ${s.artist}'.toLowerCase().contains(term)) &&
              (category == null || s.categories.contains(category)) &&
              (!favorites || s.favorite) &&
              (artist == null || s.artist == artist) &&
              (!lastWeek || !s.downloadedAt.isBefore(cutoff)) &&
              (duration == DurationFilter.any ||
                  (duration == DurationFilter.underFour
                      ? s.duration < 240
                      : s.duration >= 240)),
        )
        .toList();
    result.sort(
      (a, b) => switch (sort) {
        SongSort.newest => b.downloadedAt.compareTo(a.downloadedAt),
        SongSort.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        SongSort.artist => a.artist.toLowerCase().compareTo(
          b.artist.toLowerCase(),
        ),
        SongSort.duration => a.duration.compareTo(b.duration),
      },
    );
    return result;
  }
}
