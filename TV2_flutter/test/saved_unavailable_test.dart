import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/main.dart';
import 'package:tv2/saved_listing_ui.dart';
import 'package:tv2/models.dart';
import 'package:tv2/resolver_api.dart';
import 'package:tv2/saved_collections.dart';
import 'home_screen_test.dart' show NamespaceAwareApi, tapVisible;

class UnavailableApi extends NamespaceAwareApi {
  bool offline = false;
  final inputs = <String>[];
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
      {required String input, required String country}) async {
    inputs.add(input);
    if (offline) throw const ResolverApiException('Offline');
    return ResolveResponse(
        status: 'not_found',
        countryContext: country,
        input: input,
        listing: null);
  }
}

void main() {
  testWidgets(
      'already-open collection refreshes after local title invalidation',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    final store = await SavedCollections.open();
    await store.save(
        newFolderName: 'Samples',
        qualifiedIdentity: '*529',
        ownerTitle: 'Old publisher');
    await t.pumpWidget(MaterialApp(home: SavedFoldersScreen(onOpen: (_) {})));
    await t.pumpAndSettle();
    await t.tap(find.text('Samples'));
    await t.pumpAndSettle();
    expect(find.text('Old publisher'), findsOneWidget);
    await store.forgetPublisherTitle('*529');
    await t.pumpAndSettle();
    expect(find.text('Old publisher'), findsNothing);
    expect(find.text('Listing unavailable'), findsOneWidget);
    expect(find.text('*529'), findsOneWidget);
  });
  for (final offline in [false, true]) {
    testWidgets('saved title after qualified ENTER offline=$offline',
        (t) async {
      SharedPreferences.setMockInitialValues({'tv2_selected_nid': '91'});
      final store = await SavedCollections.open();
      await store.save(
          newFolderName: 'My folder',
          qualifiedIdentity: '91*529',
          ownerTitle: 'Old Publisher');
      await store.save(
          newFolderName: 'People',
          qualifiedIdentity: '91*529',
          ownerTitle: 'Old Publisher',
          alias: 'My private alias',
          kind: SavedCollections.addressBookKind);
      await store.save(
          newFolderName: 'Other',
          qualifiedIdentity: '1*529',
          ownerTitle: 'National other');
      final api = UnavailableApi()..offline = offline;
      await t.pumpWidget(TV2App(api: api));
      await t.pumpAndSettle();
      await tapVisible(t, find.byTooltip('HOME'));
      await t.pumpAndSettle();
      await t.tap(find.text('Bookmarks'));
      await t.pumpAndSettle();
      await t.tap(find.text('My folder'));
      await t.pumpAndSettle();
      expect(find.text('Old Publisher'), findsOneWidget);
      await t.tap(find.text('Old Publisher'));
      await t.pumpAndSettle();
      await tapVisible(t, find.byTooltip('ENTER'));
      await t.pumpAndSettle();
      expect(api.inputs.last, '91*529');
      // Recreate the app with the same preferences: local persistence survives.
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      await t.pumpWidget(TV2App(api: api));
      await t.pumpAndSettle();
      await tapVisible(t, find.byTooltip('HOME'));
      await t.pumpAndSettle();
      await t.tap(find.text('Bookmarks'));
      await t.pumpAndSettle();
      await t.tap(find.text('My folder'));
      await t.pumpAndSettle();
      expect(
          find.text('Old Publisher'), offline ? findsOneWidget : findsNothing);
      expect(find.text('91*529'), findsOneWidget);
      if (!offline) expect(find.text('Listing unavailable'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.tap(find.text('Address Book'));
      await t.pumpAndSettle();
      await t.tap(find.text('People'));
      await t.pumpAndSettle();
      expect(find.text('My private alias'), findsOneWidget);
      expect(find.text('91*529'), findsOneWidget);
      final reopened = await SavedCollections.open();
      expect(
          reopened
              .bookmarks()
              .where((x) => x.qualifiedIdentity == '91*529')
              .map((x) => x.ownerTitle),
          everyElement(offline ? 'Old Publisher' : ''));
      expect(
          reopened
              .bookmarks()
              .firstWhere((x) => x.qualifiedIdentity == '1*529')
              .ownerTitle,
          'National other');
      expect(reopened.folders().map((x) => x.label),
          containsAll(['My folder', 'People', 'Other']));
    });
  }
}
