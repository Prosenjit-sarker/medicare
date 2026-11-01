import 'package:flutter/material.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:url_launcher/url_launcher.dart';

/// Consultation access behind one function so Jitsi can be swapped for Agora later.
/// The room name contains a random key that only the appointment's patient and doctor can read.
/// Real token-based access control needs a backend (Blaze plan); see README.
Future<void> joinConsultation(BuildContext context, Doc appt, {bool audioOnly = false}) async {
  final room = 'medicarebd-${appt.id}-${appt.s('roomKey')}';
  final cfg = audioOnly ? '#config.startWithVideoMuted=true' : '';
  final ok = await launchUrl(Uri.parse('https://meet.jit.si/$room$cfg'), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) snack(context, 'Could not open the consultation room.');
}

Future<void> callNumber(BuildContext context, String number) async {
  final ok = await launchUrl(Uri(scheme: 'tel', path: number));
  if (!ok && context.mounted) snack(context, 'Could not start the call.');
}
