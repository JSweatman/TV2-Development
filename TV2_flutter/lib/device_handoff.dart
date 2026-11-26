import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';

/// Public, explicitly typed destinations only. Never derive from a List Number.
/// This validates E.164 syntax, not assignment, ownership or consent.
Uri? deviceDestination(ResourceRecord resource) {
  if (resource.type != 'call' && resource.type != 'text') return null;
  if (resource.metadata['handoff'] != 'device') return null;
  final number = resource.metadata['phone_e164'];
  if (number is! String || !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(number)) {
    return null;
  }
  return Uri(scheme: resource.type == 'call' ? 'tel' : 'sms', path: number);
}

class DeviceHandoff {
  DeviceHandoff({Future<bool> Function(Uri)? open}) : _open = open ?? _launch;
  final Future<bool> Function(Uri) _open;
  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<void> request(BuildContext context, ResourceRecord? resource,
      {bool Function()? stillCurrent}) async {
    final destination = resource == null ? null : deviceDestination(resource);
    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No valid device destination is configured.')));
      return;
    }
    // A second deliberate gesture names the external handoff and destination.
    // The platform receives no message body and TV2 never calls/sends itself.
    var requested = false;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              scrollable: true,
              title: Text(resource!.type == 'call'
                  ? 'Open phone app?'
                  : 'Open messaging app?'),
              content: Text(
                  '${destination.path}\nContinue in your device app. If it does not open, use this number manually.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () async {
                      if (requested) return;
                      if (stillCurrent != null && !stillCurrent()) {
                        Navigator.pop(dialogContext);
                        return;
                      }
                      requested = true;
                      var opened = false;
                      try {
                        opened = await _open(destination);
                      } catch (_) {/* Fall back below. */}
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(opened
                              ? 'If no app opened, use ${destination.path} in your phone or messaging app.'
                              : 'No compatible app opened. Use ${destination.path} manually.')));
                    },
                    child: const Text('Open device app')),
              ],
            ));
  }
}
