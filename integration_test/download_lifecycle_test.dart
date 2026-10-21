import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oto/data/download_bridge.dart';
import 'package:oto/data/models.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native migration, URL boundary, cancellation and dismissal persist',
    (tester) async {
      const legacyId = 'e8122bac-df3c-4dc4-89f5-0f8420ea1d73';
      const info = TrackInfo(
        videoId: 'jNQXAC9IVRw',
        url: 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
        title: 'Lifecycle test',
        artist: 'Synthetic job metadata',
        duration: 19,
      );
      final path = p.join(await getDatabasesPath(), 'oto_downloads.db');
      final old = await openDatabase(
        path,
        version: 1,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE jobs (id TEXT PRIMARY KEY, data TEXT NOT NULL)',
        ),
      );
      await old.insert('jobs', {
        'id': legacyId,
        'data': jsonEncode({
          ...info.toMap(),
          'jobId': legacyId,
          'state': 'queued',
          'bitrate': 128,
          '_server': 'http://127.0.0.1:1',
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await old.close();
      final bridge = DownloadBridge();
      await bridge.initialize();
      expect(await databaseExists(path), false);
      final migrated = (await bridge.jobs()).firstWhere(
        (job) => job.id == legacyId,
      );
      expect(migrated.state, 'interrupted');
      expect(migrated.data.containsKey('_server'), false);
      await bridge.remove(legacyId);
      await bridge.initialize();
      expect((await bridge.jobs()).any((job) => job.id == legacyId), false);
      for (final url in [
        'file:///etc/passwd',
        'https://youtube.com.evil.example/watch?v=jNQXAC9IVRw',
        'https://www.youtube.com/playlist?list=test',
      ]) {
        await expectLater(
          DownloadBridge.channel.invokeMethod<Object?>('inspect', {'url': url}),
          throwsA(isA<PlatformException>()),
        );
      }
      await expectLater(
        bridge.enqueue(info, 320),
        throwsA(isA<PlatformException>()),
      );
      final before = (await bridge.jobs()).map((job) => job.id).toSet();
      await bridge.enqueue(info, 128);
      final job = (await bridge.jobs()).firstWhere(
        (job) => !before.contains(job.id),
      );
      await bridge.cancel(job.id);
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(
        (await bridge.jobs()).firstWhere((entry) => entry.id == job.id).state,
        'cancelled',
      );
      await bridge.dispose();
      final reopened = DownloadBridge();
      await reopened.initialize();
      expect(
        (await reopened.jobs()).firstWhere((entry) => entry.id == job.id).state,
        'cancelled',
      );
      await reopened.remove(job.id);
      await reopened.initialize();
      expect((await reopened.jobs()).any((entry) => entry.id == job.id), false);
      expect((await reopened.updateEngine())['version'], isNotEmpty);
      await reopened.dispose();
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
