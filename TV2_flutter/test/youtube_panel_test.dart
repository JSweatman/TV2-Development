import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/youtube_reference.dart';
import 'package:tv2/youtube_panel.dart';
import 'package:tv2/models.dart';
import 'package:tv2/home_screen.dart';
import 'landing_theme_test.dart' show fixture;

ResourceRecord ref(
        {String id = 'M7lc1UVf-VE',
        String provider = 'youtube',
        String? uri,
        Map<String, dynamic> extra = const {}}) =>
    ResourceRecord(
        key: 'provider',
        type: 'provider_embed',
        uri: uri,
        metadata: {'provider': provider, 'video_id': id, ...extra});
void main() {
  test('only one YouTube ID builds fixed privacy-enhanced URLs', () {
    final y = YoutubeReference.parse(ref())!;
    expect(y.embed.toString(),
        'https://www.youtube-nocookie.com/embed/M7lc1UVf-VE?autoplay=0&playsinline=1');
    expect(y.watch.toString(), 'https://www.youtube.com/watch?v=M7lc1UVf-VE');
    for (final id in [
      '',
      '../abcdefgh',
      'M7lc1UVf-VE?autoplay=1',
      'M7lc1UVf-VE\n',
      'https://youtube.com',
      '<iframe>',
      'abcdefghij%'
    ]) {
      expect(YoutubeReference.parse(ref(id: id)), isNull);
    }
    expect(YoutubeReference.parse(ref(provider: 'other')), isNull);
    expect(YoutubeReference.parse(ref(uri: 'https://youtube.com')), isNull);
    for (final extra in [
      {'html': '<iframe>'},
      {'url': 'https://example.org'},
      {'autoplay': 1},
      {'redirect': 'x'}
    ]) {
      expect(YoutubeReference.parse(ref(extra: extra)), isNull);
    }
  });
  testWidgets('opt-in, dismiss, reload and canonical fallback are independent',
      (t) async {
    t.view.physicalSize = const Size(800, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    var frames = 0;
    final opened = <Uri>[];
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: YoutubePanel(
                reference: YoutubeReference.parse(ref())!,
                inlineSupported: true,
                frameBuilder: (_) {
                  frames++;
                  return const Text('mock frame');
                },
                open: (u) async {
                  opened.add(u);
                  return true;
                }))));
    expect(frames, 0);
    expect(opened, isEmpty);
    await t.tap(find.text('Load YouTube video'));
    await t.pumpAndSettle();
    expect(find.text('mock frame'), findsOneWidget);
    await t.tap(find.text('Dismiss YouTube video'));
    await t.pumpAndSettle();
    expect(find.text('mock frame'), findsNothing);
    await t.tap(find.text('Open on YouTube'));
    await t.pumpAndSettle();
    expect(opened.single.toString(),
        'https://www.youtube.com/watch?v=M7lc1UVf-VE');
    await t.tap(find.text('Load YouTube video'));
    await t.pumpAndSettle();
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pumpAndSettle();
    expect(find.text('mock frame'), findsNothing);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  testWidgets('native explicit fallback never creates inline player',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: YoutubePanel(
                reference: YoutubeReference.parse(ref())!,
                inlineSupported: false,
                frameBuilder: (_) => throw StateError('must not create'),
                open: (_) async => false))));
    expect(find.text('Load YouTube video'), findsNothing);
    await t.tap(find.text('Open on YouTube'));
    await t.pumpAndSettle();
    expect(find.textContaining('Unable to open YouTube'), findsOneWidget);
  });
  testWidgets('compact enlarged text and minimum 200px frame', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(2)),
            child: w!),
        home: Scaffold(
            body: ListView(children: [
          YoutubePanel(
              reference: YoutubeReference.parse(ref())!,
              inlineSupported: true,
              frameBuilder: (_) => const SizedBox(key: ValueKey('frame')))
        ]))));
    await t.scrollUntilVisible(find.text('Load YouTube video'), 120);
    await t.pumpAndSettle();
    await t.tap(find.text('Load YouTube video'));
    await t.pumpAndSettle();
    expect(t.getSize(find.byKey(const ValueKey('frame'))).height,
        greaterThanOrEqualTo(200));
    expect(t.takeException(), isNull);
  });
  testWidgets('under 200 width falls back and MP4 retains precedence',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 190,
                child: YoutubePanel(
                    reference: YoutubeReference.parse(ref())!,
                    inlineSupported: true,
                    frameBuilder: (_) => throw StateError('too small'))))));
    expect(find.text('Load YouTube video'), findsNothing);
    await t.pumpWidget(MaterialApp(
        home: TemplateScreen(
            listing: fixture(extra: [
      ref(),
      const ResourceRecord(
          key: 'video',
          type: 'listing_video',
          uri: 'https://media.example.org/clip.mp4',
          metadata: {'publication': 'published', 'content_type': 'video/mp4'})
    ]))));
    expect(find.byType(YoutubePanel), findsNothing);
    expect(find.text('Load listing video'), findsOneWidget);
  });
}
