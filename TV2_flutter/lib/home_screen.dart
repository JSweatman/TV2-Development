import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'input_rules.dart';
import 'home_navigation_screen.dart';
import 'keypad_surface.dart';
import 'sunset_backdrop.dart';
import 'models.dart';
import 'resolver_api.dart';
import 'public_resource_launcher.dart';
import 'saved_listing_ui.dart';
import 'saved_collections.dart';
import 'listing_video_panel.dart';
import 'landing_theme.dart';
import 'device_handoff.dart';
import 'tutorial_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    this.initialCountry,
    this.tutorial,
    this.tutorialRoutes,
    this.deviceHandoff,
  });

  final ResolverApi api;
  final DeviceHandoff? deviceHandoff;
  final String? initialCountry;
  final TutorialVideo? tutorial;
  final RouteObserver<ModalRoute<dynamic>>? tutorialRoutes;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _debounceDuration = Duration(milliseconds: 250);

  String? countryCode;
  CountryNamespace? selectedCountry;
  List<CountryNamespace> countryOptions = const [];
  bool countryLoading = true;
  String input = '';
  List<MatchRecord> matches = const [];
  Listing? exactListing;
  String? errorMessage;
  bool loading = false;
  // Only the current generation owns ENTER suppression. An edit invalidates
  // that ownership even if its obsolete network request has not completed.
  int? _enterGeneration;
  bool hasMore = false;
  // Selection hides suggestions until input or namespace is edited.
  // The qualified lookup still runs, including normal error reporting.
  bool _matchSelected = false;
  Timer? _debounce;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _initializeCountryContext();
  }

  Future<void> _initializeCountryContext() async {
    // A failed initial fetch must be retryable without reinstalling the app.
    if (!countryLoading) {
      setState(() {
        countryLoading = true;
        errorMessage = null;
      });
    }
    try {
      final countries = await widget.api.countries();
      if (countries.isEmpty) {
        throw const ResolverApiException('No countries are available yet.');
      }
      String? savedNid = widget.initialCountry;
      String? savedIso2;
      if (savedNid == null) {
        final prefs = await SharedPreferences.getInstance();
        savedNid = prefs.getString('tv2_selected_nid');
        savedIso2 = prefs.getString('tv2_selected_country_iso2');
      }

      CountryNamespace? selected;
      if (savedNid != null) {
        for (final item in countries) {
          // +1 is one public dialing namespace, not a country label.
          // A legacy US/CA/JM selection must not affect +1 restoration.
          // Other codes retain their existing country-specific selection.
          if (item.nid == savedNid &&
              (savedNid == '1' ||
                  savedIso2 == null ||
                  item.iso2 == savedIso2)) {
            selected = item;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        countryOptions = countries;
        selectedCountry = selected;
        countryCode = selected?.nid;
        countryLoading = false;
      });

      if (selected == null && widget.initialCountry == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _editCountry(requireSelection: true);
        });
      }
    } on ResolverApiException catch (error) {
      if (!mounted) return;
      setState(() {
        countryLoading = false;
        errorMessage = '${error.message} Tap Retry Country to try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        countryLoading = false;
        errorMessage =
            'Unable to load country settings. Tap Retry Country to try again.';
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _setInput(String value, {bool selectedMatch = false}) {
    setState(() {
      input = value;
      _matchSelected = selectedMatch;
      loading = false;
      exactListing = null;
      matches = const [];
      hasMore = false;
      errorMessage = null;
    });
    _scheduleLookup();
  }

  void _key(String value) {
    if (!InputRules.canAppend(input, value)) {
      setState(() => errorMessage = 'That key is not valid at this position.');
      return;
    }
    _setInput('$input$value');
  }

  void _clear() {
    _debounce?.cancel();
    _requestGeneration++;
    setState(() {
      input = '';
      _matchSelected = false;
      matches = const [];
      exactListing = null;
      errorMessage = null;
      loading = false;
      hasMore = false;
    });
  }

  void _backspace() {
    if (input.isEmpty) return;
    _setInput(input.substring(0, input.length - 1));
  }

  void _scheduleLookup() {
    _debounce?.cancel();
    final generation = ++_requestGeneration;
    setState(() => loading = input.isNotEmpty);
    if (input.isEmpty) return;
    _debounce = Timer(_debounceDuration, () => _lookup(generation));
  }

  Future<void> _lookup(int generation) async {
    if (!mounted || generation != _requestGeneration) return;
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final activeCountry = countryCode;
      if (activeCountry == null) {
        throw const ResolverApiException(
          'Select a country before resolving a local List Number.',
        );
      }
      final prefix = await widget.api.prefix(
        input: input,
        country: activeCountry,
        limit: 10,
      );
      if (!mounted || generation != _requestGeneration) return;

      Listing? listing;
      if (prefix.matches.any((item) => item.exact)) {
        final resolved = await widget.api.resolve(
          input: input,
          country: activeCountry,
        );
        if (!mounted || generation != _requestGeneration) return;
        listing = resolved.listing;
      }

      setState(() {
        matches = _matchSelected ? const [] : prefix.matches;
        hasMore = !_matchSelected && prefix.hasMore;
        exactListing = listing;
        loading = false;
        errorMessage = listing == null && prefix.matches.isEmpty
            ? 'No exact match. ENTER retries.'
            : null;
      });
    } on ResolverApiException catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        loading = false;
        exactListing = null;
        matches = const [];
        hasMore = false;
        errorMessage = '${error.message} ENTER retries.';
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        loading = false;
        exactListing = null;
        matches = const [];
        hasMore = false;
        errorMessage = 'Unexpected resolver error. ENTER retries.';
      });
    }
  }

  // Shared +1 has one visible dialing choice, regardless of how many
  // countries the API returns with that same numeric calling code.
  List<CountryNamespace> get _visibleNamespaceOptions {
    final visible = <CountryNamespace>[];
    var hasPlusOne = false;
    for (final country in countryOptions) {
      if (country.nid == '1') {
        if (hasPlusOne) continue;
        hasPlusOne = true;
      }
      visible.add(country);
    }
    return visible;
  }

  Future<void> _editCountry({bool requireSelection = false}) async {
    if (countryOptions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Country settings are unavailable.')),
      );
      return;
    }

    final visibleOptions = _visibleNamespaceOptions;
    final selected = await showModalBottomSheet<CountryNamespace>(
      context: context,
      isScrollControlled: true,
      isDismissible: !requireSelection,
      enableDrag: !requireSelection,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Text(
                  'Select Country / Namespace',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'This selection becomes your default List Number namespace until you change it.',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: visibleOptions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = visibleOptions[index];
                    final isPlusOne = item.nid == '1';
                    return ListTile(
                      leading: const Icon(Icons.public),
                      title: Text(isPlusOne ? '+1' : item.countryName),
                      subtitle: isPlusOne
                          ? const Text('Shared calling-code namespace')
                          : Text(item.iso2),
                      trailing: isPlusOne ? null : Text('+${item.nid}'),
                      selected: isPlusOne
                          ? selectedCountry?.nid == '1'
                          : selectedCountry?.iso2 == item.iso2,
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected == null) return;
    // Invalidate pending navigation before asynchronous preference storage.
    _requestGeneration++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tv2_selected_nid', selected.nid);
    if (selected.nid == '1') {
      // Do not persist an arbitrary country identity for shared +1.
      await prefs.remove('tv2_selected_country_iso2');
    } else {
      await prefs.setString('tv2_selected_country_iso2', selected.iso2);
    }

    if (!mounted) return;
    setState(() {
      selectedCountry = selected;
      countryCode = selected.nid;
      errorMessage = null;
    });
    _setInput(input);
  }

  void _selectMatch(MatchRecord match) {
    _setInput(match.qualifiedInput, selectedMatch: true);
  }

  bool get _canEnter =>
      countryCode != null &&
      input.isNotEmpty &&
      _enterGeneration != _requestGeneration;

  Future<void> _enter() async {
    if (!_canEnter) return;
    _debounce?.cancel();
    final generation = ++_requestGeneration;
    final requestedInput = input;
    final requestedCountry = countryCode!;
    setState(() {
      _enterGeneration = generation;
      loading = true;
      exactListing = null;
      errorMessage = null;
    });
    try {
      // ENTER verifies availability now; preview results are not authorization
      // to open a listing that may since have changed or expired.
      final response = await widget.api.resolve(
        input: requestedInput,
        country: requestedCountry,
      );
      if (!mounted || generation != _requestGeneration) return;
      final listing = response.status == 'resolved' ? response.listing : null;
      setState(() {
        loading = false;
        exactListing = listing;
        if (listing == null) {
          matches = const [];
          hasMore = false;
          errorMessage = 'No exact match. ENTER retries.';
        }
      });
      if (listing != null && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TemplateScreen(listing: listing,
              deviceHandoff: widget.deviceHandoff, routeObserver: widget.tutorialRoutes)),
        );
      }
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        loading = false;
        exactListing = null;
        matches = const [];
        hasMore = false;
        errorMessage = error is ResolverApiException
            ? '${error.message} ENTER retries.'
            : 'Unable to check this listing. ENTER retries.';
      });
    } finally {
      if (mounted && _enterGeneration == generation) {
        setState(() => _enterGeneration = null);
      }
    }

  }

  Future<void> _openHome() async {
    final selected = await Navigator.of(context).push<SavedBookmark>(
      MaterialPageRoute(builder: (_) => const HomeNavigationScreen()),
    );
    // Returning without choosing a saved entry leaves all dialer state intact.
    if (selected != null && mounted) _setInput(selected.qualifiedIdentity);
  }

  void _openSavedFolders({String kind = SavedCollections.bookmarksKind}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SavedFoldersScreen(
          kind: kind,
          onOpen: (saved) {
            Navigator.of(context).pop();
            // The canonical qualified identity survives changes to the
            // currently selected default country. Normal resolver rules
            // decide whether this listing is still available.
            _setInput(saved.qualifiedIdentity);
          },
        ),
      ),
    );
  }

  void _call() {
    final resources = exactListing?.resources.where((r) => r.type == 'call');
    final resource =
        resources == null || resources.isEmpty ? null : resources.first;
    (widget.deviceHandoff ?? DeviceHandoff()).request(context, resource);
  }

  @override
  Widget build(BuildContext context) {
    final listing = exactListing;
    return Scaffold(
      body: SunsetBackdrop(
          child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              // Content grows naturally for large text and long errors.
              child: Column(
                children: [
                  Material(
                    color: const Color(0xF2FFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: countryLoading
                                ? null
                                : () {
                                    if (countryOptions.isEmpty) {
                                      _initializeCountryContext();
                                    } else {
                                      _editCountry();
                                    }
                                  },
                            icon: const Icon(Icons.public),
                            label: Text(
                              countryLoading
                                  ? 'Loading countries…'
                                  : countryOptions.isEmpty
                                      ? 'Retry Country'
                                      : selectedCountry == null
                                          ? 'Select Country'
                                          : selectedCountry!.nid == '1'
                                              ? '+1'
                                              : '${selectedCountry!.iso2}  +${selectedCountry!.nid}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Saved folders',
                          onPressed: _openSavedFolders,
                          icon: const Icon(Icons.bookmarks_outlined),
                        ),
                        IconButton(
                          tooltip: 'Address Book',
                          onPressed: () => _openSavedFolders(
                            kind: SavedCollections.addressBookKind,
                          ),
                          icon: const Icon(Icons.contact_page_outlined),
                        ),
                        IconButton(
                          tooltip: 'Clear',
                          onPressed: _clear,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                  if (countryLoading)
                    ColoredBox(
                      color: const Color(0xF2FFFFFF),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Connecting to country directory… '
                                'The test server may take longer to start after inactivity.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  _IdentityDisplay(
                    input: input,
                    listing: listing,
                    loading: loading,
                    errorMessage: errorMessage,
                  ),
                  const SizedBox(height: 8),
                  // Keep the demo visible in the scrollable content even when
                  // the viewport cannot fit the panel and keypad together.
                  TutorialPanel(
                    tutorial: widget.tutorial,
                    routeObserver: widget.tutorialRoutes,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    key: const Key('tv2-home-match-viewport'),
                    // Matches scroll independently; long result sets must not
                    // push the keypad arbitrarily far down the home screen.
                    // Compact portrait results without shrinking keys or media.
                    // Keep a complete two-line row; extra matches scroll inside.
                    height: _matchSelected
                        ? 0
                        : MediaQuery.sizeOf(context).width < 600 &&
                                MediaQuery.orientationOf(context) ==
                                    Orientation.portrait
                            ? ((constraints.maxHeight * 0.15)
                                        .clamp(72.0, 160.0) /
                                    2)
                                .clamp(
                                    matches.isEmpty
                                        ? 0.0
                                        : 64.0 *
                                            MediaQuery.textScalerOf(context)
                                                .scale(14) /
                                            14,
                                    double.infinity)
                            : (constraints.maxHeight * 0.15).clamp(72.0, 160.0),
                    child: Material(
                      color: matches.isEmpty
                          ? Colors.transparent
                          : const Color(0xF2FFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: _MatchPanel(
                        matches: matches,
                        hasMore: hasMore,
                        onSelect: _selectMatch,
                      ),
                    ),
                  ),
                  Keypad(
                    onKey: _key,
                    onCall: _call,
                    onHome: _openHome,
                    onBack: _backspace,
                    onEnter: _enter,
                    callEnabled: listing?.hasType('call') ?? false,
                    enterEnabled: _canEnter,
                  ),
                ],
              ),
            ),
          ),
        ),
      )),
    );
  }
}

