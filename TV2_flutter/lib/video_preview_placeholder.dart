import 'package:flutter/material.dart';

/// Visual-only TV2 test-bed media area. No playback, connection, camera,
/// permissions, player controls or media network requests are implemented.
class VideoPreviewPlaceholder extends StatelessWidget {
  const VideoPreviewPlaceholder({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primaryContainer;
    return Semantics(
      container: true,
      label: 'Video preview placeholder. Playback is not available in this TV2 test build.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          key: const Key('tv2-video-placeholder'),
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A1529), Color(0xFF1B3156), Color(0xFF0C1C30)],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: compact ? 10 : 16,
                left: 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_outlined, size: compact ? 15 : 18, color: accent),
                    const SizedBox(width: 7),
                    Text(
                      'TV2  /  MEDIA',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 10 : 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Container(
                  width: compact ? 46 : 64,
                  height: compact ? 46 : 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: compact ? 30 : 38,
                  ),
                ),
              ),
              Positioned(
                bottom: compact ? 9 : 16,
                left: 14,
                right: 14,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'VIDEO PREVIEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 10 : 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Text(
                      'COMING SOON',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w500,
                        fontSize: compact ? 9 : 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
