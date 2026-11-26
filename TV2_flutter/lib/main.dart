import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'device_handoff.dart';
import 'resolver_api.dart';
import 'saved_title_resolver.dart';
import 'resolver_config.dart';
import 'tutorial_panel.dart';
import 'tutorial_caption_config.dart';

void main() {
  final api = HttpResolverApi(baseUri: configuredResolverOrigin());
  runApp(TV2App(
      api: api,
      tutorial: TutorialVideo.fromUrl(
        const String.fromEnvironment('TV2_TUTORIAL_URL'),
        captionsVtt: tutorialCaptionText(
          raw: const String.fromEnvironment('TV2_TUTORIAL_CAPTIONS_VTT'),
          base64Text:
              const String.fromEnvironment('TV2_TUTORIAL_CAPTIONS_VTT_BASE64'),
        ),
      )));
}

class TV2App extends StatefulWidget {
  const TV2App({
    super.key,
    required this.api,
    this.initialCountry,
    this.tutorial,
    this.deviceHandoff,
  });

  final ResolverApi api;
  final DeviceHandoff? deviceHandoff;
  final String? initialCountry;
  final TutorialVideo? tutorial;

  @override
  State<TV2App> createState() => _TV2AppState();
}

class _TV2AppState extends State<TV2App> {
  late ResolverApi _savedTitleApi = SavedTitleResolver(widget.api);

  @override
  void didUpdateWidget(covariant TV2App oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) _savedTitleApi = SavedTitleResolver(widget.api);
  }

  final _tutorialRoutes = RouteObserver<ModalRoute<dynamic>>();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'List Number TV2',
        theme: ThemeData(useMaterial3: true),
        navigatorObservers: [_tutorialRoutes],
        home: HomeScreen(
            api: _savedTitleApi,
            deviceHandoff: widget.deviceHandoff,
            initialCountry: widget.initialCountry,
            tutorial: widget.tutorial,
            tutorialRoutes: _tutorialRoutes),
      );
}
