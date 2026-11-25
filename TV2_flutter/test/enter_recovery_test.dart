import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/home_screen.dart';
import 'package:tv2/models.dart';
import 'home_screen_test.dart' show NamespaceAwareApi, tapVisible;

class HeldEnterApi extends NamespaceAwareApi {
  final calls =
      <({String input, String country, Completer<ResolveResponse> reply})>[];
  @override
  Future<PrefixResponse> prefix(
          {required String input,
          required String country,
          int limit = 10}) async =>
      PrefixResponse(
          countryContext: country,
          input: input,
          matches: const [],
          hasMore: false);
  @override
  Future<ResolveResponse> resolve(
      {required String input, required String country}) {
    final reply = Completer<ResolveResponse>();
    calls.add((input: input, country: country, reply: reply));
    return reply.future;
  }

  void complete(int index) {
    final call = calls[index];
    call.reply.complete(ResolveResponse(
        status: 'resolved',
        countryContext: call.country,
        input: call.input,
        listing: Listing(
            countryCode: call.country,
            listNumber: call.input,
            tldx: null,
            displayName: 'Synthetic ${call.country}:${call.input}',
            entityType: 'business',
            templateKey: 'basic',
            resources: const [],
            buttons: const [])));
  }
}

void main() {
  for (final newerFirst in [false, true]) {
    for (final changeCountry in [false, true]) {
      testWidgets(
          'corrected ENTER owns pending state: newerFirst=$newerFirst country=$changeCountry',
          (t) async {
        SharedPreferences.setMockInitialValues({});
        final api = HeldEnterApi();
        await t.pumpWidget(
            MaterialApp(home: HomeScreen(api: api, initialCountry: '1')));
        await t.pumpAndSettle();
        Future<void> tap(Finder finder) async {
          await tapVisible(t, finder);
          await t.pump();
        }

        for (final digit in '700002'.split('')) {
          await tap(find.widgetWithText(FilledButton, digit));
        }
        await tap(find.byTooltip('ENTER'));
        expect(api.calls.map((c) => c.input), ['700002']);
        if (changeCountry) {
          await tap(find.text('+1'));
          await t.pump(const Duration(milliseconds: 350));
          await tap(find.text('India'));
          await t.pump(const Duration(milliseconds: 350));
        } else {
          await tap(find.byTooltip('BACK'));
          await tap(find.widgetWithText(FilledButton, '1'));
        }
        await tap(find.byTooltip('ENTER'));
        expect(api.calls.length, 2,
            reason: 'corrected ENTER must not wait for obsolete reply');
        expect(api.calls[1].input, changeCountry ? '700002' : '700001');
        expect(api.calls[1].country, changeCountry ? '91' : '1');
        await tap(find.byTooltip('ENTER'));
        expect(api.calls.length, 2);
        if (!newerFirst) {
          api.complete(0);
          await t.pump();
          expect(find.byType(TemplateScreen), findsNothing);
          await tap(find.byTooltip('ENTER'));
          expect(api.calls.length, 2,
              reason: 'obsolete completion must not unlock corrected ENTER');
        }
        api.complete(1);
        await t.pumpAndSettle();
        expect(find.byType(TemplateScreen), findsOneWidget);
        expect(
            t
                .widget<TemplateScreen>(find.byType(TemplateScreen))
                .listing
                .qualifiedIdentity,
            changeCountry ? '91*700002' : '1*700001');
        if (newerFirst) {
          api.complete(0);
          await t.pumpAndSettle();
        }
        await t.pageBack();
        await t.pumpAndSettle();
        expect(find.byType(TemplateScreen), findsNothing,
            reason: 'no duplicate route underneath');
        expect(find.text(changeCountry ? '700002' : '700001'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }
}
