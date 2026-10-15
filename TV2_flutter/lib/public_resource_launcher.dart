import 'package:url_launcher/url_launcher.dart';

/// Restricts externally launched public resources to secure domain-hosted URLs.
///
/// In particular, resolver data must not be able to launch arbitrary URI
/// schemes (tel:, intent:, javascript:, file:) or local network endpoints.
Uri? safePublicResourceUri(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      !uri.hasAuthority ||
      uri.userInfo.isNotEmpty ||
      uri.host.isEmpty ||
      (uri.hasPort && uri.port != 443)) {
    return null;
  }

  final host = uri.host.toLowerCase();
  // Require a DNS-style public host. Do not open IP literals, localhost,
  // single-label intranet names, or special-use internal DNS zones.
  if (!host.contains('.') ||
      host.endsWith('.') ||
      host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      host.endsWith('.internal') ||
      host.endsWith('.test') ||
      host.endsWith('.invalid') ||
      host.endsWith('.example') ||
      RegExp(r'^[0-9.]+$').hasMatch(host) ||
      host.contains(':')) {
    return null;
  }
  // Validate DNS label syntax; this does not guarantee public DNS resolution.
  final labels = host.split('.');
  final labelPattern = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?

class PublicResourceLauncher {
  PublicResourceLauncher({Future<bool> Function(Uri)? open})
      : _open = open ?? _launch;

  final Future<bool> Function(Uri) _open;

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// Returns false when URI is rejected or the platform cannot open it.
  Future<bool> open(String? raw) async {
    final uri = safePublicResourceUri(raw);
    if (uri == null) return false;
    try {
      return await _open(uri);
    } catch (_) {
      return false;
    }
  }
}
);
  if (host.length > 253 ||
      labels.any((label) => !labelPattern.hasMatch(label)) ||
      !RegExp(r'^[a-z]{2,63}

class PublicResourceLauncher {
  PublicResourceLauncher({Future<bool> Function(Uri)? open})
      : _open = open ?? _launch;

  final Future<bool> Function(Uri) _open;

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// Returns false when URI is rejected or the platform cannot open it.
  Future<bool> open(String? raw) async {
    final uri = safePublicResourceUri(raw);
    if (uri == null) return false;
    try {
      return await _open(uri);
    } catch (_) {
      return false;
    }
  }
}
).hasMatch(labels.last)) {
    return null;
  }
  return uri;
}

class PublicResourceLauncher {
  PublicResourceLauncher({Future<bool> Function(Uri)? open})
      : _open = open ?? _launch;

  final Future<bool> Function(Uri) _open;

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// Returns false when URI is rejected or the platform cannot open it.
  Future<bool> open(String? raw) async {
    final uri = safePublicResourceUri(raw);
    if (uri == null) return false;
    try {
      return await _open(uri);
    } catch (_) {
      return false;
    }
  }
}
