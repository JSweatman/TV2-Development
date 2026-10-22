import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/main.dart';
import 'package:tv2/models.dart';
import 'package:tv2/resolver_api.dart';

class FakeApi implements ResolverApi {
  @override
  Future<List<CountryNamespace>> countries() async => const [
        CountryNamespace(
          iso2: 'US',
          countryName: 'United States',
          nid: '1',
          defaultLanguageTag: 'en-US',
        ),
        CountryNamespace(
          iso2: 'IN',
          countryName: 'India',
          nid: '91',
          defaultLanguageTag: 'en-IN',
        ),
      ];

  @override
  Future<PrefixResponse> prefix({
    required String input,
    required String country,
    int limit = 10,
  }) async {
    if (!'529'.startsWith(input)) {
      return PrefixResponse(
        countryContext: country,
        input: input,
        matches: const [],
        hasMore: false,
      );
    }
    return PrefixResponse(
      countryContext: country,
      input: input,
      hasMore: false,
      matches: [
        MatchRecord(
          countryCode: country,
          listNumber: '529',
          tldx: null,
          displayName: country == '91' ? 'Fixture India' : 'Fixture Alpha',
          entityType: 'person',
          qualifiedInput: '$country*529',
          exact: input == '529',
        ),
      ],
    );
  }

  @override
  Future<ResolveResponse> resolve({
    required String input,
    required String country,
  }) async => ResolveResponse(
        status: input == '529' ? 'resolved' : 'not_found',
        countryContext: country,
        input: input,
        listing: input == '529'
            ? Listing(
                countryCode: country,
                listNumber: '529',
                tldx: null,
                displayName: country == '91' ? 'Fixture India' : 'Fixture Alpha',
                entityType: 'person',
                templateKey: 'basic',
                resources: const [
                  ResourceRecord(
                    key: 'call',
                    type: 'call',
                    uri: null,
                    metadata: {},
                  ),
                ],
                buttons: const [],
              )
            : null,
      );
}

// Simulates the FastAPI rule: an explicit NID in the input takes precedence
// over the selected default country. Tests the Flutter request/state boundary.
class NamespaceAwareApi extends FakeApi {
  String? lastPrefixInput;
  String? lastPrefixCountry;

  ({String bare, String effectiveCountry}) parseForTest(
    String input,
    String country,
  ) {
    final separator = input.indexOf('*');
    if (separator > 0) {
      return (
        bare: input.substring(separator + 1),
        effectiveCountry: input.substring(0, separator),
      );
    }
    return (bare: input, effectiveCountry: country);
  }

  @override
  Future<PrefixResponse> prefix({
    required String input,
    required String country,
    int limit = 10,
  }) async {
    lastPrefixInput = input;
    lastPrefixCountry = country;
    final parsed = parseForTest(input, country);
    final result = await super.prefix(
      input: parsed.bare,
      country: parsed.effectiveCountry,
      limit: limit,
    );
    return PrefixResponse(
      countryContext: country,
      input: input,
      matches: result.matches,
      hasMore: result.hasMore,
    );
  }

  @override
  Future<ResolveResponse> resolve({
    required String input,
    required String country,
  }) async {
    final parsed = parseForTest(input, country);
    final result = await super.resolve(
      input: parsed.bare,
      country: parsed.effectiveCountry,
    );
    return ResolveResponse(
      status: result.status,
      countryContext: country,
      input: input,
      listing: result.listing,
    );
  }
}

class SharedCallingCodeApi extends FakeApi {
  @override
  Future<List<CountryNamespace>> countries() async => [
        ...await super.countries(),
        const CountryNamespace(
          iso2: 'CA',
          countryName: 'Canada',
          nid: '1',
          defaultLanguageTag: 'en-CA',
        ),
      ];
}

class SlowCountryApi extends FakeApi {
  final countryResponse = Completer<List<CountryNamespace>>();

  @override
  Future<List<CountryNamespace>> countries() => countryResponse.future;
}

class FlakyCountryApi extends FakeApi {
  int countryFetches = 0;

  @override
  Future<List<CountryNamespace>> countries() async {
    countryFetches++;
    if (countryFetches == 1) {
      throw const ResolverApiException('Resolver request timed out.');
    }
    return super.countries();
  }
}

class OfflineResolverApi extends FakeApi {
  @override
  Future<PrefixResponse> prefix({
    required String input,
    required String country,
    int limit = 10,
  }) async {
    throw const ResolverApiException(
      'Resolver request timed out. Check your internet connection and try again.',
    );
  }
}

