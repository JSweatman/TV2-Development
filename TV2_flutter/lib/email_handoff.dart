import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';

/// Conservative ASCII mailbox contract, not proof of ownership/deliverability.
/// Never accept a supplied mailto URL, display name, recipient list or headers.
Uri? emailDestination(ResourceRecord resource) {
  if (resource.type != 'email' ||
      resource.uri != null ||
      resource.metadata['handoff'] != 'device' ||
      resource.metadata.keys.any((k) => k != 'handoff' && k != 'address')) {
    return null;
  }
  final address = resource.metadata['address'];
  if (address is! String ||
      address.length > 254 ||
      RegExp(r'[^\x21-\x7E]').hasMatch(address)) return null;
  final parts = address.split('@');
  if (parts.length != 2 ||
      parts[0].length > 64 ||
      !RegExp(r'^[A-Za-z0-9_+\-]+(?:\.[A-Za-z0-9_+\-]+)*$')
          .hasMatch(parts[0])) {
    return null;
  }
  final labels = parts[1].split('.');
  if (labels.length < 2 ||
      labels.any((label) =>
          label.length > 63 ||
          !RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9\-]*[A-Za-z0-9])?$')
              .hasMatch(label)) ||
      !RegExp(r'^[A-Za-z]{2,63}$').hasMatch(labels.last)) return null;
  return Uri(scheme: 'mailto', path: address);
}

class EmailHandoff {
  EmailHandoff({Future<bool> Function(Uri)? open}) : _open = open ?? _launch;
  final Future<bool> Function(Uri) _open;
  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<void> request(BuildContext context, ResourceRecord resource) async {
    final destination = emailDestination(resource);
    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No valid email destination is configured.')));
      return;
    }
    var requested = false;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              scrollable: true,
              title: const Text('Open email app?'),
              content: Text(
                  '${destination.path}\nOpen a blank email addressed to this recipient. TV2 does not send it.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () async {
                      if (requested) return;
                      requested = true;
                      var opened = false;
                      try {
                        opened = await _open(destination);
                      } catch (_) {/* Manual fallback below. */}
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(opened
                              ? 'If no email app opened, compose an email to ${destination.path} manually.'
                              : 'No compatible email app opened. Use ${destination.path} manually.')));
                    },
                    child: const Text('Compose email')),
              ],
            ));
  }
}
