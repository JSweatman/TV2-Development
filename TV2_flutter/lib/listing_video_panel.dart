import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'video_preview_placeholder.dart';

import 'models.dart';
import 'listing_availability_gate.dart';
import 'public_resource_launcher.dart';

Uri? listingVideoUri(Listing listing) {
  for (final resource in listing.resources) {
    if (resource.type == 'listing_video' &&
        resource.metadata['publication'] == 'published' &&
        resource.metadata['content_type'] == 'video/mp4') {
      final uri = safePublicResourceUri(resource.uri);
      if (uri != null) return uri;
    }
  }
  return null;
}

typedef ListingControllerFactory = VideoPlayerController Function(Uri);

class ListingVideoPanel extends StatefulWidget {
  const ListingVideoPanel({
    super.key,
    required this.listing,
    this.controllerFactory,
    this.authorizeAction,
    this.routeObserver,
    this.expanded = false,
    this.onExpansionChanged,
  });
  final Listing listing;
  final bool expanded;
  final ValueChanged<bool>? onExpansionChanged;
  final ListingControllerFactory? controllerFactory;
  final AuthorizeListingAction? authorizeAction;
  final RouteObserver<ModalRoute<dynamic>>? routeObserver;

  @override
  State<ListingVideoPanel> createState() => ListingVideoPanelState();
}

class ListingVideoPanelState extends State<ListingVideoPanel>
    with WidgetsBindingObserver, RouteAware {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;
  bool _dismissed = false;
  int _generation = 0;
  Orientation? _orientation;
  final _playerKey = GlobalKey();

  void _requestExpansion(bool expanded) {
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      if (expanded &&
          (_orientation != Orientation.landscape ||
              !(_controller?.value.isPlaying ?? false) ||
              (_controller?.value.hasError ?? false))) return;
      widget.onExpansionChanged?.call(expanded);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.orientationOf(context);
    if (_orientation != null && orientation != _orientation) {
      final value = _controller?.value;
      if (orientation == Orientation.portrait) {
        if (widget.expanded) _requestExpansion(false);
      } else if (value != null &&
          value.isPlaying &&
          !value.hasError &&
          value.isInitialized &&
          !_loading &&
          !_dismissed) {
        _requestExpansion(true);
      }
    }
    _orientation = orientation;
    widget.routeObserver?.unsubscribe(this);
    final route = ModalRoute.of(context);
    if (route != null) widget.routeObserver?.subscribe(this, route);
  }

  @override
  void didUpdateWidget(ListingVideoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeObserver != widget.routeObserver) {
      oldWidget.routeObserver?.unsubscribe(this);
      final route = ModalRoute.of(context);
      if (route != null) widget.routeObserver?.subscribe(this, route);
    }
    if (oldWidget.listing.qualifiedIdentity !=
            widget.listing.qualifiedIdentity ||
        listingVideoUri(oldWidget.listing) != listingVideoUri(widget.listing)) {
      _release();
      _dismissed = false;
      _failed = false;
    }
  }

  void _changed() {
    if (mounted) {
      if (widget.expanded && (_controller?.value.hasError ?? false)) {
        _requestExpansion(false);
      }
      setState(() {});
    }
  }

  void _release() {
    _generation++;
    if (widget.expanded) _requestExpansion(false);
    _loading = false;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_changed);
      // Stop playback even if native disposal subsequently reports a failure.
      if (controller.value.isInitialized) {
        unawaited(controller.pause().catchError((Object _) {}));
      }
      unawaited(controller.dispose().catchError((Object _) {}));
    }
  }

  Future<void> _authorizeLoad() async {
    final authorize = widget.authorizeAction;
    if (authorize == null) {
      await _load();
    } else {
      await authorize(() {
        if (mounted) _load();
      });
    }
  }

  Future<void> _authorizeToggle() async {
    if (_controller?.value.isPlaying ?? false) {
      await _toggle();
      return;
    }
    final authorize = widget.authorizeAction;
    if (authorize == null) {
      await _toggle();
    } else {
      await authorize(() {
        if (mounted) _toggle();
      });
    }
  }

  Future<void> _load() async {
    _release();
    final generation = _generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final video = listingVideoUri(widget.listing)!;
      final controller = widget.controllerFactory?.call(video) ??
          VideoPlayerController.networkUrl(
            video,
            // This widget owns lifecycle pausing; disable the plugin's automatic
            // resume observer. This does not enable playback in our background.
            videoPlayerOptions: VideoPlayerOptions(
              allowBackgroundPlayback: true,
            ),
          );
      _controller = controller;
      controller.addListener(_changed);
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
      // Deliberately no play here: the next Play press is a fresh browser gesture.
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _release();
      setState(() => _failed = true);
    }
  }

  Future<void> _toggle() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        // video_player rewinds a completed video when Play is pressed again.
        await controller.play();
      }
    } catch (_) {
      if (!mounted || _controller != controller) return;
      _release();
      setState(() => _failed = true);
    }
  }

  /// Request a pause without awaiting platform work, so the caller can open
  /// an external URL in the original user gesture. Never resumes on return.
  void pauseForExternalHandoff() {
    if (_controller?.value.isPlaying ?? false) _pause();
  }

  void _pause() {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      unawaited(controller.pause().catchError((Object _) {}));
    }
  }

  @override
  void didPushNext() {
    _pause();
    if (widget.expanded) _requestExpansion(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  @override
  void dispose() {
    widget.routeObserver?.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = listingVideoUri(widget.listing);
    if (video == null) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: VideoPreviewPlaceholder(),
      );
    }
    if (_dismissed) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonal(
          onPressed: () => setState(() => _dismissed = false),
          child: const Text('Show listing video'),
        ),
      );
    }
    final controller = _controller;
    final error = _failed || (controller?.value.hasError ?? false);
    final ready =
        !error && !_loading && (controller?.value.isInitialized ?? false);
    final playing = ready && controller!.value.isPlaying;
    final completed = ready && controller!.value.isCompleted;
    if (widget.expanded && ready) {
      return ColoredBox(
        key: const Key('listing-video-expanded'),
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: controller!.value.aspectRatio,
                  child: VideoPlayer(controller, key: _playerKey),
                ),
              ),
            ),
            // Controls stay outside the image: no cropping or hidden exit action.
            Flexible(
              flex: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.4),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(
                          onPressed: _authorizeToggle,
                          child: Text(
                            playing
                                ? 'Pause listing video'
                                : completed
                                    ? 'Replay listing video'
                                    : 'Play listing video',
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () =>
                              widget.onExpansionChanged?.call(false),
                          child: const Text('Exit expanded video'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Material(
      color: const Color(0xFF0A1529),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Listing video',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            if (ready)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller!.value.aspectRatio,
                    child: VideoPlayer(controller, key: _playerKey),
                  ),
                ),
              ),
            if (_loading) ...[
              const LinearProgressIndicator(),
              const Text(
                'Loading listing video…',
                style: TextStyle(color: Colors.white),
              ),
            ],
            if (error)
              Semantics(
                liveRegion: true,
                child: Text(
                  'Listing video unavailable. Retry or continue using the listing.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _loading
                      ? null
                      : ready
                          ? _authorizeToggle
                          : _authorizeLoad,
                  child: Text(
                    error
                        ? 'Retry listing video'
                        : ready
                            ? playing
                                ? 'Pause listing video'
                                : completed
                                    ? 'Replay listing video'
                                    : 'Play listing video'
                            : 'Load listing video',
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    _release();
                    setState(() => _dismissed = true);
                  },
                  child: const Text('Dismiss listing video'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
