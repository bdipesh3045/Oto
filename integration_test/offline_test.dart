import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:oto/controller.dart';
import 'package:oto/data/models.dart';
import 'package:oto/data/repository.dart';
import 'package:oto/main.dart';
import 'fixtures/tone.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android persistence, import receipts, categories and real offline playback',
    (tester) async {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.oto.oto.playback',
        androidNotificationChannelName: 'Music playback',
        androidNotificationIcon: 'drawable/ic_music_note',
      );
      final store = LibraryRepository();
      await store.open();
      final support = await getApplicationSupportDirectory();
      final folder = Directory('${support.path}/audio/integration-tone');
      await folder.create(recursive: true);
      final file = File('${folder.path}/track.mp3');
      await file.writeAsBytes(base64Decode(testTone));
      DownloadJob fixture(String receipt) => DownloadJob({
        'jobId': receipt,
        'videoId': 'fixture0001',
        'url': 'https://www.youtube.com/watch?v=fixture0001',
        'title': 'Integration test tone',
        'artist': 'Synthetic test audio',
        'duration': 8,
        'thumbnail': '',
        'path': file.path,
        'artwork': '',
        'bitrate': 32,
        'bytes': file.lengthSync(),
        'state': 'completed',
        'completedAt': DateTime.now().millisecondsSinceEpoch,
      });
      // The receipt is durable: polling completed history cannot resurrect deletions.
      await store.db.delete(
        'imports',
        where: 'jobId LIKE ?',
        whereArgs: ['integration-%'],
      );
      await store.delete('fixture0001');
      expect(await store.importJob(fixture('integration-first')), true);
      expect(await store.importJob(fixture('integration-first')), false);
      await store.delete('fixture0001');
      expect(await store.importJob(fixture('integration-first')), false);
      expect(
        (await store.songs()).where((s) => s.id == 'fixture0001'),
        isEmpty,
      );
      await store.importJob(fixture('integration-second'));
      await store.addCategory('Integration category');
      final original = (await store.songs()).firstWhere(
        (s) => s.id == 'fixture0001',
      );
      await store.save(
        original.copyWith(
          title: 'Offline test tone',
          favorite: true,
          categories: ['Integration category'],
        ),
      );
      await store.db.close();

      final c = AppController();
      await c.init();
      expect(c.startupError, isNull);
      final persisted = c.songs.firstWhere((s) => s.id == 'fixture0001');
      expect(persisted.title, 'Offline test tone');
      expect(persisted.favorite, true);
      expect(persisted.categories, ['Integration category']);
      await tester.pumpWidget(OtoApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      expect(find.text('Your music'), findsOneWidget);
      expect(
        find.widgetWithText(ListTile, 'Offline test tone'),
        findsOneWidget,
      );
      await c.play(persisted, [persisted]);
      await tester.pump(const Duration(milliseconds: 700));
      expect(c.current?.id, persisted.id);
      expect(c.playing, true);
      await tester.pump(const Duration(seconds: 1));
      expect(c.position.value.inMilliseconds, greaterThan(0));
      await c.seek(const Duration(seconds: 3));
      await c.togglePlay();
      expect(c.playing, false);
      await c.setTheme(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Your music'))).brightness,
        Brightness.dark,
      );
      await c.setTheme(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Your music'))).brightness,
        Brightness.light,
      );
      await c.deleteCategory('Integration category');
      expect(
        c.songs.firstWhere((s) => s.id == persisted.id).categories,
        isEmpty,
      );
      await c.delete(persisted);
      expect(await file.exists(), false);
      await c.setTheme(ThemeMode.system);
      c.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
