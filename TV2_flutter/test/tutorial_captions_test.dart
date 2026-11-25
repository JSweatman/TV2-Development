import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:tv2/main.dart';
import 'package:tv2/tutorial_panel.dart';
import 'home_screen_test.dart' show NamespaceAwareApi, tapVisible;
import 'tutorial_panel_test.dart' show TestVideoPlatform;

void main() {
  final fixture =
      File('test/fixtures/tutorial_captions.vtt').readAsStringSync();
  late TestVideoPlatform platform;
  late VideoPlayerController controller;
  setUp(() {
    platform = TestVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  Future<void> mount(WidgetTester tester, String captions,
      {double scale = 1}) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SingleChildScrollView(
                    child: TutorialPanel(
                  tutorial: TutorialVideo(
                      uri: Uri.parse('https://example.invalid/test'),
                      captionsVtt: captions),
                  controllerFactory: (_) => controller =
                      VideoPlayerController.asset(
                          'test/fixtures/tutorial_test_pattern.mp4',
                          videoPlayerOptions: VideoPlayerOptions(
                              allowBackgroundPlayback: true)),
                ))))));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, String text) async {
    await tapVisible(t, find.text(text));
    await t.pumpAndSettle();
  }

  test('captions alone never enable a tutorial', () {
    expect(TutorialVideo.fromUrl('', captionsVtt: fixture), isNull);
  });
  testWidgets('missing captions allocate nothing', (t) async {
    await mount(t, '');
    expect(find.text('Show transcript'), findsNothing);
    expect(platform.sources, isEmpty);
    expect(find.text('Captions and transcript are not configured.'),
        findsOneWidget);
  });
  for (final scale in [1.0, 3.0]) {
    testWidgets('cue boundaries, transcript and dismissal at $scale',
        (t) async {
      await mount(t, fixture, scale: scale);
      await tap(t, 'Show captions');
      await tap(t, 'Show transcript');
      expect(
          t
              .widget<Text>(find.byKey(const Key('tutorial-transcript-text')))
              .data,
          'First synthetic cue.\n\nSecond synthetic cue.');
      expect(platform.sources, isEmpty);
      await tap(t, 'Close transcript');
      await tap(t, 'Load tutorial');
      expect(find.text('First synthetic cue.'), findsOneWidget);
      await controller.seekTo(const Duration(milliseconds: 400));
      await t.pump();
      expect(find.text('Second synthetic cue.'), findsOneWidget);
      expect(find.text('First synthetic cue.'), findsNothing);
      await controller.seekTo(const Duration(milliseconds: 800));
      await t.pump();
      expect(find.byKey(const Key('tutorial-active-caption')), findsNothing);
      await controller.seekTo(Duration.zero);
      await t.pump();
      await tap(t, 'Hide captions');
      expect(find.byKey(const Key('tutorial-active-caption')), findsNothing);
      await tap(t, 'Dismiss tutorial');
      await tap(t, 'Show tutorial');
      expect(find.text('Show captions'), findsOneWidget);
      expect(find.byKey(const Key('tutorial-active-caption')), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('keyboard transcript without media request', (t) async {
    await mount(t, fixture);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.text('Hide captions'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(find.text('Tutorial transcript'), findsOneWidget);
    expect(platform.sources, isEmpty);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.text('Tutorial transcript'), findsNothing);
  });
  for (final bad in [
    'not VTT',
    'WEBVTT\n\ninvalid --> cue\nwords',
    'WEBVTT\n\n00:01.000 --> 00:00.500\nReversed.',
    'WEBVTT\n\n00:00.000 --> 00:01.000\nFirst\n\n00:00.500 --> 00:02.000\nOverlap'
  ]) {
    testWidgets('invalid captions are isolated: $bad', (t) async {
      await mount(t, bad);
      await tap(t, 'Show captions');
      expect(find.textContaining('Captions and transcript unavailable'),
          findsOneWidget);
      await tap(t, 'Load tutorial');
      expect(find.text('Play tutorial'), findsOneWidget);
      expect(t.takeException(), isNull);
      await tap(t, 'Dismiss tutorial');
    });
  }
  testWidgets('failed video keeps transcript and retry keeps captions',
      (t) async {
    platform.fail = true;
    await mount(t, fixture);
    await tap(t, 'Show captions');
    await tap(t, 'Load tutorial');
    await tap(t, 'Show transcript');
    expect(find.byKey(const Key('tutorial-transcript-text')), findsOneWidget);
    await tap(t, 'Close transcript');
    platform.fail = false;
    await tap(t, 'Retry tutorial');
    expect(find.text('First synthetic cue.'), findsOneWidget);
    await tap(t, 'Dismiss tutorial');
  });
  testWidgets('failed captions and video leave keypad resolution usable',
      (t) async {
    SharedPreferences.setMockInitialValues({'tv2_selected_nid': '1'});
    platform.fail = true;
    await t.pumpWidget(TV2App(
        api: NamespaceAwareApi(),
        tutorial: TutorialVideo(
            uri: Uri.parse('https://example.invalid/test'),
            captionsVtt: 'broken')));
    await t.pumpAndSettle();
    await tap(t, 'Show captions');
    await tap(t, 'Load tutorial');
    for (final d in ['5', '2', '9']) {
      await tap(t, d);
    }
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    expect(find.text('Fixture Alpha'), findsWidgets);
    expect(find.text('529'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
