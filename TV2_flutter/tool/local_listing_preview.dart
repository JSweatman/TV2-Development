// Explicit local test entrypoint. Never imported by the production entrypoint.
import 'package:flutter/material.dart';
import 'package:tv2/main.dart';
import 'package:tv2/resolver_api.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Uri.base.host != '127.0.0.1' &&
      Uri.base.origin != 'https://tv2-media.example.org') {
    throw StateError('Local preview only');
  }
  // The genuine keypad, prefix lookup, exact lookup and listing navigation.
  runApp(TV2App(api: HttpResolverApi(baseUri: Uri.parse(Uri.base.origin))));
}
