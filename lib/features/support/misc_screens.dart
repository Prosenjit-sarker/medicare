import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/core/services/consultation_service.dart';

class SupportPage extends ConsumerWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'support'))),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New ticket'),
        onPressed: () async {
          final v = await showFormSheet(context, 'Contact support', const [
            FieldSpec('subject', 'Subject'),
            FieldSpec('message', 'Message (do not include passwords)', kind: FK.multiline),
          ]);
          if (v == null || !context.mounted) return;
          await act(
            context,
            () => fs.add('support_tickets', {...v, 'userId': fs.uid, 'status': 'open'}),
            ok: 'Ticket created.',
          );
        },
      ),
      body: DocList(
        q: q('support_tickets', f1: 'userId', v1: fs.uid),
        empty: 'No tickets.',
        builder: (c, t) => DocCard(
          title: t.s('subject'),
          subtitle: '${t.s('message')}${t.s('reply').isEmpty ? '' : '\n\nSupport: ${t.s('reply')}'}',
          trailing: StatusChip(t.s('status') == 'closed' ? 'completed' : 'pending'),
        ),
      ),
    );
  }
}

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DocList(
      q: q('announcements', limit: 30),
      empty: 'No announcements.',
      builder: (c, a) => DocCard(
        title: a.s('title'),
        subtitle:
            '${a.s('body')}\n${a.t('createdAt') == null ? '' : DateFormat('d MMM, h:mm a').format(a.t('createdAt')!)}',
      ),
    );
  }
}

/// Calling uses the phone dialer, so it works without internet. Numbers are built into the app.
class SosPage extends ConsumerWidget {
  const SosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    final me = ref.watch(docProvider((col: 'patients', id: fs.uid))).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'sos'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final n in kEmergencyNumbers)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  minimumSize: const Size.fromHeight(64),
                ),
                icon: const Icon(Icons.call),
                label: Text('${n.$1}: ${n.$2}', style: const TextStyle(fontSize: 18)),
                onPressed: () => callNumber(context, n.$2),
              ),
            ),
          if (me != null && me.s('emergencyPhone').isNotEmpty)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              icon: const Icon(Icons.contact_phone),
              label: Text('${me.s('emergencyName')}: ${me.s('emergencyPhone')}'),
              onPressed: () => callNumber(context, me.s('emergencyPhone')),
            ),
          const SizedBox(height: 16),
          const Text(
            'MediCare BD does not dispatch ambulances. Always call the numbers above in an emergency.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