class _IdentityDisplay extends StatelessWidget {
  const _IdentityDisplay({
    required this.input,
    required this.listing,
    required this.loading,
    required this.errorMessage,
  });

  final String input;
  final Listing? listing;
  final bool loading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 84),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xE6202333),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x667F89AA)),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ENTER LIST NUMBER',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                label: 'List Number',
                child: Text(
                  input,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 30, letterSpacing: 3),
                ),
              ),
              if (loading) const LinearProgressIndicator(),
              if (listing != null)
                Text(
                  listing!.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              if (errorMessage != null)
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFFB4AB)),
                ),
            ],
          ),
        ),
      );
}

class _MatchPanel extends StatelessWidget {
  const _MatchPanel({
    required this.matches,
    required this.hasMore,
    required this.onSelect,
  });

  final List<MatchRecord> matches;
  final bool hasMore;
  final ValueChanged<MatchRecord> onSelect;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      itemCount: matches.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == matches.length) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'More matching identities exist. Continue entering the List Number.',
            ),
          );
        }
        final match = matches[index];
        return ListTile(
          dense: true,
          title: Text(match.displayName),
          subtitle: Text(match.qualifiedInput),
          trailing: match.exact ? const Chip(label: Text('EXACT')) : null,
          onTap: () => onSelect(match),
        );
      },
    );
  }
}

