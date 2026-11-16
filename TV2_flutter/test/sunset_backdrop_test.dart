import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/home_screen.dart';
import 'package:tv2/main.dart';
import 'package:tv2/sunset_backdrop.dart';

import 'home_screen_test.dart' show NamespaceAwareApi;

class MissingArtworkBundle extends CachingAssetBundle {
  int loads = 0;
  @override
  Future<ByteData> load(String key) async {
    loads++;
    throw StateError('No artwork asset available: $key');
  }
}

const captureDirectory = String.fromEnvironment('TV2_CAPTURE_DIR');

Future<void> capture(WidgetTester tester, String name) async {
  if (captureDirectory.isEmpty) return;
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(captureDirectory).create(recursive: true);
    await File('$captureDirectory/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
  await tester.pump();
}

void main() {
  setUpAll(() async {
    // Optional local review captures use SDK fonts instead of test Ahem glyphs.
    // Normal CI tests remain independent of filesystem fonts and screenshots.
    const fonts = String.fromEnvironment('TV2_FONT_DIR');
    if (captureDirectory.isEmpty || fonts.isEmpty) return;
    for (final family in ['Ahem', 'Roboto', 'MaterialIcons']) {
      final file = family == 'MaterialIcons'
          ? 'MaterialIcons-Regular.otf'
          : 'Roboto-Regular.ttf';
      final loader = FontLoader(family);
      loader.addFont(File('$fonts/$file')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)));
      await loader.load();
    }
  });
  for (final artwork in [true, false]) {
    testWidgets(
        'keypad contrast and callbacks with artwork=$artwork, no assets',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bundle = MissingArtworkBundle();
      final keys = <String>[];
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
          home: DefaultAssetBundle(
        bundle: bundle,
        child: RepaintBoundary(
          key: const Key('capture'),
          child: SunsetBackdrop(
            showArtwork: artwork,
            child: Align(
                alignment: Alignment.bottomCenter,
                child: Keypad(
                    onKey: keys.add,
                    onCall: () {},
                    onHome: () {},
                    onBack: () {},
                    onEnter: () {},
                    callEnabled: true,
                    enterEnabled: true)),
          ),
        ),
      )));
      await tester.pumpAndSettle();
      expect(bundle.loads, 0);
      expect(
          find.byWidgetPredicate((widget) =>
              widget is CustomPaint && widget.painter is SunsetPainter),
          artwork ? findsOneWidget : findsNothing);
      expect(
          find.byWidgetPredicate((widget) =>
              widget is ColoredBox &&
              widget.color == SunsetBackdrop.fallbackColor),
          findsOneWidget);
      await tester.tap(find.text('5'));
      expect(keys, ['5']);
      // Color-based contrast remains deterministic for tiny punctuation;
      // screenshot classifiers can mistake an antialiased dot for its border.
      final buttonContext = tester.element(find.byType(FilledButton).first);
      final style = Theme.of(buttonContext).filledButtonTheme.style!;
      final background =
          Color.alphaBlend(style.backgroundColor!.resolve({})!, Colors.white);
      for (final foreground in [
        style.foregroundColor!.resolve({})!,
        tester.widget<Text>(find.text('ABC')).style!.color!,
      ]) {
        final ratio = (foreground.computeLuminance() + .05) /
            (background.computeLuminance() + .05);
        expect(ratio, greaterThanOrEqualTo(4.5));
      }
      if (captureDirectory.isEmpty) {
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull);
      await capture(tester, artwork ? 'keypad-sunset' : 'keypad-fallback');
      semantics.dispose();
    });
  }

  for (final size in [const Size(400, 900), const Size(900, 400)]) {
    testWidgets('original scene fills $size without assets or semantics',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(RepaintBoundary(
          key: const Key('capture'),
          child: const SunsetBackdrop(child: SizedBox.expand())));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(SunsetBackdrop)), size);
      expect(SunsetPainter().shouldRepaint(SunsetPainter()), isFalse);
      expect(tester.takeException(), isNull);
      await capture(
          tester, 'scene-${size.width.toInt()}x${size.height.toInt()}');
    });
  }

  testWidgets('home retains scrolling demo and resolver over the backdrop',
      (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(RepaintBoundary(
        key: const Key('capture'),
        child: TV2App(api: NamespaceAwareApi(), initialCountry: '1')));
    await tester.pumpAndSettle();
    expect(find.byType(SunsetBackdrop), findsOneWidget);
    final navStyle = Theme.of(tester.element(find.byTooltip('ENTER')))
        .iconButtonTheme
        .style!;
    expect(navStyle.backgroundColor!.resolve({WidgetState.disabled})!.a,
        greaterThan(.9));
    expect(find.byKey(const Key('tv2-video-placeholder')), findsOneWidget);
    await capture(tester, 'home-400x900');
    for (final value in ['5', '2', '9']) {
      await tester.ensureVisible(find.text(value));
      await tester.tap(find.text(value));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('ENTER'));
    await tester.tap(find.byTooltip('ENTER'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Save listing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
