// A fresh identity per explicit load avoids browser media-buffer reuse after a
// publication changes. This is not authorization: the same endpoint still checks
// the session and exact listing grant on every request and returns no-store.
int _loadSequence = 0;

Uri privateVideoLoadUri(Uri endpoint) => endpoint.replace(queryParameters: {
  ...endpoint.queryParameters,
  'previewLoad': '${DateTime.now().microsecondsSinceEpoch}-${++_loadSequence}',
});
