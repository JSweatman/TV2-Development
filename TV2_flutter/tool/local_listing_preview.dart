// Explicit local test entrypoint. Not imported by main.dart or production builds.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tv2/home_screen.dart';
import 'package:tv2/models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Uri.base.host != '127.0.0.1') throw StateError('Local preview only');
  final response =
      await http.get(Uri.base.resolve('/v1/resolve?country=1&input=5247'));
  final listing = Listing.fromJson(jsonDecode(response.body)['listing']);
  final routes = RouteObserver<ModalRoute<dynamic>>();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true),
    navigatorObservers: [routes],
    home: TemplateScreen(listing: listing, routeObserver: routes),
  ));
}
