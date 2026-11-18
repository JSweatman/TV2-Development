import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:tv2/home_screen.dart';

import 'listing_media_handoff_test.dart' show listing, media, tapVisible;
import 'tutorial_panel_test.dart' show TestVideoPlatform;

class PositionPlatform extends TestVideoPlatform {
  Duration position = Duration.zero;
  @override
  Future<void> seekTo(int playerId, Duration value) async {
    position = value;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;
}

void main() {
  late TestVideoPlatform platform;
  setUp(() {
    platform = PositionPlatform();
    VideoPlayerPlatform.instance = platform;
  });
  Future<void> mount(WidgetTester t,
      {RouteObserver<ModalRoute<dynamic>>? observer}) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
          navigatorObservers: [if (observer != null) observer],
          home: TemplateScreen(
              listing: listing([media]), routeObserver: observer)),
    );
    await t.pumpAndSettle();
  }

  Future<void> rotate(WidgetTester t, bool landscape) async {
    t.view.physicalSize =
        landscape ? const Size(844, 390) : const Size(390, 844);
    await t.pumpAndSettle();
  }

  final expanded = find.byKey(const Key('listing-video-expanded'));
  testWidgets('rotation keeps controller, position, aspect and explicit exit', (
    t,
  ) async {
    await mount(t);
    await tapVisible(t, find.text('Load listing video'));
    await tapVisible(t, find.text('Play listing video'));
    final controller =
        t.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    await controller.seekTo(const Duration(milliseconds: 400));
    final position = controller.value.position;
    await rotate(t, true);
    expect(expanded, findsOneWidget);
    expect(t.getSize(expanded), const Size(844, 390));
    expect(
      t.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
      same(controller),
    );
    expect(controller.value.position, position);
    expect(platform.sources.length, 1);
    expect(platform.disposed, isEmpty);
    final size = t.getSize(find.byType(VideoPlayer));
    expect(size.width / size.height, closeTo(16 / 9, .01));
    await tapVisible(t, find.text('Exit expanded video'));
    expect(expanded, findsNothing);
    expect(controller.value.isPlaying, isTrue);
    await t.pumpAndSettle();
    expect(expanded, findsNothing);
    await rotate(t, false);
    await rotate(t, true);
    expect(expanded, findsOneWidget);
    await rotate(t, false);
    expect(expanded, findsNothing);
    expect(
      t.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
      same(controller),
    );
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    await t.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    expect(platform.disposed, [0]);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'never started and paused inline video do not expand or autoplay',
    (t) async {
      await mount(t);
      await rotate(t, true);
      expect(expanded, findsNothing);
      expect(platform.sources, isEmpty);
      await tapVisible(t, find.text('Load listing video'));
      await rotate(t, false);
      await rotate(t, true);
      expect(expanded, findsNothing);
      expect(platform.plays, 0);
      await rotate(t, false);
      await tapVisible(t, find.text('Play listing video'));
      await tapVisible(t, find.text('Pause listing video'));
      await rotate(t, true);
      expect(expanded, findsNothing);
      expect(platform.plays, 1);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('expanded pause, system back, error and navigation cleanup', (
    t,
  ) async {
    await mount(t);
    await tapVisible(t, find.text('Load listing video'));
    await tapVisible(t, find.text('Play listing video'));
    await rotate(t, true);
    await tapVisible(t, find.text('Pause listing video'));
    expect(expanded, findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(expanded, findsNothing);
    expect(find.text('Local fixture'), findsOneWidget);
    await rotate(t, false);
    await tapVisible(t, find.text('Play listing video'));
    await rotate(t, true);
    final controller =
        t.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    controller.value =
        controller.value.copyWith(errorDescription: 'fixture-failure');
    await t.pumpAndSettle();
    expect(expanded, findsNothing);
    expect(find.textContaining('Listing video unavailable'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('short landscape with enlarged text keeps exit reachable',
      (t) async {
    await mount(t);
    await tapVisible(t, find.text('Load listing video'));
    await tapVisible(t, find.text('Play listing video'));
    t.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    t.view.physicalSize = const Size(568, 320);
    await t.pumpAndSettle();
    expect(expanded, findsOneWidget);
    expect(t.takeException(), isNull);
    await tapVisible(t, find.text('Exit expanded video'));
    expect(expanded, findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
      'covering expanded listing pauses and returns inline without resume',
      (t) async {
    final observer = RouteObserver<ModalRoute<dynamic>>();
    await mount(t, observer: observer);
    await tapVisible(t, find.text('Load listing video'));
    await tapVisible(t, find.text('Play listing video'));
    await rotate(t, true);
    final controller =
        t.widget<VideoPlayer>(find.byType(VideoPlayer)).controller;
    final navigator = t.state<NavigatorState>(find.byType(Navigator));
    navigator.push<int>(MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('Covered'))));
    await t.pumpAndSettle();
    expect(controller.value.isPlaying, isFalse);
    navigator.pop(7);
    await t.pumpAndSettle();
    expect(expanded, findsNothing);
    expect(controller.value.isPlaying, isFalse);
    expect(platform.sources.length, 1);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
