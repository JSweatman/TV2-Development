import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/home_screen.dart';
import 'package:tv2/models.dart';
import 'package:tv2/resolver_api.dart';
import 'home_screen_test.dart' show NamespaceAwareApi, tapVisible;

class FreshnessApi extends NamespaceAwareApi {
  bool available = true;
  bool fail = false;
  String? refreshedName;
  Completer<ResolveResponse>? pending;
  Completer<PrefixResponse>? pendingPrefix;
  final sequence = <String>[];
  final requests = <String>[];

  @override
  Future<PrefixResponse> prefix(
      {required String input, required String country, int limit = 10}) async {
    sequence.add('prefix:$country:$input');
    if (pendingPrefix != null) return pendingPrefix!.future;
    if (!available)
      return PrefixResponse(
          countryContext: country,
          input: input,
          matches: const [],
          hasMore: false);
    return super.prefix(input: input, country: country, limit: limit);
  }

  Future<ResolveResponse> answer(String input, String country) async {
    if (!available)
      return ResolveResponse(
          status: 'not_found',
          countryContext: country,
          input: input,
          listing: null);
    final result = await super.resolve(input: input, country: country);
    final old = result.listing;
    return ResolveResponse(
        status: result.status,
        countryContext: country,
        input: input,
        listing: old == null
            ? null
            : Listing(
                countryCode: old.countryCode,
                listNumber: old.listNumber,
                tldx: old.tldx,
                displayName: refreshedName ?? old.displayName,
                entityType: old.entityType,
                templateKey: old.templateKey,
                resources: old.resources,
                buttons: old.buttons));
  }

  @override
  Future<ResolveResponse> resolve(
      {required String input, required String country}) async {
    requests.add('$country:$input');
    sequence.add('resolve:$country:$input');
    if (pending != null) return pending!.future;
    if (fail) throw const ResolverApiException('Temporary fixture error.');
    return answer(input, country);
  }
}

