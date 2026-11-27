import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/email_handoff.dart';
import 'package:tv2/home_screen.dart';
import 'package:tv2/models.dart';
import 'package:tv2/public_resource_launcher.dart';
import 'landing_theme_test.dart' show fixture;

ResourceRecord email(
        {String address = 'demo@example.invalid',
        String? uri,
        String type = 'email',
        Map<String, dynamic> extra = const {}}) =>
    ResourceRecord(
        key: 'email',
        type: type,
        uri: uri,
        metadata: {'handoff': 'device', 'address': address, ...extra});
Listing page(ResourceRecord resource, String palette) =>
    fixture(palette: palette, extra: [
      resource
    ], buttons: const [
      ButtonRecord(slot: 3, label: 'EMAIL', resourceKey: 'email')
    ]);
void main() {
  test('typed single address only, no header/body/query injection', () {
    final uri = emailDestination(email())!;
    expect(uri.toString(), 'mailto:demo@example.invalid');
    expect(uri.hasQuery, isFalse);
    expect(uri.hasFragment, isFalse);
    expect(emailDestination(email(address: 'demo+tag@example.invalid')),
        isNotNull);
    for (final address in [
      '',
      'demo@example.invalid\n',
      'demo@example.invalid?subject=x',
      'demo@example.invalid#x',
      'demo@example.invalid,other@example.invalid',
      'demo@example.invalid;other@example.invalid',
      'Demo <demo@example.invalid>',
      'demo%0d%0a@example.invalid',
      'demo@example.invalid\r\nBcc:x',
      'demo..name@example.invalid',
      '.demo@example.invalid',
      'demo.@example.invalid',
      'demo@-example.invalid',
      'demo@example-.invalid',
      'demo@localhost',
      'demo@@example.invalid',
      'demo@exämple.invalid',
      ' demo@example.invalid',
      'demo@example.invalid '
    ]) {
      expect(emailDestination(email(address: address)), isNull,
          reason: address);
    }
    for (final extra in [
      {'body': 'x'},
      {'subject': 'x'},
      {'cc': 'other@example.invalid'},
      {'query': 'x'},
      {'handoff': 'web'}
    ]) {
      expect(emailDestination(email(extra: extra)), isNull);
    }
    expect(emailDestination(email(uri: 'mailto:demo@example.invalid')), isNull);
    expect(emailDestination(email(type: 'web')), isNull);
    expect(safePublicResourceUri('mailto:demo@example.invalid'), isNull);
  });
  for (final palette in ['graphite', 'lotus']) {
    testWidgets('$palette EMAIL requires confirmation and cancel never opens',
        (t) async {
      final opened = <Uri>[];
      await t.pumpWidget(MaterialApp(
          home: TemplateScreen(
              listing: page(email(), palette),
              emailHandoff: EmailHandoff(open: (uri) async {
                opened.add(uri);
                return true;
              }))));
      await t.scrollUntilVisible(find.text('EMAIL'), 150);
      await t.pumpAndSettle();
      await t.tap(find.text('EMAIL'));
      await t.pumpAndSettle();
      expect(find.text('Open email app?'), findsOneWidget);
      expect(opened, isEmpty);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(opened, isEmpty);
      await t.tap(find.text('EMAIL'));
      await t.pumpAndSettle();
      await t.tap(find.text('Compose email'));
      await t.pumpAndSettle();
      expect(opened.map((u) => u.toString()), ['mailto:demo@example.invalid']);
    });
  }
  testWidgets('invalid configured email is omitted from six-action layout',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: TemplateScreen(
            listing: page(email(address: 'bad?body=x'), 'lotus'))));
    await t.pumpAndSettle();
    // Current visitor UI hides unconfigured actions instead of advertising them.
    expect(find.widgetWithText(FilledButton, 'EMAIL'), findsNothing);
  });
  for (final throws in [false, true]) {
    testWidgets(
        'missing handler fallback (throws=$throws), 320 wide at 2x text',
        (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          builder: (c, w) => MediaQuery(
              data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(2)),
              child: w!),
          home: TemplateScreen(
              listing: page(email(), 'lotus'),
              emailHandoff: EmailHandoff(open: (_) async {
                if (throws) throw StateError('No handler');
                return false;
              }))));
      await t.scrollUntilVisible(find.text('EMAIL'), 150);
      await t.pumpAndSettle();
      await t.tap(find.text('EMAIL'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Compose email'));
      await t.tap(find.text('Compose email'));
      await t.pumpAndSettle();
      expect(
          find.text(
              'No compatible email app opened. Use demo@example.invalid manually.'),
          findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('repeated confirmation launches at most once', (t) async {
    final pending = Completer<bool>();
    var calls = 0;
    await t.pumpWidget(MaterialApp(
        home: TemplateScreen(
            listing: page(email(), 'lotus'),
            emailHandoff: EmailHandoff(open: (_) {
              calls++;
              return pending.future;
            }))));
    await t.scrollUntilVisible(find.text('EMAIL'), 150);
    await t.pumpAndSettle();
    await t.tap(find.text('EMAIL'));
    await t.pumpAndSettle();
    await t.tap(find.text('Compose email'));
    await t.pump();
    await t.tap(find.text('Compose email'));
    await t.pump();
    expect(calls, 1);
    pending.complete(false);
    await t.pumpAndSettle();
  });
}