void main() {
  testWidgets('country directory shows connecting progress during a slow startup', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = SlowCountryApi();
    await tester.pumpWidget(TV2App(api: api));
    await tester.pump();

    expect(find.text('Loading countries…'), findsOneWidget);
    expect(find.textContaining('The test server may take longer'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Select Country / Namespace'), findsNothing);
    expect(find.text('US  +1'), findsNothing);

    api.countryResponse.complete(await FakeApi().countries());
    await tester.pumpAndSettle();

    expect(find.text('Select Country / Namespace'), findsOneWidget);
    await tester.tap(find.text('India'));
    await tester.pumpAndSettle();
    expect(find.text('IN  +91'), findsOneWidget);
    expect(find.textContaining('The test server may take longer'), findsNothing);
  });

  testWidgets('unqualified 529 follows selected country without changing input', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = NamespaceAwareApi();
    await tester.pumpWidget(TV2App(api: api, initialCountry: '1'));
    await tester.pumpAndSettle();

    for (final key in ['5', '2', '9']) {
      await tester.tap(find.text(key));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('529'), findsOneWidget);
    expect(find.text('Fixture Alpha'), findsWidgets);

    await tester.tap(find.text('US  +1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('India'));
    await tester.pumpAndSettle();

    expect(find.text('IN  +91'), findsOneWidget);
    expect(find.text('529'), findsOneWidget);
    expect(find.text('Fixture India'), findsWidgets);
    expect(api.lastPrefixInput, '529');
    expect(api.lastPrefixCountry, '91');
  });

  testWidgets('explicit 1*529 remains US-scoped after switching to India', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = NamespaceAwareApi();
    await tester.pumpWidget(TV2App(api: api, initialCountry: '1'));
    await tester.pumpAndSettle();

    for (final key in ['1', '*', '5', '2', '9']) {
      await tester.tap(find.text(key));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Fixture Alpha'), findsWidgets);

    await tester.tap(find.text('US  +1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('India'));
    await tester.pumpAndSettle();

    expect(find.text('IN  +91'), findsOneWidget);
    expect(find.text('1*529'), findsWidgets);
    expect(find.text('Fixture Alpha'), findsWidgets);
    expect(find.text('Fixture India'), findsNothing);
    expect(api.lastPrefixInput, '1*529');
    expect(api.lastPrefixCountry, '91');
  });

  testWidgets('saved country ISO2 survives restart when US and Canada both use +1', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(TV2App(api: SharedCallingCodeApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Canada'));
    await tester.pumpAndSettle();
    expect(find.text('CA  +1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(TV2App(api: SharedCallingCodeApi()));
    await tester.pumpAndSettle();

    expect(find.text('CA  +1'), findsOneWidget);
    expect(find.text('US  +1'), findsNothing);
    expect(find.text('Select Country / Namespace'), findsNothing);
  });

  testWidgets('offline resolver timeout gives actionable guidance', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(TV2App(api: OfflineResolverApi(), initialCountry: '1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('5'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.textContaining('Check your internet connection'), findsOneWidget);
    expect(find.textContaining('try again.'), findsOneWidget);
    expect(find.text('Fixture Alpha'), findsNothing);
  });

  testWidgets('failed country load offers a working retry', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = FlakyCountryApi();
    await tester.pumpWidget(TV2App(api: api));
    await tester.pumpAndSettle();

    expect(find.text('Retry Country'), findsOneWidget);
    expect(find.textContaining('Resolver request timed out.'), findsOneWidget);

    await tester.tap(find.text('Retry Country'));
    await tester.pumpAndSettle();

    expect(api.countryFetches, 2);
    expect(find.text('Select Country / Namespace'), findsOneWidget);
    await tester.tap(find.text('India'));
    await tester.pumpAndSettle();
    expect(find.text('IN  +91'), findsOneWidget);
  });


  testWidgets('progressive input reaches an exact backend-driven identity', (tester) async {
    await tester.pumpWidget(TV2App(api: FakeApi(), initialCountry: '1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('9'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Fixture Alpha'), findsWidgets);
    expect(find.text('EXACT'), findsOneWidget);
    expect(find.byTooltip('ENTER'), findsOneWidget);
  });

  testWidgets('first launch requires country selection instead of defaulting to +1', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(TV2App(api: FakeApi()));
    await tester.pumpAndSettle();

    expect(find.text('Select Country / Namespace'), findsOneWidget);
    expect(find.text('United States'), findsOneWidget);
    expect(find.text('India'), findsOneWidget);

    await tester.tap(find.text('India'));
    await tester.pumpAndSettle();
    expect(find.text('IN  +91'), findsOneWidget);
  });
}
