import 'models.dart';

/// Identifiers only; never accept player HTML, URLs or parameter overrides.
class YoutubeReference {
  const YoutubeReference._(this.videoId);
  final String videoId;
  static YoutubeReference? parse(ResourceRecord resource) {
    final id = resource.metadata['video_id'];
    if (resource.type != 'provider_embed' ||
        resource.uri != null ||
        resource.metadata['provider'] != 'youtube' ||
        resource.metadata.keys.any((k) => k != 'provider' && k != 'video_id') ||
        id is! String ||
        id.length != 11 ||
        !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) return null;
    return YoutubeReference._(id);
  }

  Uri get embed => Uri.https('www.youtube-nocookie.com', '/embed/$videoId',
      {'autoplay': '0', 'playsinline': '1'});
  Uri get watch => Uri.https('www.youtube.com', '/watch', {'v': videoId});
}
