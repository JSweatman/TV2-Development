import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:tv2/device_handoff.dart';
import 'package:tv2/home_screen.dart';
import 'package:tv2/listing_video_panel.dart';
import 'package:tv2/main.dart';
import 'package:tv2/models.dart';
import 'home_screen_test.dart' show FakeApi;
import 'tutorial_panel_test.dart' show TestVideoPlatform;

const call = ResourceRecord(
    key: 'call',
    type: 'call',
    uri: null,
    metadata: {'handoff': 'device', 'phone_e164': '+12025550123'});
const text = ResourceRecord(
    key: 'text',
    type: 'text',
    uri: null,
    metadata: {'handoff': 'device', 'phone_e164': '+12025550123'});
Listing listing([List<ResourceRecord> resources = const [call, text]]) =>
    Listing(
        countryCode: '1',
        listNumber: '529',
        tldx: null,
        displayName: 'Local fixture',
        entityType: 'test',
        templateKey: 'basic',
        resources: resources,
        buttons: const [
          ButtonRecord(slot: 1, label: 'CALL', resourceKey: 'call'),
          ButtonRecord(slot: 2, label: 'TEXT', resourceKey: 'text')
        ]);
const media = ResourceRecord(
    key: 'video',
    type: 'listing_video',
    uri: 'https://media.example.org/video.mp4',
    metadata: {'publication': 'published', 'content_type': 'video/mp4'});

class ContactApi extends FakeApi {
  @override
  Future<ResolveResponse> resolve(
          {required String input, required String country}) async =>
      ResolveResponse(
          status: 'resolved',
          countryContext: '1',
          input: input,
          listing: listing());
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('only typed E164 destinations', () {
    expect(deviceDestination(call).toString(), 'tel:+12025550123');
    expect(deviceDestination(text).toString(), 'sms:+12025550123');
    for (final value in [
      '529',
      '1*529',
      '+12025550123?body=x',
      '+12025550123;ext=1',
      '+0123456789',
      '+1 2025550123',
      '+12025550123\n',
      123
    ]) {
      expect(
          deviceDestination(ResourceRecord(
              key: 'call',
              type: 'call',
              uri: 'tel:+12025550123',
              metadata: {'handoff': 'device', 'phone_e164': value})),
          isNull);
    }
    expect(
        deviceDestination(const ResourceRecord(
            key: 'call', type: 'call', uri: 'tel:+12025550123', metadata: {})),
        isNull);
    expect(deviceDestination(media), isNull);
  });
  test('listing video requires published typed HTTPS', () {
    expect(listingVideoUri(listing([media])), isNotNull);
    for (final uri in [
      'http://example.org/a',
      'https://127.0.0.1/a',
      'file:///a'
    ]) {
      expect(
          listingVideoUri(listing([
            ResourceRecord(
                key: 'video',
                type: 'listing_video',
                uri: uri,
                metadata: media.metadata)
          ])),
          isNull);
    }
    expect(listingVideoUri(listing()), isNull);
  });
  testWidgets('landing CALL/TEXT confirmation and fallback', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(MaterialApp(
        home: TemplateScreen(
            listing: listing(),
            deviceHandoff: DeviceHandoff(open: (uri) async {
              opened.add(uri);
              return false;
            }))));
    expect(opened, isEmpty);
    await tapVisible(tester, find.text('CALL'));
    expect(opened, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    await tapVisible(tester, find.text('TEXT'));
    await tester.tap(find.text('Open device app'));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'sms:+12025550123');
    expect(find.textContaining('No compatible app opened.'), findsOneWidget);
  });
  testWidgets('keypad CALL exact destination and clear', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final opened = <Uri>[];
    await tester.pumpWidget(TV2App(
        api: ContactApi(),
        initialCountry: '1',
        deviceHandoff: DeviceHandoff(open: (uri) async {
          opened.add(uri);
          return true;
        })));
    await tester.pumpAndSettle();
    for (final digit in ['5', '2', '9']) {
      await tapVisible(tester, find.text(digit));
    }
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byTooltip('CALL'));
    await tester.tap(find.text('Open device app'));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'tel:+12025550123');
    await tapVisible(tester, find.byTooltip('Clear'));
    expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.call))
            .onPressed,
        isNull);
    expect(opened.length, 1);
  });
  testWidgets(
      'no listing media allocates nothing; rejected handoff never launches',
      (tester) async {
    final platform = TestVideoPlatform();
    VideoPlayerPlatform.instance = platform;
    var launches = 0;
    final invalid =
        ResourceRecord(key: 'call', type: 'call', uri: null, metadata: {});
    await tester.pumpWidget(MaterialApp(
        home: TemplateScreen(
            listing: listing([invalid]),
            deviceHandoff: DeviceHandoff(open: (_) async {
              launches++;
              return true;
            }))));
    await tapVisible(tester, find.text('CALL'));
    expect(find.text('No valid device destination is configured.'),
        findsOneWidget);
    expect(launches, 0);
    expect(platform.sources, isEmpty);
  });
  testWidgets('thrown platform handoff reports fallback', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: TemplateScreen(
            listing: listing(),
            deviceHandoff: DeviceHandoff(open: (_) async {
              throw StateError('no handler');
            }))));
    await tapVisible(tester, find.text('CALL'));
    await tester.tap(find.text('Open device app'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No compatible app opened.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'device confirmation fits compact enlarged text and supports keyboard cancel',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var launched = false;
    final handoff = DeviceHandoff(open: (_) async {
      launched = true;
      return true;
    });
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(3)),
            child: child!),
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => handoff.request(context, call),
                    child: const Text('CALL'))))));
    await tapVisible(tester, find.text('CALL'));
    expect(find.text('Open phone app?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Open phone app?'), findsNothing);
    expect(launched, isFalse);
  });
  for (final scale in [1.0, 3.0]) {
    testWidgets('listing video opt-in retry dismiss scale $scale',
        (tester) async {
      final platform = TestVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: SingleChildScrollView(
                      child: ListingVideoPanel(listing: listing([media])))))));
      expect(platform.sources, isEmpty);
      platform.fail = true;
      await tapVisible(tester, find.text('Load listing video'));
      expect(find.text('Retry listing video'), findsOneWidget);
      platform.fail = false;
      await tapVisible(tester, find.text('Retry listing video'));
      expect(platform.plays, 0);
      await tapVisible(tester, find.text('Play listing video'));
      expect(platform.plays, 1);
      await tapVisible(tester, find.text('Dismiss listing video'));
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      expect(platform.disposed.length, 2);
      expect(find.text('Show listing video'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