void main() {
  late FreshnessApi api;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = FreshnessApi();
  });
  Future<void> mount(WidgetTester t,
      {bool settle = true, bool startPreview = true}) async {
    await t.pumpWidget(
        MaterialApp(home: HomeScreen(api: api, initialCountry: '1')));
    await t.pumpAndSettle();
    for (final key in ['5', '2', '9']) {
      await tapVisible(t, find.widgetWithText(FilledButton, key));
    }
    await t.pump(); // Render the entered number without advancing debounce time.
    if (startPreview) await t.pump(const Duration(milliseconds: 300));
    if (settle) await t.pumpAndSettle();
  }

  Future<void> enter(WidgetTester t) async {
    await tapVisible(t, find.byTooltip('ENTER'));
    await t.pumpAndSettle();
  }

  void noListing() => expect(find.byType(TemplateScreen), findsNothing);

  testWidgets('unchanged no-match becomes available through ENTER retry',
      (t) async {
    api.available = false;
    await mount(t);
    expect(find.text('No exact match. ENTER retries.'), findsOneWidget);
    expect(api.requests, isEmpty);
    api.available = true;
    await enter(t);
    expect(find.byType(TemplateScreen), findsOneWidget);
    expect(api.requests, ['1:529']);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('529'), findsOneWidget);
  });

  testWidgets(
      'ENTER refresh rejects expired result and permits unchanged retry',
      (t) async {
    await mount(t);
    expect(api.requests, ['1:529']);
    api.available = false;
    await enter(t);
    noListing();
    expect(api.requests.length, 2);
    expect(find.text('No exact match. ENTER retries.'), findsOneWidget);
    api.available = true;
    await enter(t);
    expect(find.byType(TemplateScreen), findsOneWidget);
    expect(api.requests.length, 3);
  });

  testWidgets(
      'ordinary ENTER verifies again and transient error remains retryable',
      (t) async {
    await mount(t);
    api.fail = true;
    await enter(t);
    noListing();
    expect(find.textContaining('ENTER retries.'), findsOneWidget);
    api.fail = false;
    await enter(t);
    expect(find.byType(TemplateScreen), findsOneWidget);
    expect(api.requests.length, 3);
  });

  testWidgets(
      'repeat ENTER cannot duplicate in-flight request; edit prevents stale navigation',
      (t) async {
    await mount(t);
    final pending = Completer<ResolveResponse>();
    api.pending = pending;
    await t.ensureVisible(find.byTooltip('ENTER'));
    await t.tap(find.byTooltip('ENTER'));
    await t.pump();
    await t.tap(find.byTooltip('ENTER'));
    await t.pump();
    expect(api.requests.length, 2);
    await t.tap(find.byTooltip('BACK'));
    await t.pump();
    api.pending = null;
    pending.complete(await api.answer('529', '1'));
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    noListing();
    expect(find.text('52'), findsOneWidget);
  });

  testWidgets('country change invalidates pending ENTER and keeps input',
      (t) async {
    await mount(t);
    final pending = Completer<ResolveResponse>();
    api.pending = pending;
    await t.ensureVisible(find.byTooltip('ENTER'));
    await t.tap(find.byTooltip('ENTER'));
    await t.pump();
    await t.ensureVisible(find.text('+1'));
    await t.tap(find.text('+1'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 350));
    await t.ensureVisible(find.text('India'));
    await t.tap(find.text('India'));
    await t.pump();
    api.pending = null;
    pending.complete(await api.answer('529', '1'));
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    noListing();
    expect(find.text('529'), findsOneWidget);
    await enter(t);
    expect(find.byType(TemplateScreen), findsOneWidget);
    expect(api.requests.last, '91:529');
  });

  testWidgets(
      'suggestion selection preserves qualified input without navigation',
      (t) async {
    await mount(t);
    await tapVisible(t, find.text('Fixture Alpha').last);
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    noListing();
    expect(find.text('1*529'), findsWidgets);
    await enter(t);
    expect(api.requests.last, '1:1*529');
    expect(find.byType(TemplateScreen), findsOneWidget);
  });
  testWidgets('ordinary open uses refreshed content rather than cached preview',
      (t) async {
    await mount(t);
    api.refreshedName = 'Updated synthetic listing';
    await enter(t);
    expect(find.byType(TemplateScreen), findsOneWidget);
    expect(find.text('Updated synthetic listing'), findsWidgets);
    expect(api.requests.length, 2);
  });

  testWidgets('initial transient preview failure allows unchanged ENTER retry',
      (t) async {
    api.fail = true;
    await mount(t);
    noListing();
    expect(find.textContaining('ENTER retries.'), findsOneWidget);
    api.fail = false;
    await enter(t);
    expect(find.byType(TemplateScreen), findsOneWidget);
    expect(api.requests.length, 2);
  });
  testWidgets(
      'ENTER supersedes held prefix and late prefix cannot resolve or navigate',
      (t) async {
    final preview = Completer<PrefixResponse>();
    api.pendingPrefix = preview;
    await mount(t, settle: false);
    expect(api.sequence, ['prefix:1:529']);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final explicit = Completer<ResolveResponse>();
    api.pending = explicit;
    await tapVisible(t, find.byTooltip('ENTER'));
    await t.pump();
    await tapVisible(t, find.byTooltip('ENTER'));
    await t.pump();
    expect(api.sequence, ['prefix:1:529', 'resolve:1:529']);
    explicit.complete(await api.answer('529', '1'));
    await t.pumpAndSettle();
    expect(find.byType(TemplateScreen), findsOneWidget);
    expect(
        t
            .widget<TemplateScreen>(find.byType(TemplateScreen))
            .listing
            .qualifiedIdentity,
        '1*529');
    await t.pageBack();
    await t.pumpAndSettle();
    // A late exact prefix must neither overwrite the display nor start another
    // downstream resolve after the explicit submission superseded its generation.
    preview.complete(PrefixResponse(
        countryContext: '1',
        input: '529',
        hasMore: true,
        matches: const [
          MatchRecord(
              countryCode: '1',
              listNumber: '529',
              tldx: null,
              displayName: 'Stale preview',
              entityType: 'test',
              qualifiedInput: '1*529',
              exact: true)
        ]));
    await t.pumpAndSettle();
    noListing();
    expect(find.text('529'), findsOneWidget);
    expect(find.text('Stale preview'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(api.sequence, ['prefix:1:529', 'resolve:1:529']);
  });

  testWidgets(
      'ENTER supersedes held preview exact response without stale overwrite',
      (t) async {
    final preview = Completer<ResolveResponse>();
    api.pending = preview;
    await mount(t, settle: false);
    expect(api.sequence, ['prefix:1:529', 'resolve:1:529']);
    api.pending = null;
    api.refreshedName = 'Fresh explicit result';
    await enter(t);
    expect(find.byType(TemplateScreen), findsOneWidget);
    expect(find.text('Fresh explicit result'), findsWidgets);
    api.refreshedName = 'Stale exact preview';
    preview.complete(await api.answer('529', '1'));
    await t.pumpAndSettle();
    expect(find.text('Stale exact preview'), findsNothing);
    await t.pageBack();
    await t.pumpAndSettle();
    noListing();
    expect(find.text('Fresh explicit result'), findsOneWidget);
    expect(api.sequence, ['prefix:1:529', 'resolve:1:529', 'resolve:1:529']);
  });
  testWidgets('immediate ENTER cancels debounce without a preview request',
      (t) async {
    await mount(t, settle: false, startPreview: false);
    expect(api.sequence, isEmpty);
    await enter(t);
    expect(find.byType(TemplateScreen), findsOneWidget);
    await t.pump(const Duration(milliseconds: 500));
    expect(api.sequence, ['resolve:1:529']);
  });
}
