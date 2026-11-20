import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/landing_theme.dart';
import 'package:tv2/home_screen.dart';
import 'package:tv2/models.dart';
import 'package:tv2/device_handoff.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'tutorial_panel_test.dart' show TestVideoPlatform;

Listing fixture(
        {String palette = 'graphite',
        Map<String, dynamic>? config,
        List<ButtonRecord>? buttons,
        List<ResourceRecord> extra = const []}) =>
    Listing(
        countryCode: '1',
        listNumber: '70001',
        tldx: null,
        displayName: 'Synthetic studio',
        entityType: 'test',
        templateKey: 'basic',
        resources: [
          ResourceRecord(
              key: 'theme',
              type: 'landing_theme',
              uri: null,
              metadata: config ??
                  {
                    'version': 1,
                    'palette': palette,
                    'hero': palette == 'graphite' ? 'horizon' : 'petals'
                  }),
          const ResourceRecord(
              key: 'call',
              type: 'call',
              uri: null,
              metadata: {'handoff': 'device', 'phone_e164': '+12025550123'}),
          ...extra
        ],
        buttons: buttons ??
            const [
              ButtonRecord(slot: 1, label: 'CALL', resourceKey: 'call'),
              ButtonRecord(slot: 2, label: 'TEXT', resourceKey: 'missing')
            ]);
void main() {
  test('strict theme contract and contrast', () {
    for (final palette in ['graphite', 'lotus']) {
      final s = LandingThemeSpec.fromListing(fixture(palette: palette))!;
      double ratio(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
      }

      expect(ratio(s.foreground, s.background), greaterThanOrEqualTo(4.5));
      expect(ratio(s.foreground, s.surface), greaterThanOrEqualTo(4.5));
      expect(ratio(s.accent, s.background), greaterThanOrEqualTo(4.5));
    }
    for (final config in <Map<String, dynamic>>[
      {},
      {'version': 2, 'palette': 'graphite'},
      {'version': 1, 'palette': 'red'},
      {'version': 1, 'palette': 'lotus', 'hero': 'https://example.org/x'},
      {'version': 1, 'palette': 'lotus', 'color': '#fff'}
    ]) {
      expect(LandingThemeSpec.fromListing(fixture(config: config)), isNull);
    }
    expect(
        LandingThemeSpec.fromListing(fixture(buttons: const [
          ButtonRecord(slot: 1, label: 'A', resourceKey: 'a'),
          ButtonRecord(slot: 1, label: 'B', resourceKey: 'b')
        ])),
        isNull);
  });
  test('provider reference is identifiers only; never a URL grant', () {
    ResourceRecord ref(Map<String, dynamic> data, {String? uri}) =>
        ResourceRecord(
            key: 'p', type: 'provider_embed', uri: uri, metadata: data);
    expect(
        ProviderVideoReference.parse(
            ref({'provider': 'example_provider', 'video_id': 'synthetic_1'})),
        isNotNull);
    for (final data in [
      {'provider': 'https://example.org', 'video_id': 'x'},
      {'provider': 'sample', 'video_id': '../x'},
      {'provider': 'sample', 'video_id': 'x', 'html': '<iframe>'}
    ]) {
      expect(ProviderVideoReference.parse(ref(data)), isNull);
    }
    expect(
        ProviderVideoReference.parse(ref(
            {'provider': 'sample', 'video_id': 'x'},
            uri: 'https://example.org')),
        isNull);
  });
  for (final palette in ['graphite', 'lotus']) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
          '$palette hides unconfigured actions 320 wide scale $scale',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final platform = TestVideoPlatform();
        VideoPlayerPlatform.instance = platform;
        final opened = <Uri>[];
        await tester.pumpWidget(MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: TemplateScreen(
                listing: fixture(palette: palette),
                deviceHandoff: DeviceHandoff(open: (u) async {
                  opened.add(u);
                  return true;
                }))));
        await tester.pumpAndSettle();
        for (final slot in [1]) {
          final f = find.byKey(ValueKey('landing-action-$slot'));
          await tester.scrollUntilVisible(f, 150,
              scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          expect(tester.getSize(f).height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        }
        for (var slot = 2; slot <= 6; slot++) {
          expect(find.byKey(ValueKey('landing-action-$slot')), findsNothing);
        }
        final call = find.byKey(const ValueKey('landing-action-1'));
        await tester.ensureVisible(call);
        await tester.pumpAndSettle();
        await tester.tap(call);
        await tester.pumpAndSettle();
        expect(opened, isEmpty);
        await tester.ensureVisible(find.text('Open device app'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open device app'));
        await tester.pumpAndSettle();
        expect(opened.single.toString(), 'tel:+12025550123');
        expect(platform.sources, isEmpty);
        expect(find.byKey(const Key('tv2-video-placeholder')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets(
      'rejected theme uses ordinary listing and provider fallback never allocates media',
      (tester) async {
    final platform = TestVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    await tester.pumpWidget(MaterialApp(
        home: TemplateScreen(
            listing: fixture(config: {
      'version': 99
    }, extra: const [
      ResourceRecord(
          key: 'embed',
          type: 'provider_embed',
          uri: null,
          metadata: {'provider': 'sample', 'video_id': 'synthetic'})
    ]))));
    expect(find.text('test • template: basic'), findsOneWidget);
    expect(find.byKey(const ValueKey('landing-action-1')), findsNothing);
    expect(find.text('Provider video is not supported in this build.'),
        findsOneWidget);
    expect(platform.sources, isEmpty);
  });
}
