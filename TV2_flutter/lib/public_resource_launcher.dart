import 'package:url_launcher/url_launcher.dart';

/// Accepts only syntactically valid HTTPS URLs with DNS-style hostnames.
/// This does not prove that DNS resolves to a public address.
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
  if (!host.contains('.') ||
      host.endsWith('.') ||
      host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      host.endsWith('.internal') ||
      host.endsWith('.test') ||
      host.endsWith('.invalid') ||
      host.endsWith('.example') ||
      RegExp(r'^[0-9.]+').firstMatch(host)?.group(0) == host ||
      host.contains(':') ||
      host.length > 253) {
    return null;
  }

  final labels = host.split('.');
  final labelPattern = RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?');
  for (final label in labels) {
    final match = labelPattern.firstMatch(label);
    if (match == null || match.group(0)!.length != label.length) {
      return null;
    }
  }
  final tld = labels.last;
  if (tld.length < 2 || tld.length > 63 ||
      !RegExp(r'^[a-z]+').hasMatch(tld) ||
      RegExp(r'^[a-z]+').firstMatch(tld)!.group(0)!.length != tld.length) {
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
