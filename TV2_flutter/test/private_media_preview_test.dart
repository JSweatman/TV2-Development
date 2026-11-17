import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/private_media_widgets.dart';

class FakeApi implements PreviewMediaApi {
  bool owner = true, deny = false;
  int uploads = 0, publishes = 0, cancels = 0;
  Completer<String>? pending;
  @override
  Future<bool> signIn(String e, String p) async {
    if (deny) throw StateError('denied');
    return owner;
  }

  @override
  Future<String> upload(Uint8List b) async {
    uploads++;
    if (deny) throw StateError('denied');
    return pending?.future ?? Future.value('draft');
  }

  @override
  Future<void> publish(String id) async {
    if (deny) throw StateError('denied');
    publishes++;
  }

  @override
  void cancel() {
    cancels++;
  }

  @override
  Future<void> signOut() async {}
}

Future<void> enter(WidgetTester t) async {
  final scroll = find.byType(Scrollable).first;
  await t.scrollUntilVisible(find.byKey(const ValueKey('preview-email')), 100,
      scrollable: scroll);
  await t.enterText(
      find.byKey(const ValueKey('preview-email')), 'owner@example.invalid');
  await t.scrollUntilVisible(
      find.byKey(const ValueKey('preview-password')), 100,
      scrollable: scroll);
  await t.enterText(
      find.byKey(const ValueKey('preview-password')), 'synthetic');
  await t.scrollUntilVisible(find.text('Sign in to local preview'), 100,
      scrollable: scroll);
  await t.tap(find.text('Sign in to local preview'));
  await t.pumpAndSettle();
}

Future<void> launch(WidgetTester t, FakeApi api,
    {PreviewClip? clip, double scale = 1}) async {
  await t.pumpWidget(MaterialApp(
      builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: w!),
      home: PrivateMediaPreview(
          api: api,
          pick: () async => clip,
          player: () => const Text('Private fixture player'))));
}

void main() {
  testWidgets(
      'owner upload then explicit publish, failure retry and clear password',
      (t) async {
    final api = FakeApi();
    await launch(t, api, clip: PreviewClip('synthetic.mp4', Uint8List(12)));
    await enter(t);
    await t.tap(find.text('Choose synthetic MP4'));
    await t.pumpAndSettle();
    api.deny = true;
    await t.tap(find.text('Upload private draft'));
    await t.pumpAndSettle();
    expect(find.textContaining('Action failed'), findsOneWidget);
    expect(api.publishes, 0);
    api.deny = false;
    await t.tap(find.text('Upload private draft'));
    await t.pumpAndSettle();
    expect(api.publishes, 0);
    await t.tap(find.text('Publish listing video'));
    await t.pumpAndSettle();
    expect(api.publishes, 1);
  });
  testWidgets('cancel ignores late upload and cannot publish', (t) async {
    final api = FakeApi()..pending = Completer<String>();
    await launch(t, api, clip: PreviewClip('synthetic.mp4', Uint8List(12)));
    await enter(t);
    await t.tap(find.text('Choose synthetic MP4'));
    await t.pumpAndSettle();
    await t.tap(find.text('Upload private draft'));
    await t.pump();
    await t.tap(find.text('Cancel action'));
    await t.pump();
    api.pending!.complete('late');
    await t.pumpAndSettle();
    expect(api.cancels, 1);
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Publish listing video'))
            .onPressed,
        isNull);
  });
  testWidgets('viewer has actual themed listing without owner controls',
      (t) async {
    final api = FakeApi()..owner = false;
    await launch(t, api);
    await enter(t);
    expect(find.text('Copper Observatory · synthetic'), findsOneWidget);
    expect(find.text('Private fixture player'), findsOneWidget);
    expect(find.text('Upload private draft'), findsNothing);
  });
  testWidgets('invalid file and cancelled selection never upload', (t) async {
    final api = FakeApi();
    await launch(t, api, clip: PreviewClip('bad.txt', Uint8List(10)));
    await enter(t);
    await t.tap(find.text('Choose synthetic MP4'));
    await t.pumpAndSettle();
    expect(find.textContaining('Choose an MP4'), findsOneWidget);
    expect(api.uploads, 0);
  });
  testWidgets('320 wide enlarged text scrolls without overflow', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final api = FakeApi();
    await launch(t, api, scale: 2);
    await enter(t);
    await t.scrollUntilVisible(find.text('Publish listing video'), 100,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('invalid session sign in is recoverable', (t) async {
    final api = FakeApi()..deny = true;
    await launch(t, api);
    await enter(t);
    expect(find.textContaining('Sign-in unavailable'), findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty);
    api.deny = false;
    await t.enterText(find.byType(TextField).last, 'synthetic');
    await t.tap(find.text('Sign in to local preview'));
    await t.pumpAndSettle();
    expect(find.text('Upload private draft'), findsOneWidget);
  });
  testWidgets('file chooser cancellation sends no upload', (t) async {
    final api = FakeApi();
    await launch(t, api);
    await enter(t);
    await t.tap(find.text('Choose synthetic MP4'));
    await t.pumpAndSettle();
    expect(find.text('Selection cancelled.'), findsOneWidget);
    expect(api.uploads, 0);
  });
}
