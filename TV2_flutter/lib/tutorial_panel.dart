import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'video_preview_placeholder.dart';

/// Build-owned configuration. No tutorial, account or analytics by default.
class TutorialVideo {
  const TutorialVideo(
      {required this.uri, this.title = 'TV2 tutorial', this.captionsVtt = ''});
  final Uri uri;
  final String title;
  final String captionsVtt;

  static TutorialVideo? fromUrl(String value, {String captionsVtt = ''}) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) return null;
    return TutorialVideo(uri: uri, captionsVtt: captionsVtt);
  }
}

typedef TutorialControllerFactory = VideoPlayerController Function(
    TutorialVideo);

class TutorialPanel extends StatefulWidget {
  const TutorialPanel({
    super.key,
    required this.tutorial,
    this.controllerFactory,
    this.routeObserver,
  });
  final TutorialVideo? tutorial;
  final TutorialControllerFactory? controllerFactory;
  final RouteObserver<ModalRoute<dynamic>>? routeObserver;

  @override
  State<TutorialPanel> createState() => _TutorialPanelState();
}

class _TutorialPanelState extends State<TutorialPanel>
    with WidgetsBindingObserver, RouteAware {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;
  bool _dismissed = false;
  int _generation = 0;
  bool _captionsEnabled = false;
  bool _captionError = false;
  List<Caption>? _captions;

  bool _prepareCaptions() {
    if (_captions != null) return true;
    try {
      final source = widget.tutorial!.captionsVtt.trim();
      if (!RegExp(r'^WEBVTT(?:[ \t].*)?(?:\r?\n|$)').hasMatch(source) ||
          source.length > 65536) {
        throw const FormatException('Invalid caption file');
      }
      final cues = WebVTTCaptionFile(source).captions;
      if (cues.isEmpty ||
          cues.length > 200 ||
          RegExp('-->').allMatches(source).length != cues.length) {
        throw const FormatException('Invalid caption cues');
      }
      var previousEnd = Duration.zero;
      for (final cue in cues) {
        if (cue.start < previousEnd ||
            cue.end <= cue.start ||
            cue.text.trim().isEmpty) {
          throw const FormatException('Invalid caption timing');
        }
        previousEnd = cue.end;
      }
      _captions = cues;
      return true;
    } catch (_) {
      setState(() => _captionError = true);
      return false;
    }
  }

  String _currentCaption() {
    final controller = _controller;
    if (!_captionsEnabled ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.hasError ||
        controller.value.isCompleted) return '';
    final position = controller.value.position;
    for (final cue in _captions ?? <Caption>[]) {
      if (cue.start <= position && position < cue.end) return cue.text;
    }
    return '';
  }

  void _showTranscript() {
    if (!_prepareCaptions()) return;
    _pause();
    final transcript = _captions!.map((cue) => cue.text).join('\n\n');
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Tutorial transcript'),
              content: SingleChildScrollView(
                  child: SelectionArea(
                      child: Text(transcript,
                          key: const Key('tutorial-transcript-text')))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close transcript'))
              ],
            ));
  }

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
  void didUpdateWidget(TutorialPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeObserver != widget.routeObserver) {
      oldWidget.routeObserver?.unsubscribe(this);
      final route = ModalRoute.of(context);
      if (route != null) widget.routeObserver?.subscribe(this, route);
    }
    if (oldWidget.tutorial != widget.tutorial) {
      _release();
      _dismissed = false;
      _failed = false;
      _captionsEnabled = false;
      _captionError = false;
      _captions = null;
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _release() {
    _generation++;
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

  Future<void> _load() async {
    _release();
    final generation = _generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final video = widget.tutorial!;
      final controller = widget.controllerFactory?.call(video) ??
          VideoPlayerController.networkUrl(
            video.uri,
            // This widget owns lifecycle pausing; disable the plugin's automatic
            // resume observer. This does not enable playback in our background.
            videoPlayerOptions:
                VideoPlayerOptions(allowBackgroundPlayback: true),
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

  void _pause() {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      unawaited(controller.pause().catchError((Object _) {}));
    }
  }

  @override
  void didPushNext() => _pause();

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
    final video = widget.tutorial;
    if (video == null) {
      return SizedBox(
        height: 120 + MediaQuery.textScalerOf(context).scale(20),
        child: const VideoPreviewPlaceholder(compact: true),
      );
    }
    if (_dismissed) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonal(
          onPressed: () => setState(() => _dismissed = false),
          child: const Text('Show tutorial'),
        ),
      );
    }
    final controller = _controller;
    final error = _failed || (controller?.value.hasError ?? false);
    final ready =
        !error && !_loading && (controller?.value.isInitialized ?? false);
    final playing = ready && controller!.value.isPlaying;
    final completed = ready && controller!.value.isCompleted;
    final caption = _currentCaption();
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
              video.title,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            if (ready)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller!.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(caption,
                    key: const Key('tutorial-active-caption'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
              ),
            if (_loading) ...[
              const LinearProgressIndicator(),
              const Text(
                'Loading tutorial…',
                style: TextStyle(color: Colors.white),
              ),
            ],
            if (error)
              Semantics(
                liveRegion: true,
                child: Text(
                  'Tutorial unavailable. Retry or continue using the keypad.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            const SizedBox(height: 8),
            if (video.captionsVtt.isEmpty)
              const Text('Captions and transcript are not configured.',
                  style: TextStyle(color: Colors.white)),
            if (_captionError)
              Semantics(
                  liveRegion: true,
                  child: Text(
                      'Captions and transcript unavailable. You can still use the video or keypad.',
                      style: TextStyle(color: Colors.white))),
            if (video.captionsVtt.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () {
                    if (_prepareCaptions())
                      setState(() => _captionsEnabled = !_captionsEnabled);
                  },
                  child: Text(
                      _captionsEnabled ? 'Hide captions' : 'Show captions'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: _showTranscript,
                  child: const Text('Show transcript'),
                ),
              ]),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _loading
                      ? null
                      : ready
                          ? _toggle
                          : _load,
                  child: Text(
                    error
                        ? 'Retry tutorial'
                        : ready
                            ? playing
                                ? 'Pause tutorial'
                                : completed
                                    ? 'Replay tutorial'
                                    : 'Play tutorial'
                            : 'Load tutorial',
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    _release();
                    setState(() {
                      _dismissed = true;
                      _captionsEnabled = false;
                      _captionError = false;
                      _captions = null;
                    });
                  },
                  child: const Text('Dismiss tutorial'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
