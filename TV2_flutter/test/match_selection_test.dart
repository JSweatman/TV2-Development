import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/main.dart';
import 'package:tv2/models.dart';
import 'package:tv2/resolver_api.dart';
import 'home_screen_test.dart' show NamespaceAwareApi;

const chosen = '91*529.xyz';

class SelectionApi extends NamespaceAwareApi {
  final pending = <String, Completer<PrefixResponse>>{};
  bool failSelected = false;
  PrefixResponse response(String input, String country) => PrefixResponse(
        countryContext: country,
        input: input,
        hasMore: false,
        matches: [
          MatchRecord(
              countryCode: '91',
              listNumber: '529',
              tldx: 'xyz',
              displayName: 'Synthetic choice',
              entityType: 'person',
              qualifiedInput: chosen,
              exact: input == chosen),
          if (input != chosen)
            MatchRecord(
                countryCode: '1',
                listNumber: '530',
                tldx: null,
                displayName: 'Other choice',
                entityType: 'person',
                qualifiedInput: '1*530',
                exact: false)
        ],
      );
  @override
  Future<PrefixResponse> prefix(
      {required String input, required String country, int limit = 10}) async {
    if (failSelected && input == chosen)
      throw const ResolverApiException('Synthetic lookup failed');
    return pending[input]?.future ?? response(input, country);
  }

  @override
  Future<ResolveResponse> resolve(
          {required String input, required String country}) async =>
      ResolveResponse(
          status: 'resolved',
          countryContext: country,
          input: input,
          listing: Listing(
              countryCode: '91',
              listNumber: '529',
              tldx: 'xyz',
              displayName: 'Synthetic selected listing',
              entityType: 'person',
              templateKey: 'basic',
              resources: const [],
              buttons: const []));
}

final panel = find.byKey(const Key('tv2-home-match-viewport'));
Future<void> settleLookup(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 300));
  await t.pumpAndSettle();
}

Future<void> launch(WidgetTester t, SelectionApi api,
    {Size size = const Size(360, 740)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'tv2_selected_nid': '1'});
  await t.pumpWidget(TV2App(api: api));
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.tap(finder);
  await settleLookup(t);
}

void main() {
  for (final size in [
    const Size(360, 740),
    const Size(390, 844),
    const Size(1280, 800)
  ]) {
    testWidgets('select collapses, ENTER opens, return retains suffix $size',
        (t) async {
      await launch(t, SelectionApi(), size: size);
      await tap(t, find.text('5'));
      await tap(t, find.text('Synthetic choice'));
      expect(t.getSize(panel).height, 0);
      expect(find.text(chosen), findsOneWidget);
      expect(find.byTooltip('Save listing'), findsNothing);
      expect(t.getRect(find.byTooltip('ENTER')).bottom,
          lessThanOrEqualTo(size.height));
      await tap(t, find.byTooltip('ENTER'));
      expect(find.byTooltip('Save listing'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text(chosen), findsOneWidget);
      expect(t.getSize(panel).height, 0);
      await tap(t, find.byTooltip('BACK'));
      expect(t.getSize(panel).height, greaterThan(0));
      expect(find.text('Synthetic choice'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
      'semantics activation, country change and clear restore suggestions',
      (t) async {
    final api = SelectionApi();
    await launch(t, api);
    final semantics = t.ensureSemantics();
    await tap(t, find.text('5'));
    final node = t.getSemantics(find.text('Synthetic choice'));
    t.binding.pipelineOwner.semanticsOwner!
        .performAction(node.id, SemanticsAction.tap);
    await settleLookup(t);
    expect(t.getSize(panel).height, 0);
    await tap(t, find.text('+1'));
    await tap(t, find.text('India'));
    expect(t.getSize(panel).height, greaterThan(0));
    await tap(t, find.text('Synthetic choice'));
    await tap(t, find.byTooltip('Clear'));
    expect(t.getSize(panel).height, greaterThan(0));
    await tap(t, find.text('5'));
    expect(find.text('Synthetic choice'), findsOneWidget);
    semantics.dispose();
  });
  testWidgets('old prefix cannot reopen selection or overwrite newer edit',
      (t) async {
    final api = SelectionApi();
    api.pending['5'] = Completer();
    await launch(t, api);
    await t.tap(find.text('5'));
    await t.pump(const Duration(milliseconds: 300));
    await tap(t, find.text('2'));
    api.pending[chosen] = Completer();
    await t.tap(find.text('Synthetic choice'));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.getSize(panel).height, 0);
    api.pending['5']!.complete(api.response('5', '1'));
    await t.pump();
    expect(t.getSize(panel).height, 0);
    await t.tap(find.byTooltip('BACK'));
    await settleLookup(t);
    api.pending[chosen]!
        .completeError(const ResolverApiException('Old failure'));
    await t.pumpAndSettle();
    expect(find.text('Old failure'), findsNothing);
    expect(find.text('91*529.xy'), findsOneWidget);
    expect(find.text('Synthetic choice'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('selected lookup errors remain visible with collapsed matches',
      (t) async {
    final api = SelectionApi();
    await launch(t, api);
    await tap(t, find.text('5'));
    api.failSelected = true;
    await tap(t, find.text('Synthetic choice'));
    expect(find.text('Synthetic lookup failed ENTER retries.'), findsOneWidget);
    expect(t.getSize(panel).height, 0);
    expect(
        t
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'ENTER'))
            .onPressed,
        isNotNull);
  });
}
