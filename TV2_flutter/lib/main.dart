import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'resolver_api.dart';

const _apiBase = String.fromEnvironment(
  'TV2_API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);
const _defaultCountry = String.fromEnvironment(
  'TV2_DEFAULT_COUNTRY',
  defaultValue: '1',
);

void main() {
  final api = HttpResolverApi(baseUri: Uri.parse(_apiBase));
  runApp(TV2App(api: api));
}

class TV2App extends StatelessWidget {
  const TV2App({super.key, required this.api});
  final ResolverApi api;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'List Number TV2',
        theme: ThemeData(useMaterial3: true),
        home: HomeScreen(api: api, initialCountry: _defaultCountry),
      );
}