class Keypad extends StatelessWidget {
  const Keypad({
    super.key,
    required this.onKey,
    required this.onCall,
    required this.onHome,
    required this.onBack,
    required this.onEnter,
    required this.callEnabled,
    required this.enterEnabled,
  });

  final ValueChanged<String> onKey;
  final VoidCallback onCall;
  final VoidCallback onHome;
  final VoidCallback onBack;
  final VoidCallback onEnter;
  final bool callEnabled;
  final bool enterEnabled;

  static const layout = [
    ['1', '2', '3', '@'],
    ['4', '5', '6', '/'],
    ['7', '8', '9', '-'],
    ['*', '0', '#', '.'],
  ];

  @override
  Widget build(BuildContext context) => KeypadSurface(
        child: Column(
          children: [
            for (final row in layout)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    for (final value in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: KeypadTile(
                            value: value,
                            child: FilledButton.tonal(
                              key: value == '0'
                                  ? const Key('tv2-zero-operator-key')
                                  : null,
                              onPressed: () => onKey(value),
                              // OPER is a visual legend only. Tapping this
                              // button still sends numeric zero.
                              child: value == '0'
                                  ? const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '0',
                                            style: TextStyle(
                                              fontSize: 22,
                                              height: 1,
                                            ),
                                          ),
                                          Text(
                                            'OPER',
                                            style: TextStyle(
                                              fontSize: 10,
                                              height: 1.1,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Text(
                                      value,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  tooltip: 'CALL',
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF216C2E),
                    backgroundColor: const Color(0xFFE1F3E3),
                  ),
                  onPressed: callEnabled ? onCall : null,
                  icon: const Icon(Icons.call),
                ),
                IconButton(
                  tooltip: 'HOME',
                  onPressed: onHome,
                  icon: const Icon(Icons.home_outlined),
                ),
                IconButton(
                  tooltip: 'BACK',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                IconButton(
                  tooltip: 'ENTER',
                  onPressed: enterEnabled ? onEnter : null,
                  icon: const Icon(Icons.keyboard_return),
                ),
              ],
            ),
          ],
        ),
      );
}

class TemplateScreen extends StatefulWidget {
  TemplateScreen({
    super.key,
    required this.listing,
    this.deviceHandoff,
    this.routeObserver,
  });
  final DeviceHandoff? deviceHandoff;
  final RouteObserver<ModalRoute<dynamic>>? routeObserver;
  final Listing listing;

