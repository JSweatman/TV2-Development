import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/home_screen.dart';
import 'package:tv2/models.dart';
import 'package:tv2/resolver_api.dart';
import 'home_screen_test.dart' show FakeApi, tapVisible;

class RetryDirectoryApi extends FakeApi {
  final first = Completer<List<CountryNamespace>>();
  final retry = Completer<List<CountryNamespace>>();
  int fetches = 0;
  final prefixes = <String>[];
  final held = Completer<PrefixResponse>();
  bool holdPreview = false;
  @override
  Future<List<CountryNamespace>> countries() =>
      ++fetches == 1 ? first.future : retry.future;
  @override
  Future<PrefixResponse> prefix(
      {required String input, required String country, int limit = 10}) {
    prefixes.add('$country:$input');
    if (holdPreview && prefixes.length == 1) return held.future;
    return super.prefix(input: input, country: country, limit: limit);
  }
}

void main() {
  for (final scenario in [(true, true), (false, true), (true, false)]) {
    final (saved, failsFirst) = scenario;
    testWidgets(
        'directory retry restores preview with saved country=$saved initial failure=$failsFirst',
        (t) async {
      SharedPreferences.setMockInitialValues(
          saved ? {'tv2_selected_nid': '1'} : {});
      final api = RetryDirectoryApi();
      await t.pumpWidget(MaterialApp(home: HomeScreen(api: api)));
      for (final digit in '529'.split('')) {
        await tapVisible(t, find.widgetWithText(FilledButton, digit));
        await t.pump();
      }
      if (failsFirst) {
        api.first.completeError(
            const ResolverApiException('Synthetic directory failure'));
        await t.pumpAndSettle();
        await t.pump(const Duration(milliseconds: 300));
        await t.pumpAndSettle();
        expect(api.prefixes, isEmpty);
        await tapVisible(t, find.text('Retry Country'));
        await t.pump();
        api.retry.complete(await FakeApi().countries());
      } else {
        api.first.complete(await FakeApi().countries());
      }
      await t.pumpAndSettle();
      if (!saved) {
        expect(find.text('Select Country / Namespace'), findsOneWidget);
        await tapVisible(t, find.text('Shared calling-code namespace'));
        await t.pumpAndSettle();
      }
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      expect(find.text('529'), findsOneWidget);
      expect(find.text('Fixture Alpha'), findsNWidgets(2),
          reason:
              'both identity panel and suggestion show the expected name before ENTER');
      expect(find.byType(TemplateScreen), findsNothing);
      expect(api.prefixes, ['1:529']);
    });
  }

  testWidgets('edit invalidates restored preview while its response is pending',
      (t) async {
    SharedPreferences.setMockInitialValues({'tv2_selected_nid': '1'});
    final api = RetryDirectoryApi()..holdPreview = true;
    await t.pumpWidget(MaterialApp(home: HomeScreen(api: api)));
    api.first.completeError(
        const ResolverApiException('Synthetic directory failure'));
    await t.pumpAndSettle();
    for (final digit in '529'.split('')) {
      await tapVisible(t, find.widgetWithText(FilledButton, digit));
      await t.pump();
    }
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    await tapVisible(t, find.text('Retry Country'));
    await t.pump();
    api.retry.complete(await FakeApi().countries());
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(api.prefixes, ['1:529']);
    await tapVisible(t, find.byTooltip('BACK'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    api.held.complete(await FakeApi().prefix(input: '529', country: '1'));
    await t.pumpAndSettle();
    expect(find.text('52'), findsOneWidget);
    // A prefix suggestion is allowed; the obsolete exact identity is not.
    expect(find.text('Fixture Alpha'), findsOneWidget);
    expect(api.prefixes, ['1:529', '1:52']);
    expect(find.byType(TemplateScreen), findsNothing);
  });
}
