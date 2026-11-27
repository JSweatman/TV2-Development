import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Same family as Flutter's web default, without requiring a font CDN.
/// Platform-filtered assets and this guard leave native fonts unchanged.
Future<void> loadWebDefaultFont() async {
  if (!kIsWeb) return;
  final loader = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    loader.addFont(rootBundle.load('assets/web_fonts/Roboto-$weight.ttf'));
  }
  await loader.load();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['Roboto (web default)'],
      await rootBundle.loadString('assets/web_fonts/LICENSE.txt'),
    );
  });
}
