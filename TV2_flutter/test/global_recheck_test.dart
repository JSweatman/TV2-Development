import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tv2/resolver_api.dart';
import 'package:tv2/models.dart';
import 'package:tv2/listing_availability_gate.dart';

void main() {
  test('global prefix omits empty default namespace', () async {
    final api = HttpResolverApi(
        baseUri: Uri.parse('https://resolver.example.test'),
        client: MockClient((r) async {
          expect(r.url.path, '/v1/prefix');
          expect(r.url.queryParameters['input'], '*529');
          expect(r.url.queryParameters.containsKey('country'), false);
          return http.Response(
              '{"input":"*529","matches":[],"has_more":false}', 200);
        }));
    await api.prefix(input: '*529', country: '');
  });
  for (final country in <String?>[null, '1']) {
    testWidgets('HTTP action and resume preserve qualified identity $country',
        (t) async {
      final input = '${country ?? ''}*529';
      var active = true;
      var opened = 0;
      final requests = <Uri>[];
      final data = {
        'country_code': country,
        'list_number': '529',
        'display_name': 'Synthetic',
        'entity_type': 'business',
        'template_key': 'basic',
        'resources': <Object>[],
        'buttons': <Object>[]
      };
      final api = HttpResolverApi(
          baseUri: Uri.parse('https://resolver.example.test'),
          client: MockClient((r) async {
            requests.add(r.url);
            expect(r.url.queryParameters['input'], input);
            expect(r.url.queryParameters['country'], country);
            // Real FastAPI rejects a present empty country before parsing input.
            if (r.url.queryParameters['country'] == '')
              return http.Response('{}', 422);
            return http.Response(
                jsonEncode({
                  'status': active ? 'resolved' : 'not_found',
                  'input': input,
                  'country_context': country,
                  'listing': active ? data : null
                }),
                200);
          }));
      await t.pumpWidget(MaterialApp(
          home: ListingAvailabilityGate(
              api: api,
              listing: Listing.fromJson(data),
              builder: (listing, authorize) => TextButton(
                  onPressed: () => authorize(() {
                        opened++;
                      }),
                  child: const Text('WEBSITE')))));
      await t.tap(find.text('WEBSITE'));
      await t.pumpAndSettle();
      expect(opened, 0);
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(opened, 1);
      active = false;
      await t.runAsync(() async {
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await t.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(find.text('This listing is no longer available.'), findsOneWidget);
      expect(find.text('WEBSITE'), findsNothing);
      expect(opened, 1);
      expect(requests, hasLength(2));
    });
  }
}
