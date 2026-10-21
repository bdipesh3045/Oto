import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class DownloadBridge {
  static const channel = MethodChannel('oto/downloads');
  Future<void> initialize() async {
    // Preserve existing phone files and import terminal server history once.
    final oldPath = p.join(await getDatabasesPath(), 'oto_downloads.db');
    List<Map<String, dynamic>> legacy = [];
    if (await databaseExists(oldPath)) {
      final db = await openDatabase(oldPath, readOnly: true);
      try {
        final rows = await db.query('jobs');
        legacy = rows
            .map(
              (row) => Map<String, dynamic>.from(
                jsonDecode(row['data'] as String) as Map,
              ),
            )
            .toList();
      } finally {
        await db.close();
      }
    }
    await channel.invokeMethod<Object?>('initialize', {'legacyJobs': legacy});
    if (await databaseExists(oldPath)) await deleteDatabase(oldPath);
  }

  Future<TrackInfo> inspect(String url) async => TrackInfo.fromMap(
    Map<String, dynamic>.from(
      await channel.invokeMapMethod<String, dynamic>('inspect', {
            'url': youtubeUrl(url),
          }) ??
          {},
    ),
  );
  Future<List<DownloadJob>> jobs() async {
    final values = await channel.invokeListMethod<dynamic>('jobs') ?? [];
    return values
        .map((value) => DownloadJob(Map<String, dynamic>.from(value as Map)))
        .toList();
  }

  Future<void> enqueue(TrackInfo info, int bitrate) async {
    await channel.invokeMethod<String>('enqueue', {
      'info': info.toMap(),
      'bitrate': bitrate,
    });
  }

  Future<Map<String, dynamic>> engineStatus() async =>
      Map<String, dynamic>.from(
        await channel.invokeMapMethod<String, dynamic>('engineStatus') ?? {},
      );
  Future<Map<String, dynamic>> updateEngine() async =>
      Map<String, dynamic>.from(
        await channel.invokeMapMethod<String, dynamic>('updateEngine') ?? {},
      );
  Future<void> cancel(String id) =>
      channel.invokeMethod<void>('cancel', {'id': id});
  Future<void> remove(String id) =>
      channel.invokeMethod<void>('remove', {'id': id});
  Future<bool> export(Song song) async =>
      await channel.invokeMethod<bool>('export', {
        'path': song.path,
        'title': song.title,
      }) ??
      false;
  Future<void> dispose() async {
    /* Android foreground service owns active jobs. */
  }
}
