import 'dart:async';

import 'package:flutter/material.dart';

import 'input_rules.dart';
import 'models.dart';
import 'resolver_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    required this.initialCountry,
  });

  final ResolverApi api;
  final String initialCountry;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _debounceDuration = Duration(milliseconds: 250);

  late String countryCode;
  String input = '';
  List<MatchRecord> matches = const [];
  Listing? exactListing;
  String? errorMessage;
  bool loading = false;
  bool hasMore = false;
  Timer? _debounce;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    countryCode = widget.initialCountry;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _setInput(String value) {
    setState(() {
      input = value;
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
      final prefix = await widget.api.prefix(
        input: input,
        country: countryCode,
        limit: 10,
      );
      if (!mounted || generation != _requestGeneration) return;

      Listing? listing;
      if (prefix.matches.any((item) => item.exact)) {
        final resolved = await widget.api.resolve(
          input: input,
          country: countryCode,
        );
        if (!mounted || generation != _requestGeneration) return;
        listing = resolved.listing;
      }

      setState(() {
        matches = prefix.matches;
        hasMore = prefix.hasMore;
        exactListing = listing;
        loading = false;
      });
    } on ResolverApiException catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        loading = false;
        exactListing = null;
        matches = const [];
        hasMore = false;
        errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        loading = false;
        exactListing = null;
        matches = const [];
        hasMore = false;
        errorMessage = 'Unexpected resolver error.';
      });
    }
  }

  Future<void> _editCountry() async {
    final controller = TextEditingController(text: countryCode);
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Country context'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Country Code',
            helperText: 'Temporary TV2 test setting',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (RegExp(r'^\d+$').hasMatch(value)) Navigator.pop(context, value);
            },
            child: const Text('APPLY'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (selected == null || selected == countryCode) return;
    setState(() => countryCode = selected);
    if (input.isNotEmpty) _scheduleLookup();
  }

  void _selectMatch(MatchRecord match) {
    _setInput(match.qualifiedInput);
  }

  void _enter() {
    final listing = exactListing;
    if (listing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This List Number does not exist.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TemplateScreen(listing: listing)),
    );
  }

  void _call() {
    final listing = exactListing;
    final canRequestCall = listing?.hasType('call') ?? false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          canRequestCall
              ? 'CALL capability is configured. Communications service is not connected in this checkpoint.'
              : 'The call cannot be completed.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = exactListing;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _editCountry,
                    icon: const Icon(Icons.public),
                    label: Text('+$countryCode'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: _clear,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('ENTER LIST NUMBER', style: TextStyle(letterSpacing: 2)),
              const SizedBox(height: 10),
              _IdentityDisplay(
                input: input,
                listing: listing,
                loading: loading,
                errorMessage: errorMessage,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _MatchPanel(
                  matches: matches,
                  hasMore: hasMore,
                  onSelect: _selectMatch,
                ),
              ),
              Keypad(
                onKey: _key,
                onCall: _call,
                onHome: _clear,
                onBack: _backspace,
                onEnter: _enter,
                callEnabled: listing?.hasType('call') ?? false,
                enterEnabled: listing != null,
              ),
            ],
          ),
        ),
      ),
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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(input, style: const TextStyle(fontSize: 30, letterSpacing: 3)),
            if (loading) const LinearProgressIndicator(),
            if (listing != null)
              Text(listing!.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (errorMessage != null)
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
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
            child: Text('More matching identities exist. Continue entering the List Number.'),
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
  Widget build(BuildContext context) => Column(
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
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.tonal(
                            onPressed: () => onKey(value),
                            child: Text(value, style: const TextStyle(fontSize: 22)),
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
      );
}

class TemplateScreen extends StatelessWidget {
  const TemplateScreen({super.key, required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final resources = {for (final item in listing.resources) item.key: item};
    return Scaffold(
      appBar: AppBar(title: Text(listing.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(listing.qualifiedIdentity, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('${listing.entityType} • template: ${listing.templateKey}'),
          const SizedBox(height: 20),
          if (listing.resources.isEmpty)
            const Text('This identity has no configured public resources.'),
          for (final button in listing.buttons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.tonal(
                onPressed: resources.containsKey(button.resourceKey)
                    ? () => _resourceAction(context, resources[button.resourceKey]!)
                    : null,
                child: Text(button.label ?? button.resourceKey.toUpperCase()),
              ),
            ),
          const Divider(height: 32),
          for (final resource in listing.resources)
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

  void _resourceAction(BuildContext context, ResourceRecord resource) {
    // Deliberately provider-independent. External URL launching and the
    // communications session service are separate adapters in the next stage.
    final message = resource.uri != null
        ? '${resource.type.toUpperCase()} resource configured: ${resource.uri}'
        : '${resource.type.toUpperCase()} capability is configured.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
