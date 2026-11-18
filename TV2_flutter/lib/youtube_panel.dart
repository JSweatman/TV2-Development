import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'public_resource_launcher.dart';
import 'youtube_reference.dart';
import 'youtube_frame_stub.dart' if (dart.library.html) 'youtube_frame_web.dart'
    as platform;

class YoutubePanel extends StatefulWidget {
  const YoutubePanel(
      {super.key,
      required this.reference,
      this.routeObserver,
      this.inlineSupported,
      this.frameBuilder,
      this.open});
  final YoutubeReference reference;
  final RouteObserver<ModalRoute<dynamic>>? routeObserver;
  final bool? inlineSupported;
  final Widget Function(YoutubeReference)? frameBuilder;
  final Future<bool> Function(Uri)? open;
  @override
  State<YoutubePanel> createState() => _YoutubeState();
}

class _YoutubeState extends State<YoutubePanel>
    with WidgetsBindingObserver, RouteAware {
  bool loaded = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.routeObserver?.unsubscribe(this);
    final route = ModalRoute.of(context);
    if (route != null) widget.routeObserver?.subscribe(this, route);
  }

  @override
  void didUpdateWidget(YoutubePanel old) {
    super.didUpdateWidget(old);
    if (old.reference.videoId != widget.reference.videoId) loaded = false;
    if (old.routeObserver != widget.routeObserver) {
      old.routeObserver?.unsubscribe(this);
      final route = ModalRoute.of(context);
      if (route != null) widget.routeObserver?.subscribe(this, route);
    }
  }

  void dismiss() {
    if (mounted && loaded) setState(() => loaded = false);
  }

  @override
  void didPushNext() => dismiss();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) dismiss();
  }

  @override
  void dispose() {
    widget.routeObserver?.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> watch() async {
    bool opened = false;
    try {
      opened = await (widget.open?.call(widget.reference.watch) ??
          PublicResourceLauncher().open(widget.reference.watch.toString()));
    } catch (_) {/* Manual fallback below. */}
    if (!mounted) return;
    if (!opened)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Unable to open YouTube. Use ${widget.reference.watch} in your browser.')));
  }

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(builder: (context, box) {
            final inline =
                (widget.inlineSupported ?? platform.youtubeInlineSupported) &&
                    box.maxWidth >= 200;
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('YouTube video'),
                  const SizedBox(height: 8),
                  Text(inline
                      ? 'Load to connect to YouTube. Then press Play in its player. YouTube privacy-enhanced mode still contacts the provider.'
                      : 'Inline YouTube playback is unavailable here. Open it in your browser.'),
                  if (loaded && inline) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                        height: math.max(200, box.maxWidth * 9 / 16),
                        child: (widget.frameBuilder ??
                            platform.youtubeFrame)(widget.reference))
                  ],
                  const SizedBox(height: 8),
                  if (loaded && inline)
                    const Text(
                        'If the player is blocked or unavailable, use Open on YouTube.'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (inline)
                      FilledButton.tonal(
                          onPressed: () => setState(() => loaded = !loaded),
                          child: Text(loaded
                              ? 'Dismiss YouTube video'
                              : 'Load YouTube video')),
                    OutlinedButton(
                        onPressed: watch, child: const Text('Open on YouTube')),
                  ]),
                ]);
          })));
}
