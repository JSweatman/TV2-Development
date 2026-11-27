import 'package:flutter/material.dart';
import 'package:tv2/main.dart';
import 'package:tv2/models.dart';
import 'package:tv2/resolver_api.dart';

void main() {
  if (Uri.base.host != '127.0.0.1') throw StateError('Local only');
  runApp(TV2App(api: FakeApi()));
}

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
    if (!'70001'.startsWith(input.split('*').last)) {
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
          listNumber: '70001',
          tldx: null,
          displayName:
              country == '91' ? 'Fixture India' : 'Synthetic viewport listing',
          entityType: 'person',
          qualifiedInput: '$country*70001',
          exact: input.split('*').last == '70001',
        ),
      ],
    );
  }

  @override
  Future<ResolveResponse> resolve({
    required String input,
    required String country,
  }) async =>
      ResolveResponse(
        status: input.split('*').last == '70001' ? 'resolved' : 'not_found',
        countryContext: country,
        input: input,
        listing: input.split('*').last == '70001'
            ? Listing(
                countryCode: country,
                listNumber: '70001',
                tldx: null,
                displayName: country == '91'
                    ? 'Fixture India'
                    : 'Synthetic viewport listing',
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
