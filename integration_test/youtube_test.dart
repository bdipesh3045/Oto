import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oto/data/download_bridge.dart';
import 'package:just_audio/just_audio.dart';
import 'package:oto/data/repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'YouTube test video becomes a local MP3 entirely on the phone',
    (tester) async {
      final bridge = DownloadBridge();
      await bridge.initialize();
      expect((await bridge.engineStatus())['ready'], true);
      const url = String.fromEnvironment(
        'OTO_TEST_URL',
        defaultValue: 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
      );
      final info = await bridge
          .inspect(url)
          .timeout(const Duration(seconds: 120));
      expect(info.duration, greaterThan(0));
      await bridge.enqueue(info, 128);
      final end = DateTime.now().add(const Duration(minutes: 3));
      while (DateTime.now().isBefore(end)) {
        final jobs = await bridge.jobs();
        final job = jobs.firstWhere((j) => j.info.videoId == info.videoId);
        if (job.state == 'completed') {
          final file = File(job.data['path'] as String);
          expect(file.path.endsWith('.mp3'), true);
          expect(await file.length(), greaterThan(1000));
          final header = await file.open();
          try {
            expect(await header.read(3), [73, 68, 51]);
          } finally {
            await header.close();
          }
          final player = AudioPlayer();
          try {
            final duration = await player.setFilePath(file.path);
            expect(duration!.inSeconds, greaterThan(0));
          } finally {
            await player.dispose();
          }
          final library = LibraryRepository();
          await library.open();
          try {
            await library.importJob(job);
          } finally {
            await library.db.close();
          }
          await bridge.dispose();
          return;
        }
        if (job.retryable) fail(job.error ?? job.label);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      fail('The on-device download did not finish within three minutes.');
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
