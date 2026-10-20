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

void main() {
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
