import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class LibraryRepository {
  late final Database db;
  Future<void> open() async {
    db = await openDatabase(
      p.join(await getDatabasesPath(), 'oto.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE songs (id TEXT PRIMARY KEY, title TEXT NOT NULL, artist TEXT NOT NULL, url TEXT NOT NULL, duration INTEGER NOT NULL, path TEXT NOT NULL, artwork TEXT NOT NULL, downloadedAt INTEGER NOT NULL, bitrate INTEGER NOT NULL, bytes INTEGER NOT NULL, favorite INTEGER NOT NULL, categories TEXT NOT NULL)',
        );
        await db.execute('CREATE TABLE categories (name TEXT PRIMARY KEY)');
        await db.execute('CREATE TABLE imports (jobId TEXT PRIMARY KEY)');
      },
    );
  }

  Future<List<Song>> songs() async => (await db.query(
    'songs',
    orderBy: 'downloadedAt DESC',
  )).map(Song.fromMap).toList();
  Future<List<String>> categories() async => (await db.query(
    'categories',
    orderBy: 'name COLLATE NOCASE',
  )).map((m) => m['name'] as String).toList();
  Future<void> save(Song song) async =>
      db.update('songs', song.toMap(), where: 'id = ?', whereArgs: [song.id]);
  Future<void> delete(String id) async =>
      db.delete('songs', where: 'id = ?', whereArgs: [id]);
  Future<void> addCategory(String name) async => db.insert('categories', {
    'name': name,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
  Future<void> deleteCategory(String name) async {
    await db.transaction((tx) async {
      final songs = await tx.query('songs');
      for (final row in songs) {
        final song = Song.fromMap(row);
        if (song.categories.contains(name)) {
          await tx.update(
            'songs',
            {
              'categories': jsonEncode(
                song.categories.where((c) => c != name).toList(),
              ),
            },
            where: 'id = ?',
            whereArgs: [song.id],
          );
        }
      }
      await tx.delete('categories', where: 'name = ?', whereArgs: [name]);
    });
  }

  Future<bool> importJob(DownloadJob job) async => db.transaction((tx) async {
    if ((await tx.query(
      'imports',
      where: 'jobId = ?',
      whereArgs: [job.id],
    )).isNotEmpty) {
      return false;
    }
    final m = job.data;
    final info = job.info;
    final song = Song(
      id: info.videoId,
      title: info.title,
      artist: info.artist,
      url: info.url,
      duration: info.duration,
      path: m['path'] as String,
      artwork: m['artwork'] as String? ?? '',
      downloadedAt: DateTime.fromMillisecondsSinceEpoch(
        (m['completedAt'] as num).toInt(),
      ),
      bitrate: job.bitrate,
      bytes: (m['bytes'] as num).toInt(),
    );
    await tx.insert(
      'songs',
      song.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await tx.insert('imports', {'jobId': job.id});
    return true;
  });
}
