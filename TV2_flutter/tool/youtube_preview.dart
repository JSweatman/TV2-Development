// Official YouTube documentation sample, explicit local-only review entrypoint.
import 'package:flutter/material.dart';
import 'package:tv2/home_screen.dart';
import 'package:tv2/models.dart';

void main() {
  if (Uri.base.host != '127.0.0.1') throw StateError('Local review only');
  runApp(MaterialApp(
      home: TemplateScreen(
          listing: const Listing(
              countryCode: '1',
              listNumber: '70001',
              tldx: null,
              displayName: 'Official YouTube player sample',
              entityType: 'test',
              templateKey: 'basic',
              resources: [
        ResourceRecord(
            key: 'theme',
            type: 'landing_theme',
            uri: null,
            metadata: {'version': 1, 'palette': 'lotus'}),
        ResourceRecord(
            key: 'youtube',
            type: 'provider_embed',
            uri: null,
            metadata: {'provider': 'youtube', 'video_id': 'M7lc1UVf-VE'})
      ],
              buttons: []))));
}
