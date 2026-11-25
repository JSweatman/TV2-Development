import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/tutorial_caption_config.dart';

void main() {
  test('absent config remains absent', () {
    expect(tutorialCaptionText(), '');
  });
  test('raw input is preserved exactly and takes precedence', () {
    const raw = 'WEBVTT\r\n\r\n00:00.000 --> 00:01.000\r\nLiteral \\n café\r\n';
    expect(tutorialCaptionText(raw: raw, base64Text: 'bad'), raw);
  });
  test('base64 UTF8 preserves generated newlines and literal backslashes', () {
    const text = 'WEBVTT\n\n00:00.000 --> 00:01.000\nCafé \\n\n';
    expect(tutorialCaptionText(base64Text: base64.encode(utf8.encode(text))),
        text);
  });
  test('invalid or oversized encoded config is nonempty invalid text', () {
    for (final value in ['!', '/w==', 'A' * 87385]) {
      expect(tutorialCaptionText(base64Text: value),
          'Invalid caption configuration');
    }
  });
}
