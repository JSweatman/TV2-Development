import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'resolver_api.dart';
import 'tutorial_panel.dart';

const _apiBase = String.fromEnvironment(
  'TV2_API_BASE_URL',
  defaultValue: 'https://tv2-development.onrender.com',
);

void main() {
  final api = HttpResolverApi(baseUri: Uri.parse(_apiBase));
  runApp(TV2App(
      api: api,
      tutorial: TutorialVideo.fromUrl(
        const String.fromEnvironment('TV2_TUTORIAL_URL'),
      )));
}

class TV2App extends StatefulWidget {
  const TV2App({
    super.key,
    required this.api,
    this.initialCountry,
    this.tutorial,
  });

  final ResolverApi api;
  final String? initialCountry;
  final TutorialVideo? tutorial;

  @override
  State<TV2App> createState() => _TV2AppState();
}

class _TV2AppState extends State<TV2App> {
  final _tutorialRoutes = RouteObserver<ModalRoute<dynamic>>();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'List Number TV2',
        theme: ThemeData(useMaterial3: true),
        navigatorObservers: [_tutorialRoutes],
        home: HomeScreen(
            api: widget.api,
            initialCountry: widget.initialCountry,
            tutorial: widget.tutorial,
            tutorialRoutes: _tutorialRoutes),
      );
}
