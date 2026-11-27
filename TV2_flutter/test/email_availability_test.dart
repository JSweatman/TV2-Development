import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/email_handoff.dart';
import 'package:tv2/main.dart';
import 'package:tv2/models.dart';
import 'package:tv2/resolver_api.dart';
import 'home_screen_test.dart' show FakeApi;
import 'listing_media_handoff_test.dart' show tapVisible;

Listing sample({String? address = 'first@example.invalid'}) => Listing(
        countryCode: '1',
        listNumber: '529',
        tldx: null,
        displayName: 'Synthetic email',
        entityType: 'business',
        templateKey: 'basic',
        resources: [
          if (address != null)
            ResourceRecord(
                key: 'email',
                type: 'email',
                uri: null,
                metadata: {'handoff': 'device', 'address': address})
        ],
        buttons: const [
          ButtonRecord(slot: 3, label: 'EMAIL', resourceKey: 'email')
        ]);

class EmailApi extends FakeApi {
  bool hold = false;
  final pending = <Completer<ResolveResponse>>[];
  final requests = <String>[];
  @override
  Future<ResolveResponse> resolve(
      {required String input, required String country}) {
    requests.add('$input|$country');
    if (!hold)
      return Future.value(ResolveResponse(
          status: 'resolved',
          countryContext: country,
          input: input,
          listing: sample()));
    final c = Completer<ResolveResponse>();
    pending.add(c);
    return c.future;
  }
}

void main() {
  for (final outcome in [
    'valid',
    'changed',
    'withdrawn',
    'removed',
    'invalid',
    'offline',
    'cancel-check',
    'cancel-compose',
    'no-handler'
  ]) {
    testWidgets('normal keypad to gated EMAIL: $outcome', (t) async {
      SharedPreferences.setMockInitialValues({});
      final api = EmailApi();
      final opened = <Uri>[];
      await t.pumpWidget(TV2App(
          api: api,
          initialCountry: '1',
          emailHandoff: EmailHandoff(open: (uri) async {
            opened.add(uri);
            return outcome != 'no-handler';
          })));
      await t.pumpAndSettle();
      for (final digit in '529'.split(''))
        await tapVisible(t, find.text(digit));
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      await tapVisible(t, find.byTooltip('ENTER'));
      api.hold = true;
      await t.ensureVisible(find.text('EMAIL'));
      await t.pumpAndSettle();
      await t.tap(find.text('EMAIL'));
      await t.pump(const Duration(milliseconds: 100));
      expect(api.pending, hasLength(1));
      expect(api.requests.last, '1*529|1');
      expect(opened, isEmpty);
      expect(find.text('Compose email'), findsNothing);
      if (outcome == 'offline') {
        api.pending.single
            .completeError(const ResolverApiException('Synthetic offline'));
      } else {
        api.pending.single.complete(ResolveResponse(
            status: outcome == 'withdrawn' ? 'not_found' : 'resolved',
            countryContext: '1',
            input: '1*529',
            listing: outcome == 'withdrawn'
                ? null
                : sample(
                    address: outcome == 'removed'
                        ? null
                        : outcome == 'invalid'
                            ? 'bad@example.invalid?body=x'
                            : outcome == 'changed'
                                ? 'current@example.invalid'
                                : 'first@example.invalid')));
      }
      await t.pumpAndSettle();
      if (outcome == 'withdrawn' || outcome == 'offline') {
        expect(
            find.text(outcome == 'withdrawn'
                ? 'This listing is no longer available.'
                : 'Unable to verify this listing. Reconnect and retry.'),
            findsOneWidget);
        expect(find.text('Continue'), findsNothing);
        expect(opened, isEmpty);
        return;
      }
      if (outcome == 'cancel-check') {
        await tapVisible(t, find.text('Cancel'));
        expect(opened, isEmpty);
        expect(find.text('Compose email'), findsNothing);
        return;
      }
      await tapVisible(t, find.text('Continue'));
      expect(opened, isEmpty);
      if (outcome == 'removed' || outcome == 'invalid') {
        expect(find.text('Compose email'), findsNothing);
        if (outcome == 'invalid')
          expect(find.text('No valid email destination is configured.'),
              findsOneWidget);
        return;
      }
      final address = outcome == 'changed'
          ? 'current@example.invalid'
          : 'first@example.invalid';
      expect(find.textContaining(address), findsOneWidget);
      if (outcome == 'changed')
        expect(find.textContaining('first@example.invalid'), findsNothing);
      if (outcome == 'cancel-compose') {
        await tapVisible(t, find.text('Cancel'));
        expect(opened, isEmpty);
        return;
      }
      await tapVisible(t, find.text('Compose email'));
      expect(opened, hasLength(1));
      expect(opened.single.toString(), 'mailto:$address');
      expect(opened.single.hasQuery, isFalse);
      expect(opened.single.hasFragment, isFalse);
      if (outcome == 'no-handler')
        expect(find.textContaining('No compatible email app opened.'),
            findsOneWidget);
    });
  }
}
