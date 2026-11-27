// Build-only portable sample entrypoint. No production API or upload service.
import 'package:flutter/material.dart';
import 'package:tv2/main.dart' show TV2App;
import 'portable/sample_resolver.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final uri = Uri.base;
  if (!allowedSampleOrigin(uri)) {
    runApp(const MaterialApp(
        home: Scaffold(
            body: SafeArea(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                        'Private sample review requires an approved HTTPS host.'))))));
    return;
  }
  runApp(TV2App(api: SampleResolver(Uri.parse(uri.origin))));
}