  @override
  State<TemplateScreen> createState() => _TemplateScreenState();
}

class _TemplateScreenState extends State<TemplateScreen> {
  final _videoKey = GlobalKey<ListingVideoPanelState>();
  bool _videoExpanded = false;
  Listing get listing => widget.listing;
  DeviceHandoff? get deviceHandoff => widget.deviceHandoff;
  RouteObserver<ModalRoute<dynamic>>? get routeObserver => widget.routeObserver;

  void _expandVideo(bool expanded) {
    if (mounted && _videoExpanded != expanded) {
      setState(() => _videoExpanded = expanded);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_videoExpanded) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _expandVideo(false);
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(child: _media()),
        ),
      );
    }
    final spec = LandingThemeSpec.fromListing(listing);
    if (spec != null) {
      return Theme(
          data: spec.theme(),
          child: Builder(builder: (context) => _themed(context, spec)));
    }
    return _normal(context);
  }

  Widget _media() {
    if (listingVideoUri(listing) == null && listing.hasType('provider_embed')) {
      final configured = listing.resources
          .where((r) => r.type == 'provider_embed')
          .any((r) => ProviderVideoReference.parse(r) != null);
      return Card(
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(configured
                  ? 'Provider video is not supported in this build.'
                  : 'Provider video configuration is unavailable.')));
    }
    return ListingVideoPanel(key: _videoKey, listing: listing, routeObserver: routeObserver,
      expanded: _videoExpanded, onExpansionChanged: _expandVideo);
  }

  bool _configured(ResourceRecord? resource) {
    if (resource == null) return false;
    if (resource.type == 'call' || resource.type == 'text')
      return deviceDestination(resource) != null;
    if (resource.type == 'provider_embed' ||
        resource.type == 'landing_theme' ||
        resource.type == 'listing_video') return false;
    return safePublicResourceUri(resource.uri) != null;
  }

  Widget _themed(BuildContext context, LandingThemeSpec spec) {
    final slots = {for (final b in listing.buttons) b.slot: b};
    return Scaffold(
      appBar: AppBar(title: const Text('List Number'), actions: [
        SaveListingAction(listing: listing),
        SaveListingAction(
            listing: listing, kind: SavedCollections.addressBookKind)
      ]),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(padding: const EdgeInsets.all(20), children: [
                if (spec.hero != null) ...[
                  LandingHero(spec: spec),
                  const SizedBox(height: 24)
                ],
                Text(listing.displayName,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(listing.qualifiedIdentity,
                    style: TextStyle(color: spec.accent, fontSize: 16)),
                const SizedBox(height: 24),
                if (listingVideoUri(listing) != null || listing.hasType('provider_embed')) ...[
                  _media(),
                  const SizedBox(height: 24),
                ],
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 300 &&
                          MediaQuery.textScalerOf(context).scale(16) <= 24
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(spacing: 12, runSpacing: 12, children: [
                    for (var slot = 1; slot <= 6; slot++)
                      if (_configured(listing.resource(slots[slot]?.resourceKey ?? '')))
                      SizedBox(
                          width: width,
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 56),
                              child: FilledButton.tonal(
                                key: ValueKey('landing-action-$slot'),
                                style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 18),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16))),
                                onPressed: _configured(listing.resource(
                                        slots[slot]?.resourceKey ?? ''))
                                    ? () => _resourceAction(
                                        context,
                                        listing.resource(
                                            slots[slot]!.resourceKey)!)
                                    : null,
                                child: Text(
                                    slots[slot]?.label ??
                                        slots[slot]
                                            ?.resourceKey
                                            .toUpperCase() ??
                                        'Not configured',
                                    textAlign: TextAlign.center),
                              ))),
                  ]);
                }),
                const SizedBox(height: 20),
              ]))),
    );
  }

  Widget _normal(BuildContext context) {
    final resources = {for (final item in listing.resources) item.key: item};
    return Scaffold(
      appBar: AppBar(
        title: Text(listing.displayName),
        actions: [
          SaveListingAction(listing: listing),
          SaveListingAction(
            listing: listing,
            kind: SavedCollections.addressBookKind,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            listing.qualifiedIdentity,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text('${listing.entityType} • template: ${listing.templateKey}'),
          const SizedBox(height: 16),
          _media(),
          const SizedBox(height: 16),
          if (listing.resources.isEmpty)
            const Text('This identity has no configured public resources.'),
          for (final button in listing.buttons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.tonal(
                onPressed: resources.containsKey(button.resourceKey)
                    ? () => _resourceAction(
                          context,
                          resources[button.resourceKey]!,
                        )
                    : null,
                child: Text(button.label ?? button.resourceKey.toUpperCase()),
              ),
            ),
          const Divider(height: 32),
          for (final resource in listing.resources.where((r) => !{
                'listing_video',
                'landing_theme',
                'provider_embed'
              }.contains(r.type)))

            ListTile(
              title: Text(resource.type),
              subtitle: resource.uri == null ? null : Text(resource.uri!),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _resourceAction(context, resource),
            ),
        ],
      ),
    );
  }

  Future<void> _resourceAction(
    BuildContext context,
    ResourceRecord resource,
  ) async {
    if (resource.type == 'provider_embed' || resource.type == 'landing_theme') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This resource is unavailable in this build.')));
      return;
    }
    if (resource.type == 'call' || resource.type == 'text') {
      await (deviceHandoff ?? DeviceHandoff()).request(context, resource);
      return;
    }
    if (resource.type == 'listing_video') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use the listing video controls above.')),
      );
      return;
    }
    if (resource.uri != null) {
      if (safePublicResourceUri(resource.uri) != null) {
        _videoKey.currentState?.pauseForExternalHandoff();
      }
      // Do not await the pause: launch must retain the user's browser gesture.
      final opened = await PublicResourceLauncher().open(resource.uri);
      if (!context.mounted) return;
      if (!opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open public resource securely.'),
          ),
        );
      }
      return;
    }
    // Deliberately provider-independent. External URL launching and the
    // communications session service are separate adapters in the next stage.
    final message = resource.uri != null
        ? '${resource.type.toUpperCase()} resource configured: ${resource.uri}'
        : '${resource.type.toUpperCase()} capability is configured.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
