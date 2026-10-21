import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oto/controller.dart';
import 'package:oto/main.dart';
import 'models_test.dart' show song;

void main() {
  AppController controller() =>
      AppController(audioEnabled: false)..loading = false;
  testWidgets('home and empty library offer a working route to add music', (
    tester,
  ) async {
    final c = controller();
    await tester.pumpWidget(OtoApp(controller: c));
    expect(find.text('Good songs.\nYours to keep.'), findsOneWidget);
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('A collection of your own'), findsOneWidget);
    await tester.ensureVisible(find.text('Add your first song'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add your first song'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('youtube-link')), findsOneWidget);
  });
  testWidgets('library search and category chips filter actual song rows', (
    tester,
  ) async {
    final c = controller()
      ..songs = [
        song('one', title: 'Morning', categories: ['Chill']),
        song('two', title: 'Running'),
      ]
      ..categories = ['Chill'];
    await tester.pumpWidget(OtoApp(controller: c));
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(ListTile, 'Running').hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.text('Chill'));
    await tester.pumpAndSettle();
    expect(find.text('Morning').hitTestable(), findsOneWidget);
    expect(
      find.widgetWithText(ListTile, 'Running').hitTestable(),
      findsNothing,
    );
    await tester.tap(find.text('All songs'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search songs or artists'),
      'Running',
    );
    await tester.pumpAndSettle();
    expect(find.text('Morning').hitTestable(), findsNothing);
    expect(
      find.widgetWithText(ListTile, 'Running').hitTestable(),
      findsOneWidget,
    );
  });
  testWidgets(
    'light and dark layouts tolerate a compact phone with larger text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        final c = controller()..themeMode = mode;
        await tester.pumpWidget(OtoApp(key: ValueKey(mode), controller: c));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Settings and appearance'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }
    },
  );
}
