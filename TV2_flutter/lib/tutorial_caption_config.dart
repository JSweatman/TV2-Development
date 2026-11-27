import 'dart:convert';

/// Raw WebVTT retains its original semantics (including literal backslashes).
/// Base64 UTF-8 is an optional single-line transport for compiler build defines.
String tutorialCaptionText({String raw = '', String base64Text = ''}) {
  if (raw.isNotEmpty) return raw;
  if (base64Text.isEmpty) return '';
  try {
    if (base64Text.length > 87384) throw const FormatException();
    final text = utf8.decode(base64.decode(base64Text));
    if (text.length > 65536) throw const FormatException();
    return text;
  } on FormatException {
    // Nonempty invalid text uses the panel's existing sanitized opt-in error.
    return 'Invalid caption configuration';
  }
}
