import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Same family as Flutter's web default, without requiring a font CDN.
/// Platform-filtered assets and this guard leave native fonts unchanged.
Future<void> loadWebDefaultFont() async {
  if (!kIsWeb) return;
  await loadRobotoWeights((weight) async {
    final loader = FontLoader('Roboto');
    loader.addFont(rootBundle.load('assets/web_fonts/Roboto-$weight.ttf'));
    await loader.load();
  });
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['Roboto (web default)'],
      await rootBundle.loadString('assets/web_fonts/LICENSE.txt'),
    );
  });
}

/// Regular is required; missing optional faces can be synthesized by the engine.
@visibleForTesting
Future<void> loadRobotoWeights(Future<void> Function(String) load) async {
  await load('Regular');
  for (final weight in ['Medium', 'Bold']) {
    try {
      await load(weight);
    } catch (_) {
      debugPrint('Optional Roboto weight unavailable; using registered faces.');
    }
  }
}
