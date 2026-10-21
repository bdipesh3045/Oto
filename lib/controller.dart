import 'dart:async';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart'
    show MediaItem;
import 'package:shared_preferences/shared_preferences.dart';
import 'data/download_bridge.dart';
import 'data/models.dart';
import 'data/repository.dart';

class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController({this.audioEnabled = true});
  final bool audioEnabled;
  final repository = LibraryRepository();
  final downloads = DownloadBridge();
  AudioPlayer? player;
  final position = ValueNotifier(Duration.zero);
  final subscriptions = <StreamSubscription<dynamic>>[];
  List<Song> songs = [], queue = [];
  List<DownloadJob> jobs = [];
  List<String> categories = [];
  ThemeMode themeMode = ThemeMode.system;
  int bitrate = 192;
  String engineVersion = 'Bundled';
  String? engineStatus;
  bool loading = true,
      checking = false,
      updating = false,
      _polling = false,
      _enqueuing = false,
      _disposed = false;
  String? message, startupError;
  TrackInfo? preview;
  Song? get current =>
      player?.currentIndex != null && player!.currentIndex! < queue.length
      ? queue[player!.currentIndex!]
      : null;
  bool get playing =>
      (player?.playing ?? false) &&
      player?.processingState != ProcessingState.completed;
  bool get busyPlayer =>
      player?.processingState == ProcessingState.loading ||
      player?.processingState == ProcessingState.buffering;
  int get activeCount => jobs.where((j) => j.active).length;
  bool get enqueuing => _enqueuing;
  Timer? _timer;
  int _idleTicks = 0;
  final _importedJobs = <String>{};
  late SharedPreferences _prefs;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      _prefs = await SharedPreferences.getInstance();
      themeMode = ThemeMode.values.firstWhere(
        (v) => v.name == _prefs.getString('theme'),
        orElse: () => ThemeMode.system,
      );
      bitrate = _prefs.getInt('bitrate') ?? 192;
      await _prefs.remove('serverUrl');
      await _prefs.remove('serverKey');
      await downloads.initialize();
      try {
        final engine = await downloads.engineStatus();
        engineVersion = engine['version'] as String? ?? 'Bundled';
      } catch (_) {
        engineStatus =
            'The download engine could not start. Check free storage and reopen oto. Your saved music is still available.';
      }
      await repository.open();
      await reload();
      if (audioEnabled) {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
        player = AudioPlayer();
        subscriptions.add(
          player!.positionStream.listen((v) => position.value = v),
        );
        subscriptions.add(player!.playerStateStream.listen((_) => _notify()));
        subscriptions.add(player!.currentIndexStream.listen((_) => _notify()));
        subscriptions.add(
          player!.errorStream.listen(
            (_) => report(
              'This file could not be played. Check that it is still on your phone.',
            ),
          ),
        );
      }
      await poll();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (activeCount > 0 || _idleTicks++ % 10 == 0) unawaited(poll());
      });
    } catch (e) {
      debugPrint('oto initialization failed: $e');
      startupError =
          'Your library could not open. Close oto and reopen it to try again.';
    }
    loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void report(String text) {
    message = text;
    _notify();
  }

  void clearMessage() {
    message = null;
  }

  static String errorText(Object e) => switch (e) {
    FormatException(:final message) => message,
    PlatformException(:final message) =>
      message ?? 'Could not complete that action. Try again.',
    FileSystemException() =>
      'Could not access your music files. Check storage and retry.',
    _ => 'Something went wrong. Please try again.',
  };
  Future<void> run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      report(errorText(e));
    }
  }

  Future<void> reload() async {
    songs = await repository.songs();
    categories = await repository.categories();
    queue = queue
        .map((s) => songs.where((t) => t.id == s.id).firstOrNull ?? s)
        .toList();
    _notify();
  }

  Future<void> poll() async {
    if (_polling || _disposed) return;
    _polling = true;
    try {
      final fetched = await downloads.jobs();
      final changed =
          fetched.length != jobs.length ||
          fetched.asMap().entries.any(
            (e) =>
                e.key >= jobs.length ||
                e.value.id != jobs[e.key].id ||
                e.value.state != jobs[e.key].state ||
                e.value.progress != jobs[e.key].progress ||
                e.value.error != jobs[e.key].error,
          );
      bool imported = false;
      for (final job in fetched.where(
        (j) => j.state == 'completed' && !_importedJobs.contains(j.id),
      )) {
        imported = await repository.importJob(job) || imported;
        _importedJobs.add(job.id);
      }
      jobs = fetched;
      if (imported) {
        await reload();
        report('MP3 saved. Find it in your library.');
      }
      if (changed) _notify();
    } catch (e) {
      if (loading) rethrow;
    } finally {
      _polling = false;
    }
  }

  Future<void> inspect(String value) async {
    if (checking || updating) return;
    checking = true;
    preview = null;
    _notify();
    try {
      preview = await downloads.inspect(youtubeUrl(value));
    } catch (e) {
      report(errorText(e));
    } finally {
      checking = false;
      _notify();
    }
  }

  Future<bool> enqueue(TrackInfo info, {int? quality}) async {
    if (_enqueuing || updating) return false;
    if (songs.any((s) => s.id == info.videoId)) {
      report('This song is already in your library.');
      return false;
    }
    if (jobs.any((j) => j.info.videoId == info.videoId && j.active)) {
      report('This song is already in the download queue.');
      return false;
    }
    _enqueuing = true;
    _notify();
    try {
      await downloads.enqueue(info, quality ?? bitrate);
      preview = null;
      await poll();
      return true;
    } catch (e) {
      report(errorText(e));
      return false;
    } finally {
      _enqueuing = false;
      _notify();
    }
  }

  Future<void> retry(DownloadJob job) async {
    if (await enqueue(job.info, quality: job.bitrate)) {
      await downloads.remove(job.id);
      await poll();
    }
  }

  Future<void> cancel(DownloadJob job) => run(() async {
    await downloads.cancel(job.id);
    await poll();
  });
  Future<void> dismiss(DownloadJob job) => run(() async {
    await downloads.remove(job.id);
    await poll();
  });
  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;
    _notify();
    await _prefs.setString('theme', mode.name);
  }

  Future<void> setBitrate(int value) async {
    bitrate = value;
    _notify();
    await _prefs.setInt('bitrate', value);
  }

  Future<void> favorite(Song song) => run(() async {
    await repository.save(song.copyWith(favorite: !song.favorite));
    await reload();
  });
  Future<void> rename(Song song, String title) => run(() async {
    final value = title.trim();
    if (value.isEmpty || value.length > 150) {
      report('Use a title between 1 and 150 characters.');
      return;
    }
    await repository.save(song.copyWith(title: value));
    await reload();
  });
  Future<void> categorize(Song song, List<String> names) => run(() async {
    await repository.save(
      song.copyWith(categories: names.where(categories.contains).toList()),
    );
    await reload();
  });
  Future<void> addCategory(String text) => run(() async {
    final name = text.trim();
    if (name.isEmpty || name.length > 30) {
      report('Use a category name between 1 and 30 characters.');
      return;
    }
    if (categories.any((c) => c.toLowerCase() == name.toLowerCase())) {
      report('That category already exists.');
      return;
    }
    await repository.addCategory(name);
    await reload();
  });
  Future<void> deleteCategory(String name) => run(() async {
    await repository.deleteCategory(name);
    await reload();
  });
  Future<void> delete(Song song) => run(() async {
    if (queue.any((s) => s.id == song.id)) {
      await player?.stop();
      await player?.clearAudioSources();
      queue = [];
    }
    // Keep import receipts so completed history cannot resurrect a deleted song.
    await repository.delete(song.id);
    final file = File(song.path);
    if (await file.exists()) await file.parent.delete(recursive: true);
    await reload();
    report('Song removed from this phone.');
  });
  Future<void> export(Song song) => run(() async {
    if (await downloads.export(song)) report('MP3 exported.');
  });
  Future<void> play(Song song, List<Song> source) => run(() async {
    if (player == null) return;
    final valid = <Song>[];
    for (final track in source) {
      if (await File(track.path).exists()) valid.add(track);
    }
    final index = valid.indexWhere((s) => s.id == song.id);
    if (index < 0) {
      report(
        'This audio file is missing. Remove the entry and download it again.',
      );
      return;
    }
    queue = valid;
    await player!.setAudioSources(
      valid
          .map(
            (s) => AudioSource.uri(
              Uri.file(s.path),
              tag: MediaItem(
                id: s.id,
                title: s.title,
                artist: s.artist,
                duration: Duration(seconds: s.duration),
                artUri: s.artwork.isNotEmpty ? Uri.file(s.artwork) : null,
              ),
            ),
          )
          .toList(),
      initialIndex: index,
    );
    unawaited(
      player!.play().catchError((Object e) {
        report(errorText(e));
      }),
    );
    _notify();
  });
  Future<void> togglePlay() => run(() async {
    if (player == null) return;
    if (playing) {
      await player!.pause();
    } else {
      if (player!.processingState == ProcessingState.completed) {
        await player!.seek(Duration.zero);
      }
      unawaited(
        player!.play().catchError((Object e) {
          report(errorText(e));
        }),
      );
    }
  });
  Future<void> next() => run(() async {
    if (player?.hasNext ?? false) await player!.seekToNext();
  });
  Future<void> previous() => run(() async {
    if (position.value.inSeconds > 3) {
      await player?.seek(Duration.zero);
    } else if (player?.hasPrevious ?? false) {
      await player!.seekToPrevious();
    }
  });
  Future<void> seek(Duration value) => run(() async {
    await player?.seek(value);
  });
  Future<void> shuffle() => run(() async {
    if (player == null) return;
    await player!.setShuffleModeEnabled(!player!.shuffleModeEnabled);
    _notify();
  });
  Future<void> repeat() => run(() async {
    if (player == null) return;
    await player!.setLoopMode(switch (player!.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    });
    _notify();
  });
  Future<void> updateEngine() async {
    if (updating || activeCount > 0 || checking) return;
    updating = true;
    engineStatus = null;
    _notify();
    try {
      final result = await downloads.updateEngine();
      engineVersion = result['version'] as String? ?? engineVersion;
      engineStatus = result['updated'] == true
          ? 'Download engine updated. You can retry your song.'
          : 'Your download engine is up to date.';
      report(engineStatus!);
    } catch (e) {
      engineStatus = errorText(e);
      report(engineStatus!);
    } finally {
      updating = false;
      _notify();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(poll());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (final sub in subscriptions) {
      unawaited(sub.cancel());
    }
    unawaited(player?.dispose());
    unawaited(downloads.dispose());
    position.dispose();
    super.dispose();
  }
}
