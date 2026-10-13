import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/main.dart';
import 'package:tv2/models.dart';
import 'package:tv2/resolver_api.dart';

class FakeApi implements ResolverApi {
  static const listing = Listing(
    countryCode: '1',
    listNumber: '529',
    tldx: null,
    displayName: 'Fixture Alpha',
    entityType: 'person',
    templateKey: 'basic',
    resources: [
      ResourceRecord(key: 'call', type: 'call', uri: null, metadata: {}),
    ],
    buttons: [],
  );

  @override
  Future<PrefixResponse> prefix({required String input, required String country, int limit = 10}) async {
    if (!'529'.startsWith(input)) {
      return PrefixResponse(countryContext: country, input: input, matches: const [], hasMore: false);
    }
    return PrefixResponse(
      countryContext: country,
      input: input,
      hasMore: false,
      matches: [
        MatchRecord(
          countryCode: '1',
          listNumber: '529',
          tldx: null,
          displayName: 'Fixture Alpha',
          entityType: 'person',
          qualifiedInput: '1*529',
          exact: input == '529',
        ),
      ],
    );
  }

  @override
  Future<ResolveResponse> resolve({required String input, required String country}) async =>
      ResolveResponse(
        status: input == '529' ? 'resolved' : 'not_found',
        countryContext: country,
        input: input,
        listing: input == '529' ? listing : null,
      );
}

void main() {
  testWidgets('progressive input reaches an exact backend-driven identity', (tester) async {
    await tester.pumpWidget(const TV2App(api: FakeApi()));
    await tester.tap(find.text('5'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('9'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Fixture Alpha'), findsWidgets);
    expect(find.text('EXACT'), findsOneWidget);
    expect(find.byTooltip('ENTER'), findsOneWidget);
  });
}
