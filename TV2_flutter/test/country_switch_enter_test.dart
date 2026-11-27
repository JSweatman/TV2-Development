import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/home_screen.dart';
import 'package:tv2/models.dart';

import 'home_screen_test.dart' show FakeApi, tapVisible;

class CountrySwitchApi extends FakeApi {
  final newCountryPreview = Completer<PrefixResponse>();
  final requests = <String>[];

  @override
  Future<PrefixResponse> prefix({
    required String input,
    required String country,
    int limit = 10,
  }) {
    requests.add('prefix:$country:$input');
    if (country == '91') return newCountryPreview.future;
    return super.prefix(input: input, country: country, limit: limit);
  }

  @override
  Future<ResolveResponse> resolve({
    required String input,
    required String country,
  }) {
    requests.add('resolve:$country:$input');
    return super.resolve(input: input, country: country);
  }

  Future<void> releasePreview() async {
    newCountryPreview.complete(await super.prefix(input: '529', country: '91'));
  }
}

void main() {
  testWidgets(
      'country switch ENTER replaces cached exact listing before new preview replies',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = CountrySwitchApi();
    await tester.pumpWidget(
        MaterialApp(home: HomeScreen(api: api, initialCountry: '1')));
    await tester.pumpAndSettle();
    for (final digit in ['5', '2', '9']) {
      await tapVisible(tester, find.widgetWithText(FilledButton, digit));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Fixture Alpha'), findsWidgets);
    expect(api.requests.last, 'resolve:1:529');
    expect(find.byType(TemplateScreen), findsNothing);

    await tapVisible(tester, find.text('+1'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('India'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('IN  +91'), findsOneWidget);
    expect(find.text('529'), findsOneWidget);
    expect(api.requests.last, 'prefix:91:529');
    expect(api.newCountryPreview.isCompleted, isFalse);

    // Tap while the new-country prefix is genuinely pending. The previously
    // resolved exact listing must not be used as the ENTER destination.
    final beforeEnter = api.requests.length;
    await tapVisible(tester, find.byTooltip('ENTER'));
    await tester.pumpAndSettle();
    expect(find.byType(TemplateScreen), findsOneWidget);
    final opened = tester.widget<TemplateScreen>(find.byType(TemplateScreen));
    expect(opened.listing.qualifiedIdentity, '91*529');
    expect(opened.listing.displayName, 'Fixture India');
    expect(api.requests.skip(beforeEnter).toList(), ['resolve:91:529']);
    expect(api.newCountryPreview.isCompleted, isFalse);

    // Releasing the superseded prefix cannot start another exact lookup or
    // replace the listing. Back must retain the new namespace and bare digits.
    final afterEnter = List<String>.of(api.requests);
    await api.releasePreview();
    await tester.pumpAndSettle();
    expect(api.requests, afterEnter);
    expect(
        tester
            .widget<TemplateScreen>(find.byType(TemplateScreen))
            .listing
            .qualifiedIdentity,
        '91*529');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(TemplateScreen), findsNothing);
    expect(find.text('IN  +91'), findsOneWidget);
    expect(find.text('529'), findsOneWidget);
    expect(find.text('Fixture India'), findsWidgets);
    expect(find.text('Fixture Alpha'), findsNothing);
  });
}
