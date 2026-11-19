import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/main.dart';
import 'package:tv2/models.dart';
import 'package:tv2/tutorial_panel.dart';
import 'home_screen_test.dart' show FakeApi, NamespaceAwareApi;

void main() {
  testWidgets('portrait empty gap halves without shrinking video or keys',
      (t) async {
    t.view.physicalSize = const Size(360, 740);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'tv2_selected_nid': '1'});
    await t.pumpWidget(TV2App(api: FakeApi()));
    await t.pumpAndSettle();
    final video = t.getRect(find.byType(TutorialPanel));
    final key =
        find.ancestor(of: find.text('1'), matching: find.byType(FilledButton));
    // Baseline: 116px (108px reserved results + 8px spacing).
    expect(t.getTopLeft(key).dy - video.bottom, closeTo(62, 0.1));
    expect(video.height, 140);
    expect(t.getSize(key).height, 64);
    expect(t.getSize(key).width, greaterThanOrEqualTo(48));
    expect(t.getRect(find.byTooltip('ENTER')).bottom, lessThanOrEqualTo(740));
    expect(t.getTopLeft(find.byTooltip('ENTER')).dx,
        greaterThan(t.getTopLeft(find.byTooltip('BACK')).dx));
    // A complete suggestion row fits in the compact results viewport.
    await t.tap(find.text('5'));
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(
        t.getSize(find.byKey(const Key('tv2-home-match-viewport'))).height, 64);
    expect(t.getRect(find.byTooltip('ENTER')).bottom, lessThanOrEqualTo(740));
    expect(t.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'multiple matches scroll, select and ENTER at text scale $scale',
        (t) async {
      t.view.physicalSize = const Size(360, 740);
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({'tv2_selected_nid': '1'});
      await t.pumpWidget(TV2App(api: MultipleApi()));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('5'));
      await t.tap(find.text('5'));
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      final panel = find.byKey(const Key('tv2-home-match-viewport'));
      expect(t.getSize(panel).height, 64 * scale);
      final list =
          find.descendant(of: panel, matching: find.byType(Scrollable));
      await t.scrollUntilVisible(find.text('Fixture choice 9'), 80,
          scrollable: list);
      await t.tap(find.text('Fixture choice 9'));
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byTooltip('ENTER'));
      await t.tap(find.byTooltip('ENTER'));
      await t.pumpAndSettle();
      expect(find.byTooltip('Save listing'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('1*529'), findsWidgets);
      expect(t.takeException(), isNull);
    });
  }
  for (final size in [const Size(844, 390), const Size(1280, 800)]) {
    testWidgets('empty gap unchanged outside portrait phones $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'tv2_selected_nid': '1'});
      await t.pumpWidget(TV2App(api: FakeApi()));
      await t.pumpAndSettle();
      expect(t.getSize(find.byKey(const Key('tv2-home-match-viewport'))).height,
          size.width == 844 ? 72 : 117);
      expect(t.takeException(), isNull);
    });
  }
}

class MultipleApi extends NamespaceAwareApi {
  @override
  Future<PrefixResponse> prefix(
          {required String input,
          required String country,
          int limit = 10}) async =>
      PrefixResponse(
        countryContext: country,
        input: input,
        hasMore: false,
        matches: List.generate(
            10,
            (i) => MatchRecord(
                countryCode: country,
                listNumber: i == 9 ? '529' : '50$i',
                tldx: null,
                displayName: 'Fixture choice $i',
                entityType: 'person',
                qualifiedInput: '$country*${i == 9 ? '529' : '50$i'}',
                exact: i == 9 && input == '$country*529')),
      );
}
