// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';
import 'youtube_reference.dart';

const youtubeInlineSupported = true;
bool _registered = false;
final _frames = <int, html.IFrameElement>{};

Widget youtubeFrame(YoutubeReference reference) => _YoutubeFrame(reference);

class _YoutubeFrame extends StatefulWidget {
  const _YoutubeFrame(this.reference);
  final YoutubeReference reference;
  @override
  State<_YoutubeFrame> createState() => _FrameState();
}

class _FrameState extends State<_YoutubeFrame> {
  int? id;
  @override
  void initState() {
    super.initState();
    if (!_registered) {
      ui_web.platformViewRegistry.registerViewFactory('tv2-youtube',
          (int viewId, {Object? params}) {
        final frame = html.IFrameElement();
        _frames[viewId] = frame;
        frame.title = 'YouTube video player';
        frame.style.border = '0';
        frame.style.width = '100%';
        frame.style.height = '100%';
        frame.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
        frame.setAttribute('allow',
            'fullscreen; encrypted-media; picture-in-picture; camera \'none\'; microphone \'none\'; autoplay \'none\'');
        frame.setAttribute('allowfullscreen', '');
        frame.setAttribute('sandbox',
            'allow-scripts allow-same-origin allow-presentation allow-popups');
        // URL is assigned only by the trusted widget after view creation.
        return frame;
      });
      _registered = true;
    }
  }

  @override
  void dispose() {
    final frame = _frames.remove(id);
    if (frame != null) {
      frame.src = 'about:blank';
      frame.remove();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(
      viewType: 'tv2-youtube',
      onPlatformViewCreated: (viewId) {
        id = viewId;
        final frame = _frames[viewId];
        if (!mounted) {
          frame?.remove();
          _frames.remove(viewId);
          return;
        }
        frame?.src = widget.reference.embed.toString();
      });
}
