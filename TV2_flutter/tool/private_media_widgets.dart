// Preview-only UI: imported only by the explicit local entrypoint and tests.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:tv2/home_screen.dart';
import 'package:tv2/models.dart';

class PreviewClip {
  PreviewClip(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

abstract class PreviewMediaApi {
  Future<bool> signIn(String email, String password);
  Future<String> upload(Uint8List bytes);
  Future<void> publish(String id);
  void cancel();
  Future<void> signOut();
}

// Carry only the HTTP status; never display a provider response body.
class PreviewMediaFailure implements Exception {
  const PreviewMediaFailure(this.statusCode);
  final int statusCode;
}

String previewActionFailure(Object error, {required bool upload}) {
  final code = error is PreviewMediaFailure ? error.statusCode : null;
  if (code == 401) return 'Session unavailable. Sign out and sign in again.';
  if (code == 403) {
    return 'Permission denied for this listing. Check that this account is allowed to make this change.';
  }
  if (upload) {
    if (code == 413)
      return 'Choose an MP4 between 1 byte and 5 MiB, then upload again.';
    if (code == 415)
      return 'Choose an MP4 file, then upload again. MOV is not supported.';
    if (code == 422) {
      return 'This clip could not be validated. Choose an MP4 with one H.264 video track, optional AAC audio, up to 30 seconds and 5 MiB, with long side at most 1920 pixels and short side at most 1080 pixels. HEVC is not supported. Choose a replacement and upload again.';
    }
  }
  return 'Action failed. Retry when ready. Nothing is published automatically.';
}

const privateListing = Listing(
    countryCode: '1',
    listNumber: '73141',
    tldx: null,
    displayName: 'Copper Observatory · synthetic',
    entityType: 'test',
    templateKey: 'basic',
    resources: [
      ResourceRecord(
          key: 'theme',
          type: 'landing_theme',
          uri: null,
          metadata: {'version': 1, 'palette': 'graphite', 'hero': 'horizon'})
    ],
    buttons: []);

class PrivateMediaPreview extends StatefulWidget {
  const PrivateMediaPreview(
      {super.key, required this.api, required this.pick, required this.player});
  final PreviewMediaApi api;
  final Future<PreviewClip?> Function() pick;
  final Widget Function() player;
  @override
  State<PrivateMediaPreview> createState() => _PreviewState();
}

class _PreviewState extends State<PrivateMediaPreview> {
  final email = TextEditingController(), password = TextEditingController();
  bool? owner;
  bool busy = false;
  bool publishing = false;
  String status = '';
  String? draft;
  PreviewClip? clip;
  int generation = 0;
  @override
  void dispose() {
    generation++;
    widget.api.cancel();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => status = 'Enter the synthetic test account and password.');
      return;
    }
    setState(() {
      busy = true;
      status = 'Signing in…';
    });
    try {
      final value = await widget.api.signIn(email.text.trim(), password.text);
      if (!mounted) return;
      setState(() {
        owner = value;
        status = '';
      });
    } catch (_) {
      if (mounted)
        setState(() =>
            status = 'Sign-in unavailable. Check the test account and retry.');
    } finally {
      password.clear();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> choose() async {
    final file = await widget.pick();
    if (!mounted) return;
    setState(() {
      draft = null;
      clip = null;
      if (file == null) {
        status = 'Selection cancelled.';
        return;
      }
      if (!file.name.toLowerCase().endsWith('.mp4') ||
          file.bytes.isEmpty ||
          file.bytes.length > 5242880) {
        status = 'Choose an MP4 between 1 byte and 5 MiB.';
        return;
      }
      clip = file;
      status =
          'Synthetic MP4 selected. Server validates content before publication.';
    });
  }

  Future<void> send({bool publish = false}) async {
    final run = ++generation;
    setState(() {
      busy = true;
      publishing = publish;
      status = publish ? 'Publishing…' : 'Uploading private draft…';
    });
    try {
      if (publish) {
        await widget.api.publish(draft!);
      } else {
        final id = await widget.api.upload(clip!.bytes);
        if (run == generation) draft = id;
      }
      if (mounted && run == generation)
        setState(() => status = publish
            ? 'Published for allowed viewers.'
            : 'Private draft ready. Publish is a separate action.');
    } catch (error) {
      if (mounted && run == generation)
        setState(() => status = previewActionFailure(error, upload: !publish));
    } finally {
      if (mounted && run == generation) setState(() => busy = false);
    }
  }

  void cancel() {
    generation++;
    widget.api.cancel();
    setState(() {
      busy = false;
      draft = null;
      status =
          'Cancelled. Nothing was published; a private draft may need cleanup.';
    });
  }

  Future<void> signOut() async {
    generation++;
    widget.api.cancel();
    await widget.api.signOut();
    if (!mounted) return;
    setState(() {
      owner = null;
      draft = null;
      clip = null;
      status = '';
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (owner == false)
      return Material(
          child: Column(children: [
        SafeArea(
            bottom: false,
            child:
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Text('Local allowed-viewer preview'),
              TextButton(onPressed: signOut, child: const Text('Sign out'))
            ])),
        Expanded(
            child: TemplateScreen(
                listing: privateListing, mediaOverride: widget.player()))
      ]));
    return Scaffold(
        appBar: AppBar(
            title: Text(owner == true
                ? 'Local owner preview'
                : 'Local private-media preview')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  const Text(
                      'Synthetic local test only. Ordinary TV2 lookup does not require sign-in.'),
                  const SizedBox(height: 16),
                  if (owner == null) ...[
                    TextField(
                        key: const ValueKey("preview-email"),
                        controller: email,
                        decoration:
                            const InputDecoration(labelText: 'Test account'),
                        autocorrect: false),
                    TextField(
                        key: const ValueKey("preview-password"),
                        controller: password,
                        decoration:
                            const InputDecoration(labelText: 'Test password'),
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        onSubmitted: (_) {
                          if (!busy) signIn();
                        }),
                    FilledButton(
                        onPressed: busy ? null : signIn,
                        child: const Text('Sign in to local preview')),
                  ] else ...[
                    const Text('1*73141 · Copper Observatory'),
                    const Text('MP4 only · up to 5 MiB · up to 30 seconds'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton(
                          onPressed: busy ? null : choose,
                          child: const Text('Choose synthetic MP4')),
                      FilledButton(
                          onPressed: busy || clip == null ? null : () => send(),
                          child: const Text('Upload private draft')),
                      FilledButton(
                          onPressed: busy || draft == null
                              ? null
                              : () => send(publish: true),
                          child: const Text('Publish listing video')),
                      if (busy && !publishing)
                        OutlinedButton(
                            onPressed: cancel,
                            child: const Text('Cancel action')),
                      TextButton(
                          onPressed: busy ? null : signOut,
                          child: const Text('Sign out')),
                    ]),
                  ],
                  if (busy) const LinearProgressIndicator(),
                  Semantics(liveRegion: true, child: Text(status)),
                ]))));
  }
}

