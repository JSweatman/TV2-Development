import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/private_media_widgets.dart';

class FakeApi implements PreviewMediaApi {
  bool owner = true, deny = false;
  int uploads = 0, publishes = 0, cancels = 0, signIns = 0;
  Object? uploadError;
  Completer<String>? pending;
  @override
  Future<bool> signIn(String e, String p) async {
    signIns++;
    if (deny) throw StateError('denied');
    return owner;
  }

  @override
  Future<String> upload(Uint8List b) async {
    uploads++;
    if (uploadError != null) throw uploadError!;
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

class PreviewProbe extends StatefulWidget {
  const PreviewProbe({super.key, required this.onDispose});
  final VoidCallback onDispose;
  @override
  State<PreviewProbe> createState() => _PreviewProbeState();
}
class _PreviewProbeState extends State<PreviewProbe> {
  @override
  void dispose() { widget.onDispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => const Text('Local preview probe');
}

void main() {
  testWidgets('replacement clears old draft and disposes local preview without writes', (t) async {
    final api = FakeApi();
    var disposed = 0;
    var next = PreviewClip('first.mp4', Uint8List(12));
    Completer<PreviewClip?>? picker;
    await t.pumpWidget(MaterialApp(home: PrivateMediaPreview(
      api: api, pick: () => picker?.future ?? Future.value(next),
      player: () => const SizedBox(),
      selectedPreview: (_) => PreviewProbe(onDispose: () => disposed++))));
    await enter(t);
    await t.tap(find.text('Choose synthetic MP4')); await t.pumpAndSettle();
    expect(api.uploads, 0); expect(api.publishes, 0);
    await t.tap(find.text('Upload private draft')); await t.pumpAndSettle();
    picker = Completer<PreviewClip?>();
    await t.tap(find.text('Choose synthetic MP4')); await t.pump();
    expect(disposed, 1);
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publish listing video')).onPressed, isNull);
    picker!.complete(next = PreviewClip('second.mp4', Uint8List(16)));
    await t.pumpAndSettle();
    expect(api.uploads, 1); expect(api.publishes, 0);
    expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publish listing video')).onPressed, isNull);
    picker = Completer<PreviewClip?>();
    await t.tap(find.text('Choose synthetic MP4')); await t.pump();
    expect(disposed, 2);
    await t.tap(find.text('Cancel action')); await t.pump();
    picker!.complete(next); await t.pumpAndSettle();
    expect(find.text('Local preview probe'), findsNothing);
    picker = null;
    await t.tap(find.text('Choose synthetic MP4')); await t.pumpAndSettle();
    await t.tap(find.text('Sign out')); await t.pumpAndSettle();
    expect(disposed, 3);
    await enter(t);
    await t.tap(find.text('Choose synthetic MP4')); await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
    expect(disposed, 4);
  });

  test('fixed status guidance is upload-specific and never echoes errors', () {
    for (final entry in {
      413: '5 MiB',
      415: 'MOV',
      422: 'H.264',
      401: 'Session unavailable',
      403: 'Permission denied',
    }.entries) {
      expect(
        previewActionFailure(PreviewMediaFailure(entry.key), upload: true),
        contains(entry.value),
      );
    }
    expect(
      previewActionFailure(const PreviewMediaFailure(422), upload: false),
      startsWith('Action failed.'),
    );
    expect(
      previewActionFailure(StateError('private response'), upload: true),
      isNot(contains('private response')),
    );
    expect(
      previewActionFailure(const PreviewMediaFailure(503), upload: true),
      startsWith('Action failed.'),
    );
  });
  testWidgets(
    'invalid upload replacement keeps session and requires explicit publish',
    (t) async {
      final api = FakeApi()..uploadError = const PreviewMediaFailure(422);
      await launch(t, api, clip: PreviewClip('synthetic.mp4', Uint8List(12)));
      await enter(t);
      await t.tap(find.text('Choose synthetic MP4'));
      await t.pumpAndSettle();
      await t.tap(find.text('Upload private draft'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('This clip could not be validated'),
        findsOneWidget,
      );
      expect(api.publishes, 0);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Publish listing video'),
            )
            .onPressed,
        isNull,
      );
      api.uploadError = null;
      await t.tap(find.text('Choose synthetic MP4'));
      await t.pumpAndSettle();
      await t.tap(find.text('Upload private draft'));
      await t.pumpAndSettle();
      expect(api.signIns, 1);
      expect(api.publishes, 0);
      await t.tap(find.text('Publish listing video'));
      await t.pumpAndSettle();
      expect(api.publishes, 1);
    },
  );
  testWidgets('validation guidance is reachable at 320 wide and enlarged text', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final api = FakeApi()..uploadError = const PreviewMediaFailure(422);
    await launch(t, api, scale: 2, clip: PreviewClip('synthetic.mp4', Uint8List(12)));
    await enter(t);
    final scroll = find.byType(Scrollable).first;
    await Scrollable.ensureVisible(t.element(find.text('Choose synthetic MP4')), alignment: 0.5);
    await t.pumpAndSettle();
    await t.tap(find.text('Choose synthetic MP4'));
    await t.pumpAndSettle();
    await Scrollable.ensureVisible(t.element(find.text('Upload private draft')), alignment: 0.5);
    await t.pumpAndSettle();
    await t.tap(find.text('Upload private draft'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.textContaining('This clip could not be validated'), 100, scrollable: scroll);
    expect(find.textContaining('H.264'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('cancelled late validation failure cannot replace status', (
    t,
  ) async {
    final api = FakeApi()..pending = Completer<String>();
    await launch(t, api, clip: PreviewClip('synthetic.mp4', Uint8List(12)));
    await enter(t);
    await t.tap(find.text('Choose synthetic MP4'));
    await t.pumpAndSettle();
    await t.tap(find.text('Upload private draft'));
    await t.pump();
    await t.tap(find.text('Cancel action'));
    api.pending!.completeError(const PreviewMediaFailure(422));
    await t.pumpAndSettle();
    expect(
      find.textContaining('Cancelled. Nothing was published'),
      findsOneWidget,
    );
    expect(
      find.textContaining('This clip could not be validated'),
      findsNothing,
    );
  });

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
