import 'dart:async';
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

// Simulates platform events/commands, not hardware codec decoding.
class TestVideoPlatform extends VideoPlayerPlatform {
  final streams = <int, StreamController<VideoEvent>>{};
  final sources = <DataSource>[];
  final disposed = <int>[];
  int plays = 0;
  int pauses = 0;
  bool fail = false;
  bool stall = false;
  bool failPlay = false;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = sources.length;
    sources.add(options.dataSource);
    final stream = streams[id] = StreamController<VideoEvent>();
    if (fail) {
      stream.addError(
        PlatformException(code: 'test-error', message: 'Controlled test error'),
      );
    } else if (!stall) {
      stream.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 1),
          size: const Size(160, 90),
        ),
      );
    }
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    await streams[playerId]!.close();
  }

  @override
  Future<void> play(int playerId) async {
    if (failPlay) throw PlatformException(code: 'test-play-error');
    plays++;
  }

  @override
  Future<void> pause(int playerId) async {
    pauses++;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.blue);
}

void main() {
  late TestVideoPlatform platform;
  final video = TutorialVideo(
    uri: Uri.parse('https://example.invalid/tutorial-v1.mp4'),
  );
  setUp(() {
    platform = TestVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  Future<void> mount(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: SingleChildScrollView(
              child: TutorialPanel(
                tutorial: video,
                controllerFactory: (_) => VideoPlayerController.asset(
                  'test/fixtures/tutorial_test_pattern.mp4',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('configuration defaults off and accepts only explicit HTTPS', () {
    for (final url in [
      '',
      'bad',
      'http://example.com/a.mp4',
      'https://user:password@example.com/a.mp4',
    ]) {
      expect(TutorialVideo.fromUrl(url), isNull);
    }
    expect(
      TutorialVideo.fromUrl('https://example.com/tutorial/v1.mp4')!.uri.scheme,
      'https',
    );
    expect(
      File('test/fixtures/tutorial_test_pattern.mp4').lengthSync(),
      greaterThan(0),
    );
  });

  testWidgets(
    'no configured tutorial keeps noninteractive placeholder and allocates no player',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TutorialPanel(tutorial: null))),
      );
      expect(find.text('COMING SOON'), findsOneWidget);
      expect(find.text('Load tutorial'), findsNothing);
      expect(platform.sources, isEmpty);
    },
  );

  for (final scale in [1.0, 3.0]) {
    testWidgets(
      'explicit load, play, pause, replay, dismiss and reopen at scale $scale',
      (tester) async {
        await mount(tester, scale: scale);
        expect(platform.sources, isEmpty);
        await tapVisible(tester, find.text('Load tutorial'));
        await tester.pumpAndSettle();
        expect(
          platform.sources.single.asset,
          'test/fixtures/tutorial_test_pattern.mp4',
        );
        expect(platform.plays, 0);
        await tapVisible(tester, find.text('Play tutorial'));
        await tester.pumpAndSettle();
        expect(platform.plays, 1);
        await tapVisible(tester, find.text('Pause tutorial'));
        await tester.pumpAndSettle();
        platform.streams[0]!.add(
          VideoEvent(eventType: VideoEventType.completed),
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Replay tutorial'));
        await tester.pumpAndSettle();
        expect(platform.plays, 2);
        await tapVisible(tester, find.text('Dismiss tutorial'));
        await tester.pumpAndSettle();
        expect(find.text('Show tutorial'), findsOneWidget);
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump();
        expect(platform.disposed, contains(0));
        expect(find.byType(VideoPlayer), findsNothing);
        await tapVisible(tester, find.text('Show tutorial'));
        await tester.pumpAndSettle();
        expect(find.text('Load tutorial'), findsOneWidget);
        expect(platform.sources.length, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('keyboard activation loads, plays, pauses and dismisses', (
    tester,
  ) async {
    await mount(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(platform.sources.length, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(platform.plays, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Play tutorial'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Show tutorial'), findsOneWidget);
  });

  testWidgets('load failure retries, play rejection is contained', (
    tester,
  ) async {
    platform.fail = true;
    await mount(tester);
    await tester.tap(find.text('Load tutorial'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tutorial unavailable'), findsOneWidget);
    platform.fail = false;
    await tester.tap(find.text('Retry tutorial'));
    await tester.pumpAndSettle();
    platform.failPlay = true;
    await tester.tap(find.text('Play tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Retry tutorial'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading can be dismissed and timeout cannot revive it', (
    tester,
  ) async {
    platform.stall = true;
    await mount(tester);
    await tester.tap(find.text('Load tutorial'));
    await tester.pump();
    expect(find.text('Loading tutorial…'), findsOneWidget);
    await tester.tap(find.text('Dismiss tutorial'));
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(find.text('Show tutorial'), findsOneWidget);
    expect(platform.plays, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('background pauses without automatic resume', (tester) async {
    await mount(tester);
    await tester.tap(find.text('Load tutorial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play tutorial'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(platform.plays, 1);
    expect(find.text('Play tutorial'), findsOneWidget);
    await tester.tap(find.text('Dismiss tutorial'));
    await tester.pumpAndSettle();
  });

  testWidgets('loading timeout reports recoverable error', (tester) async {
    platform.stall = true;
    await mount(tester);
    await tester.tap(find.text('Load tutorial'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(find.text('Retry tutorial'), findsOneWidget);
    expect(platform.plays, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tutorial playback leaves lookup intact and pauses when HOME covers keypad',
    (tester) async {
      SharedPreferences.setMockInitialValues({'tv2_selected_nid': '1'});
      await tester.pumpWidget(
        TV2App(api: NamespaceAwareApi(), tutorial: video),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Load tutorial'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Play tutorial'));
      await tester.pumpAndSettle();
      for (final digit in ['5', '2', '9']) {
        await tapVisible(tester, find.text(digit));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Fixture Alpha'), findsWidgets);
      await tapVisible(tester, find.byTooltip('HOME'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Play tutorial'), findsOneWidget);
      expect(find.text('529'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      await tapVisible(tester, find.text('Dismiss tutorial'));
      await tester.pumpAndSettle();
    },
  );
}
