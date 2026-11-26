import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/main.dart';
import 'package:tv2/device_handoff.dart';
import 'package:tv2/models.dart';
import 'package:tv2/resolver_api.dart';
import 'home_screen_test.dart' show FakeApi;
import 'listing_media_handoff_test.dart' show tapVisible;

Listing fixture(String? country, {String? phone = '+12025550101'}) => Listing(
        countryCode: country,
        listNumber: '529',
        tldx: null,
        displayName: 'Synthetic',
        entityType: 'test',
        templateKey: 'basic',
        resources: [
          if (phone != null)
            ResourceRecord(
                key: 'call',
                type: 'call',
                uri: null,
                metadata: {'handoff': 'device', 'phone_e164': phone})
        ],
        buttons: const []);

class CallApi extends FakeApi {
  CallApi(this.country);
  final String? country;
  bool hold = false;
  final pending = <Completer<ResolveResponse>>[];
  final requests = <String>[];
  @override
  Future<PrefixResponse> prefix(
          {required String input,
          required String country,
          int limit = 10}) async =>
      PrefixResponse(
          countryContext: this.country,
          input: input,
          hasMore: false,
          matches: [
            if (!hold && input == (this.country == null ? '*529' : '529'))
              MatchRecord(
                  countryCode: this.country,
                  listNumber: '529',
                  tldx: null,
                  displayName: 'Synthetic',
                  entityType: 'test',
                  qualifiedInput: '${this.country ?? ''}*529',
                  exact: true)
          ]);
  @override
  Future<ResolveResponse> resolve(
      {required String input, required String country}) async {
    requests.add('$input|$country');
    if (!hold) return reply(fixture(this.country));
    final c = Completer<ResolveResponse>();
    pending.add(c);
    return c.future;
  }

  ResolveResponse reply(Listing? listing) => ResolveResponse(
      status: listing == null ? 'not_found' : 'resolved',
      countryContext: country,
      input: '${country ?? ''}*529',
      listing: listing);
}

Future<void> tapPending(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.tap(finder);
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final country in <String?>['1', null]) {
    for (final outcome in [
      'missing',
      'removed',
      'changed',
      'wrong-namespace',
      'offline'
    ]) {
      testWidgets('keypad CALL rechecks $country $outcome', (t) async {
        SharedPreferences.setMockInitialValues({});
        final api = CallApi(country);
        final opened = <Uri>[];
        await t.pumpWidget(TV2App(
            api: api,
            initialCountry: '1',
            deviceHandoff: DeviceHandoff(open: (uri) async {
              opened.add(uri);
              return true;
            })));
        await t.pumpAndSettle();
        for (final digit in (country == null ? '*529' : '529').split('')) {
          await tapVisible(t, find.text(digit));
        }
        await t.pump(const Duration(milliseconds: 350));
        await t.pumpAndSettle();
        api.hold = true;
        await tapPending(t, find.byTooltip('CALL'));
        expect(api.pending, hasLength(1));
        expect(api.requests.last, '${country ?? ''}*529|${country ?? ''}');
        expect(find.text('Open device app'), findsNothing);
        expect(opened, isEmpty);
        if (outcome == 'offline') {
          api.pending.single
              .completeError(const ResolverApiException('Offline'));
        } else {
          api.pending.single.complete(api.reply(outcome == 'missing'
              ? null
              : fixture(
                  outcome == 'wrong-namespace'
                      ? (country == null ? '1' : null)
                      : country,
                  phone: outcome == 'removed' ? null : '+12025550102')));
        }
        await t.pumpAndSettle();
        if (outcome == 'changed') {
          expect(find.textContaining('+12025550102'), findsOneWidget);
          expect(find.textContaining('+12025550101'), findsNothing);
          expect(opened, isEmpty);
          await t.tap(find.text('Open device app'));
          await t.pumpAndSettle();
          expect(opened.single.toString(), 'tel:+12025550102');
        } else {
          expect(find.text('Open device app'), findsNothing);
          expect(opened, isEmpty);
        }
      });
    }
  }
  for (final edit in ['backspace', 'country', 'clear']) {
    testWidgets(
        '$edit invalidates pending CALL and repeated CALL cannot duplicate',
        (t) async {
      SharedPreferences.setMockInitialValues({});
      final api = CallApi('1');
      final opened = <Uri>[];
      await t.pumpWidget(TV2App(
          api: api,
          initialCountry: '1',
          deviceHandoff: DeviceHandoff(open: (uri) async {
            opened.add(uri);
            return true;
          })));
      await t.pumpAndSettle();
      for (final d in '529'.split('')) {
        await tapVisible(t, find.text(d));
      }
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
      api.hold = true;
      await tapPending(t, find.byTooltip('CALL'));
      await tapPending(t, find.byTooltip('CALL'));
      expect(api.pending, hasLength(1));
      if (edit == 'country') {
        await tapPending(t, find.text('+1'));
        await t.pump(const Duration(milliseconds: 400));
        await t.ensureVisible(find.text('India'));
        await t.pump(const Duration(milliseconds: 100));
        expect(find.text('India').hitTestable(), findsOneWidget);
        await tapPending(t, find.text('India'));
        await t.pump(const Duration(milliseconds: 400));
        expect(
            (await SharedPreferences.getInstance())
                .getString('tv2_selected_nid'),
            '91');
      } else {
        await tapPending(t, find.byTooltip(edit == 'clear' ? 'Clear' : 'BACK'));
      }
      api.pending.single.complete(api.reply(fixture('1')));
      await t.pumpAndSettle();
      expect(find.text('Open device app'), findsNothing);
      expect(opened, isEmpty);
    });
  }
}
