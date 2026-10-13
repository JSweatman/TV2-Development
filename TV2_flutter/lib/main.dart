import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'resolver_api.dart';

const _apiBase = String.fromEnvironment(
  'TV2_API_BASE_URL',
  defaultValue: 'https://tv2-development.onrender.com',
);

void main() {
  final api = HttpResolverApi(baseUri: Uri.parse(_apiBase));
  runApp(TV2App(api: api));
}

class TV2App extends StatelessWidget {
  const TV2App({
    super.key,
    required this.api,
    this.initialCountry,
  });

  final ResolverApi api;
  final String? initialCountry;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'List Number TV2',
        theme: ThemeData(useMaterial3: true),
        home: HomeScreen(api: api, initialCountry: initialCountry),
      );
}