class PrivatePreviewPlayer extends StatefulWidget {
  const PrivatePreviewPlayer({super.key, required this.create});
  final VideoPlayerController Function() create;
  @override
  State<PrivatePreviewPlayer> createState() => _PlayerState();
}

class _PlayerState extends State<PrivatePreviewPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? controller;
  bool loading = false, failed = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  void release() {
    generation++;
    final old = controller;
    controller = null;
    old?.removeListener(changed);
    if (old != null) {
      old.pause().catchError((Object _) {});
      old.dispose().catchError((Object _) {});
    }
  }

  Future<void> load() async {
    release();
    final run = generation;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final next = widget.create();
      controller = next;
      next.addListener(changed);
      await next.initialize().timeout(const Duration(seconds: 15));
      if (mounted && run == generation) setState(() => loading = false);
    } catch (_) {
      if (mounted && run == generation) {
        release();
        setState(() {
          failed = true;
          loading = false;
        });
      }
    }
  }

  Future<void> toggle() async {
    try {
      final c = controller!;
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        await c.play();
      }
    } catch (_) {
      release();
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed)
      controller?.pause().catchError((Object _) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final ready = !failed &&
        !(c?.value.hasError ?? false) &&
        (c?.value.isInitialized ?? false);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Private listing video'),
                  if (ready)
                    AspectRatio(
                        aspectRatio: c!.value.aspectRatio,
                        child: VideoPlayer(c)),
                  if (loading) const LinearProgressIndicator(),
                  if (failed || c?.value.hasError == true)
                    const Text(
                        'Video unavailable or session denied. Retry or sign in again.'),
                  Wrap(spacing: 8, children: [
                    FilledButton(
                        onPressed: loading
                            ? null
                            : ready
                                ? toggle
                                : load,
                        child: Text(ready
                            ? (c!.value.isPlaying
                                ? 'Pause private video'
                                : 'Play private video')
                            : 'Load private video')),
                    TextButton(
                        onPressed: () {
                          release();
                          setState(() {
                            loading = false;
                            failed = false;
                          });
                        },
                        child: const Text('Dismiss private video'))
                  ]),
                ])));
  }
}
