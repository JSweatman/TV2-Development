import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:tv2/home_screen.dart';
import 'package:tv2/models.dart';
import 'package:tv2/listing_availability_gate.dart';
import 'home_screen_test.dart' show FakeApi;
import 'listing_media_handoff_test.dart' show media, tapVisible;
import 'tutorial_panel_test.dart' show TestVideoPlatform;

final record = Listing(
    countryCode: '81',
    listNumber: '529',
    tldx: '12',
    displayName: 'Synthetic current',
    entityType: 'test',
    templateKey: 'basic',
    resources: [
      media,
      const ResourceRecord(
          key: 'web', type: 'web', uri: 'https://example.org', metadata: {})
    ],
    buttons: const [
      ButtonRecord(slot: 1, label: 'WEBSITE', resourceKey: 'web')
    ]);
ResolveResponse reply(Listing? value) => ResolveResponse(
    status: value == null ? 'not_found' : 'resolved',
    countryContext: '81',
    input: '81*529.12',
    listing: value);

class ControlledApi extends FakeApi {
  final pending = <Completer<ResolveResponse>>[];
  @override
  Future<ResolveResponse> resolve(
      {required String input, required String country}) {
    expect(input, '81*529.12');
    expect(country, '81');
    final c = Completer<ResolveResponse>();
    pending.add(c);
    return c.future;
  }
}

void main() {
  Future<void> mount(WidgetTester t, ControlledApi api,
      {Listing? initial}) async {
    t.view.physicalSize = const Size(390, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        home: ListingAvailabilityGate(
            api: api,
            listing: initial ?? record,
            builder: (listing, authorize) =>
                TemplateScreen(listing: listing, authorizeAction: authorize))));
  }

  Future<void> tap(WidgetTester t, String label) async {
    await t.ensureVisible(find.text(label));
    await t.tap(find.text(label));
    await t.pump();
  }

  for (final type in ['call', 'text', 'social']) {
    testWidgets('withdrawn $type shares resource action gate', (t) async {
      final api = ControlledApi();
      final listing = Listing(
          countryCode: '81',
          listNumber: '529',
          tldx: '12',
          displayName: 'Synthetic',
          entityType: 'test',
          templateKey: 'basic',
          resources: [
            ResourceRecord(
                key: 'action',
                type: type,
                uri: type == 'social' ? 'https://example.org' : null,
                metadata: const {
                  'handoff': 'device',
                  'phone_e164': '+12025550123'
                })
          ],
          buttons: [
            ButtonRecord(
                slot: 1, label: type.toUpperCase(), resourceKey: 'action')
          ]);
      await mount(t, api, initial: listing);
      await tap(t, type.toUpperCase());
      expect(api.pending.length, 1);
      api.pending.single.complete(reply(null));
      await t.pumpAndSettle();
      expect(find.text('This listing is no longer available.'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });
  }
  testWidgets(
      'withdrawn Website and media are blocked; network failure is retryable',
      (t) async {
    final api = ControlledApi();
    await mount(t, api);
    await tap(t, 'WEBSITE');
    expect(api.pending.length, 1);
    expect(find.text('Checking listing availability…'), findsOneWidget);
    api.pending[0].complete(reply(null));
    await t.pumpAndSettle();
    expect(find.text('This listing is no longer available.'), findsOneWidget);
    expect(find.text('WEBSITE'), findsNothing);
    await tap(t, 'Retry availability');
    api.pending[1].completeError(Exception('offline'));
    await t.pumpAndSettle();
    expect(find.text('Unable to verify this listing. Reconnect and retry.'),
        findsOneWidget);
    await tap(t, 'Retry availability');
    api.pending[2].complete(reply(record));
    await t.pumpAndSettle();
    await tap(t, 'Load listing video');
    api.pending[3].complete(reply(null));
    await t.pumpAndSettle();
    expect(find.text('This listing is no longer available.'), findsOneWidget);
  });
  testWidgets(
      'active Website and media require new gesture; resume cannot revive stale response',
      (t) async {
    final api = ControlledApi();
    final platform = TestVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    var launches = 0;
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'launch') launches++;
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await mount(t, api);
    await tap(t, 'WEBSITE');
    api.pending.last.complete(reply(record));
    await t.pumpAndSettle();
    expect(launches, 0);
    await tapVisible(t, find.text('Continue'));
    expect(launches, 1);
    await tap(t, 'Load listing video');
    api.pending.last.complete(reply(record));
    await t.pumpAndSettle();
    expect(platform.sources, isEmpty);
    await tapVisible(t, find.text('Continue'));
    expect(platform.sources.length, 1);
    await tap(t, 'Play listing video');
    api.pending.last.complete(reply(record));
    await t.pumpAndSettle();
    expect(platform.plays, 0);
    await tapVisible(t, find.text('Continue'));
    expect(platform.plays, 1);
    await tap(t, 'WEBSITE');
    final old = api.pending.last;
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await t.pump();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(api.pending.last, isNot(same(old)));
    api.pending.last.complete(reply(null));
    await t.pumpAndSettle();
    old.complete(reply(record));
    await t.pumpAndSettle();
    expect(find.text('This listing is no longer available.'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(launches, 1);
    expect(platform.plays, 1);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
}
