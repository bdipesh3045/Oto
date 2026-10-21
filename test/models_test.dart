import 'package:flutter_test/flutter_test.dart';
import 'package:oto/data/models.dart';

Song song(
  String id, {
  String title = 'Track',
  String artist = 'Artist',
  int duration = 180,
  bool favorite = false,
  List<String> categories = const [],
  int age = 0,
}) => Song(
  id: id,
  title: title,
  artist: artist,
  url: 'https://www.youtube.com/watch?v=$id',
  duration: duration,
  path: '/audio/$id/track.mp3',
  downloadedAt: DateTime(2026, 10, 19).subtract(Duration(days: age)),
  bitrate: 192,
  bytes: 2000000,
  favorite: favorite,
  categories: categories,
);

void main() {
  group('YouTube link normalization', () {
    for (final url in [
      'https://youtu.be/BaW_jenozKc?t=3',
      'https://music.youtube.com/watch?v=BaW_jenozKc&list=123',
      'https://www.youtube.com/shorts/BaW_jenozKc',
      'https://m.youtube.com/watch?v=BaW_jenozKc',
    ]) {
      test(
        url,
        () => expect(
          youtubeUrl(url),
          'https://www.youtube.com/watch?v=BaW_jenozKc',
        ),
      );
    }
    for (final url in [
      'https://youtube.com.evil.example/watch?v=BaW_jenozKc',
      'file:///etc/passwd',
      'https://www.youtube.com/playlist?list=123',
      'https://youtube.com/watch?v=short',
      'https://youtube.com@evil.example/watch?v=BaW_jenozKc',
      'https://youtube.com:8080/watch?v=BaW_jenozKc',
    ]) {
      test(
        'rejects $url',
        () => expect(() => youtubeUrl(url), throwsFormatException),
      );
    }
  });
  test('song serialization preserves edits, categories and timestamps', () {
    final original = song(
      'one',
      favorite: true,
      categories: ['Workout', 'Evening'],
    ).copyWith(title: 'Edited title');
    final restored = Song.fromMap(original.toMap());
    expect(restored.toMap(), original.toMap());
  });
  final songs = [
    song(
      'one',
      title: 'Quiet Morning',
      artist: 'Mina',
      duration: 180,
      favorite: true,
      categories: ['Chill'],
    ),
    song(
      'two',
      title: 'Long Way Home',
      artist: 'Noah',
      duration: 300,
      categories: ['Workout'],
      age: 10,
    ),
    song(
      'three',
      title: 'Evening Light',
      artist: 'Mina',
      duration: 240,
      categories: ['Chill'],
      age: 2,
    ),
  ];
  test('search, category, favorite and artist filters compose', () {
    final result = const LibraryQuery(
      search: 'quiet',
      category: 'Chill',
      favorites: true,
      artist: 'Mina',
    ).apply(songs);
    expect(result.map((s) => s.id), ['one']);
  });
  test('duration boundary and date cutoff are consistent', () {
    expect(
      const LibraryQuery(
        duration: DurationFilter.underFour,
      ).apply(songs).map((s) => s.id),
      ['one'],
    );
    expect(
      const LibraryQuery(
        duration: DurationFilter.fourPlus,
        lastWeek: true,
      ).apply(songs, now: DateTime(2026, 10, 19)).map((s) => s.id),
      ['three'],
    );
  });
  test('sorting does not mutate the stored library', () {
    expect(
      const LibraryQuery(sort: SongSort.title).apply(songs).map((s) => s.id),
      ['three', 'two', 'one'],
    );
    expect(songs.first.id, 'one');
  });
  test('cancelled and interrupted downloads are retryable, never active', () {
    for (final state in ['cancelled', 'interrupted', 'failed']) {
      final job = DownloadJob({
        'jobId': 'job',
        'state': state,
        'progress': 47,
        'bitrate': 128,
      });
      expect(job.active, false);
      expect(job.retryable, true);
    }
  });
}
