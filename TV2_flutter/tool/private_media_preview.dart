// Web-only disposable preview. Not imported by lib/main.dart.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'private_media_widgets.dart';

class LocalMediaApi implements PreviewMediaApi {
  http.Client client = http.Client();
  Uri uri(String path) => Uri.parse('${Uri.base.origin}$path');
  void check(http.Response r) {
    if (r.statusCode != 200) throw PreviewMediaFailure(r.statusCode);
  }

  @override
  Future<bool> signIn(String email, String password) async {
    final r = await client.post(uri('/preview/session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}));
    check(r);
    return jsonDecode(r.body)['owner'] == true;
  }

  @override
  Future<String> upload(Uint8List bytes) async {
    final r = await client.put(uri('/private/listings/1*73141/uploads'),
        headers: {'Content-Type': 'video/mp4'}, body: bytes);
    check(r);
    return jsonDecode(r.body)['upload_id'] as String;
  }

  @override
  Future<void> publish(String id) async {
    final r = await client.post(uri('/private/listings/1*73141/publish/$id'));
    check(r);
  }

  @override
  void cancel() {
    client.close();
    client = http.Client();
  }

  @override
  Future<void> signOut() async {
    try {
      await client.delete(uri('/preview/session'));
    } catch (_) {
      // Always remove the local UI session, even when the gateway is unavailable.
    } finally {
      cancel();
    }
  }
}

Future<PreviewClip?> pick() async {
  final input = html.FileUploadInputElement()..accept = '.mp4,video/mp4';
  final done = Completer<PreviewClip?>();
  input.addEventListener('cancel', (_) {
    if (!done.isCompleted) done.complete(null);
  });
  input.onChange.listen((_) async {
    try {
      final files = input.files;
      if (files == null || files.isEmpty) {
        done.complete(null);
        return;
      }
      final f = files.single;
      if (f.size > 5242880) {
        done.complete(PreviewClip(f.name, Uint8List(0)));
        return;
      }
      final reader = html.FileReader();
      reader.readAsArrayBuffer(f);
      await reader.onLoad.first;
      done.complete(PreviewClip(f.name, reader.result as Uint8List));
    } catch (_) {
      if (!done.isCompleted) done.complete(null);
    }
  });
  input.click();
  return done.future;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Uri.base.host != '127.0.0.1' ||
      Uri.base.scheme != 'http' ||
      Uri.base.port != 54327) throw StateError('Disposable local preview only');
  runApp(MaterialApp(
      home: PrivateMediaPreview(
          api: LocalMediaApi(),
          pick: pick,
          player: () => PrivatePreviewPlayer(
              create: () => VideoPlayerController.networkUrl(
                  Uri.parse(
                      '${Uri.base.origin}/private/listings/1*73141/video'),
                  videoPlayerOptions:
                      VideoPlayerOptions(allowBackgroundPlayback: true))))));
}
