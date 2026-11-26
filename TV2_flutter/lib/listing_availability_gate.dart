import 'package:flutter/material.dart';
import 'models.dart';
import 'resolver_api.dart';

typedef AuthorizeListingAction = Future<void> Function(VoidCallback action);

/// One exact request per deliberate action or reported resume. No polling.
class ListingAvailabilityGate extends StatefulWidget {
  const ListingAvailabilityGate(
      {super.key,
      required this.api,
      required this.listing,
      required this.builder});
  final ResolverApi api;
  final Listing listing;
  final Widget Function(Listing, AuthorizeListingAction) builder;
  @override
  State<ListingAvailabilityGate> createState() =>
      _ListingAvailabilityGateState();
}

class _ListingAvailabilityGateState extends State<ListingAvailabilityGate>
    with WidgetsBindingObserver {
  late Listing current = widget.listing;
  String status = 'ready';
  int generation = 0;
  BuildContext? prompt;
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void invalidate() {
    generation++;
    final dialog = prompt;
    prompt = null;
    if (dialog != null && dialog.mounted) Navigator.of(dialog).pop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      foreground = false;
      invalidate();
      if (mounted) setState(() => status = 'checking');
    } else if (!foreground) {
      foreground = true;
      check();
    }
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> check([VoidCallback? action]) async {
    final ticket = ++generation;
    setState(() => status = 'checking');
    final original = widget.listing;
    final input = original.qualifiedIdentity;
    try {
      final result = await widget.api
          .resolve(input: input, country: original.countryCode ?? '');
      if (!mounted || !foreground || ticket != generation) return;
      final fresh = result.listing;
      if (result.status == 'not_found') {
        setState(() => status = 'unavailable');
        return;
      }
      if (result.status != 'resolved' ||
          fresh == null ||
          fresh.countryCode != original.countryCode ||
          fresh.listNumber != original.listNumber ||
          fresh.tldx != original.tldx) {
        setState(() => status = 'error');
        return;
      }
      setState(() {
        current = fresh;
        status = 'ready';
      });
      if (action == null) return;
      // A second explicit tap preserves browser activation after asynchronous verification.
      await showDialog<void>(
          context: context,
          builder: (dialog) {
            prompt = dialog;
            return AlertDialog(
                title: const Text('Listing available'),
                content: const Text('Continue with the current listing?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        Navigator.pop(dialog);
                        prompt = null;
                        if (mounted && foreground && ticket == generation)
                          action();
                      },
                      child: const Text('Continue')),
                ]);
          });
      prompt = null;
    } catch (_) {
      if (mounted && ticket == generation) setState(() => status = 'error');
    }
  }

  Future<void> authorize(VoidCallback action) async {
    if (status != 'ready' || prompt != null || !foreground) return;
    await check(action);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = status != 'ready';
    return Stack(children: [
      if (status == 'ready' || status == 'checking')
        Offstage(offstage: blocked, child: widget.builder(current, authorize)),
      if (blocked)
        Scaffold(
            appBar: AppBar(title: const Text('Listing availability')),
            body: Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(status == 'checking'
                          ? 'Checking listing availability…'
                          : status == 'unavailable'
                              ? 'This listing is no longer available.'
                              : 'Unable to verify this listing. Reconnect and retry.'),
                      if (status == 'checking')
                        const CircularProgressIndicator(),
                      if (status != 'checking')
                        FilledButton(
                            onPressed: () => check(),
                            child: const Text('Retry availability')),
                    ])))),
    ]);
  }
}
