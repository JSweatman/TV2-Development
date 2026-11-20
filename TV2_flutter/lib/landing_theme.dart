import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'models.dart';

/// Versioned, data-only contract. No CSS, remote images, arbitrary colors/fonts.
class LandingThemeSpec {
  const LandingThemeSpec._(this.palette, this.hero);
  final String palette;
  final String? hero;

  static LandingThemeSpec? fromListing(Listing listing) {
    final configs = listing.resources.where((r) => r.type == 'landing_theme');
    if (configs.length != 1) return null;
    final resource = configs.single;
    final data = resource.metadata;
    if (resource.uri != null ||
        data['version'] is! int ||
        data['version'] != 1 ||
        data.keys.any((k) => !{'version', 'palette', 'hero'}.contains(k)) ||
        !{'graphite', 'lotus'}.contains(data['palette']) ||
        (data['hero'] != null && !{'horizon', 'petals'}.contains(data['hero'])))
      return null;
    if (listing.resources.map((r) => r.key).toSet().length !=
        listing.resources.length) return null;
    if (listing.buttons.any((b) =>
        !RegExp(r'^[A-Za-z0-9_-]{1,60}$').hasMatch(b.resourceKey) ||
        (b.label != null && RegExp(r'[\x00-\x1F\x7F]').hasMatch(b.label!))))
      return null;
    final slots = listing.buttons.map((b) => b.slot).toList();
    if (slots.any((s) => s < 1 || s > 6) ||
        slots.toSet().length != slots.length ||
        listing.buttons.any((b) =>
            b.label != null &&
            (b.label!.trim().isEmpty || b.label!.length > 32))) return null;
    return LandingThemeSpec._(
        data['palette'] as String, data['hero'] as String?);
  }

  bool get dark => palette == 'graphite';
  Color get background =>
      dark ? const Color(0xFF101820) : const Color(0xFFF7F5EE);
  Color get surface => dark ? const Color(0xFF25333C) : const Color(0xFFE3EDE5);
  Color get foreground =>
      dark ? const Color(0xFFF5F3ED) : const Color(0xFF203C36);
  Color get accent => dark ? const Color(0xFFE5CC91) : const Color(0xFF375F53);
  ThemeData theme() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
                seedColor: accent,
                brightness: dark ? Brightness.dark : Brightness.light)
            .copyWith(
                surface: background,
                onSurface: foreground,
                primary: accent,
                onPrimary: background,
                secondaryContainer: surface,
                onSecondaryContainer: foreground),
        scaffoldBackgroundColor: background,
        appBarTheme: AppBarTheme(
            backgroundColor: background, foregroundColor: foreground),
        textTheme: TextTheme(
            headlineMedium: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w600, color: foreground),
            bodyMedium:
                TextStyle(fontSize: 16, height: 1.4, color: foreground)),
      );
}

/// Reserved provider contract. No provider SDK, iframe or remote fetch is enabled.
class ProviderVideoReference {
  const ProviderVideoReference(this.provider, this.videoId);
  final String provider;
  final String videoId;
  static ProviderVideoReference? parse(ResourceRecord resource) {
    final provider = resource.metadata['provider'];
    final id = resource.metadata['video_id'];
    if (resource.type != 'provider_embed' ||
        resource.uri != null ||
        resource.metadata.keys
            .any((k) => !{'provider', 'video_id'}.contains(k)) ||
        provider is! String ||
        id is! String ||
        !RegExp(r'^[a-z][a-z0-9_]{0,31}$').hasMatch(provider) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)) return null;
    return ProviderVideoReference(provider, id);
  }
}

class LandingHero extends StatelessWidget {
  const LandingHero({super.key, required this.spec});
  final LandingThemeSpec spec;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: SizedBox(
          height: 130,
          width: double.infinity,
          child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(painter: _HeroPainter(spec)))));
}

/// Original geometric decoration, not supplied/private art or business imagery.
class _HeroPainter extends CustomPainter {
  const _HeroPainter(this.spec);
  final LandingThemeSpec spec;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = LinearGradient(colors: [spec.surface, spec.background])
              .createShader(bounds));
    if (spec.hero == 'horizon') {
      final p = Path()
        ..moveTo(0, size.height * .78)
        ..quadraticBezierTo(
            size.width * .5, size.height * .12, size.width, size.height * .64);
      canvas.drawPath(
          p,
          Paint()
            ..color = spec.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      for (var i = 0; i < 5; i++) {
        canvas.drawLine(
            Offset(size.width * (.1 + i * .2), size.height),
            Offset(size.width * .5, size.height * .55),
            Paint()
              ..color = spec.accent.withValues(alpha: .15)
              ..strokeWidth = 1);
      }
      canvas.drawCircle(Offset(size.width * .78, size.height * .25), 11,
          Paint()..color = spec.accent);
    } else {
      for (var i = 0; i < 5; i++) {
        canvas.save();
        canvas.translate(size.width / 2, size.height * .72);
        canvas.rotate((i - 2) * math.pi / 7);
        final p = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-32, -38, 0, -78)
          ..quadraticBezierTo(32, -38, 0, 0);
        canvas.drawPath(
            p,
            Paint()
              ..color =
                  (i.isEven ? const Color(0xFFB8CDC3) : const Color(0xFFE8C9D4))
                      .withValues(alpha: .75));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_HeroPainter old) =>
      old.spec.palette != spec.palette || old.spec.hero != spec.hero;
}
