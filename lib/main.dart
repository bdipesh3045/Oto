import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'controller.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.oto.oto.playback',
      androidNotificationChannelName: 'Music playback',
      androidNotificationOngoing: true,
      androidNotificationIcon: 'drawable/ic_music_note',
    );
  } catch (_) {
    controller.startupError = 'Audio could not start. Close oto and reopen it.';
    controller.loading = false;
  }
  runApp(OtoApp(controller: controller));
  if (controller.startupError == null) unawaited(controller.init());
}

class OtoApp extends StatelessWidget {
  const OtoApp({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      title: 'oto',
      debugShowCheckedModeBanner: false,
      theme: otoTheme(Brightness.light),
      darkTheme: otoTheme(Brightness.dark),
      themeMode: controller.themeMode,
      home: AppShell(controller: controller),
    ),
  );
}
