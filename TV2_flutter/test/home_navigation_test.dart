import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/home_navigation_screen.dart';
import 'package:tv2/main.dart';
import 'package:tv2/saved_collections.dart';
import 'package:tv2/saved_listing_ui.dart';

import 'home_screen_test.dart' show NamespaceAwareApi, tapVisible;

void main() {
  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets(
        'HOME and both collections preserve dialer; Clear clears at $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({
        'tv2_selected_nid': '91',
        'tv2_selected_country_iso2': 'IN',
      });
      await tester.pumpWidget(TV2App(api: NamespaceAwareApi()));
      await tester.pumpAndSettle();
      for (final digit in ['5', '2', '9']) {
        await tapVisible(tester, find.text(digit));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byTooltip('HOME'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeNavigationScreen), findsOneWidget);
      expect(find.text('Saved on this device. No account needed.'),
          findsOneWidget);
      for (final destination in ['Bookmarks', 'Address Book']) {
        await tester.scrollUntilVisible(find.text(destination), 180,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(destination));
        await tester.pumpAndSettle();
        expect(find.text(destination).hitTestable(), findsOneWidget);
        await tester.tap(find.text(destination));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<SavedFoldersScreen>(find.byType(SavedFoldersScreen))
                .kind,
            destination == 'Bookmarks'
                ? SavedCollections.bookmarksKind
                : SavedCollections.addressBookKind);
        expect(
            find.textContaining(destination == 'Bookmarks'
                ? 'No saved folders yet'
                : 'Your Address Book is empty'),
            findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(HomeNavigationScreen), findsOneWidget);
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('529'), findsOneWidget);
      expect(find.text('IN  +91'), findsOneWidget);
      expect(find.text('Fixture India'), findsWidgets);
      expect(find.byTooltip('Saved folders'), findsOneWidget);
      expect(find.byTooltip('Address Book'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tv2_selected_nid'), '91');
      expect(prefs.getString('tv2_selected_country_iso2'), 'IN');
      await tapVisible(tester, find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('529'), findsNothing);
      expect(find.text('Fixture India'), findsNothing);
      expect(find.text('IN  +91'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final destination in ['Bookmarks', 'Address Book']) {
    testWidgets('HOME $destination opens only its saved canonical identity',
        (tester) async {
      SharedPreferences.setMockInitialValues({'tv2_selected_nid': '1'});
      final store = await SavedCollections.open();
      await store.save(
          kind: SavedCollections.bookmarksKind,
          newFolderName: 'Family',
          qualifiedIdentity: '91*529',
          ownerTitle: 'Original',
          alias: 'Saved article');
      await store.save(
          kind: SavedCollections.addressBookKind,
          newFolderName: 'Family',
          qualifiedIdentity: '91*529',
          ownerTitle: 'Original',
          alias: 'My contact');
      await tester.pumpWidget(TV2App(api: NamespaceAwareApi()));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byTooltip('HOME'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text(destination));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Family'));
      await tester.pumpAndSettle();
      final alias = destination == 'Bookmarks' ? 'Saved article' : 'My contact';
      expect(
          find.text(
              destination == 'Bookmarks' ? 'My contact' : 'Saved article'),
          findsNothing);
      await tapVisible(tester, find.text(alias));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byType(HomeNavigationScreen), findsNothing);
      expect(find.byType(SavedFoldersScreen), findsNothing);
      expect(find.text('91*529'), findsWidgets);
      expect(find.text('Fixture India'), findsWidgets);
      expect(find.text('+1'), findsOneWidget);
      expect(
          (await SharedPreferences.getInstance()).getString('tv2_selected_nid'),
          '1');
      expect(tester.takeException(), isNull);
    });
  }
}
