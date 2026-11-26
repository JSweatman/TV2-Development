/// All normal Android, iOS and web builds share this public resolver.
/// Database credentials and direct database clients do not belong in the app.
const canonicalResolverOrigin = 'https://tv2-development.onrender.com';

Uri resolverOrigin({
  String configured = canonicalResolverOrigin,
  bool localFixture = false,
}) {
  if (configured == canonicalResolverOrigin && !localFixture) {
    return Uri.parse(canonicalResolverOrigin);
  }
  final uri = Uri.tryParse(configured);
  if (localFixture &&
      uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      (uri.host == '127.0.0.1' ||
          uri.host == 'localhost' ||
          uri.host == '::1') &&
      uri.userInfo.isEmpty &&
      uri.path.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment) {
    return uri;
  }
  throw const FormatException(
    'Normal TV2 builds must use the canonical resolver. '
    'Local fixture builds require TV2_LOCAL_FIXTURE=true and a loopback origin.',
  );
}

Uri configuredResolverOrigin() => resolverOrigin(
      configured: const String.fromEnvironment('TV2_API_BASE_URL',
          defaultValue: canonicalResolverOrigin),
      localFixture: const bool.fromEnvironment('TV2_LOCAL_FIXTURE'),
    );
