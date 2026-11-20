import 'package:flutter_test/flutter_test.dart';
import '../tool/private_video_load.dart';

void main() {
  test('explicit loads have distinct identities on the same private endpoint', () {
    final endpoint = Uri.parse('http://127.0.0.1:54327/private/listings/1*73141/video');
    final loads = List.generate(100, (_) => privateVideoLoadUri(endpoint));
    expect(loads.toSet(), hasLength(100));
    for (final uri in loads) {
      expect(uri.origin, endpoint.origin);
      expect(uri.path, endpoint.path);
      expect(uri.queryParameters.keys, ['previewLoad']);
      expect(uri.userInfo, isEmpty);
      expect(uri.fragment, isEmpty);
    }
  });
}
