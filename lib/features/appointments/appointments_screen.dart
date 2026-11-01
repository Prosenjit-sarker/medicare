import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/core/services/consultation_service.dart';
import 'package:medicare_bd/core/services/payment_gateway.dart';
import 'package:medicare_bd/features/doctors/reviews_section.dart';

import 'appointment_repository.dart';

class AppointmentsPage extends ConsumerWidget {
  const AppointmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    const gateway = ManualMfsGateway();
    return DocList(
      q: q('appointments', f1: 'patientId', v1: fs.uid, limit: 60),
      empty: 'No appointments yet.',
      builder: (c, a) => DocCard(
        title: a.s('doctorName'),
        subtitle: '${a.s('date')} · ${a.s('slot')} · ${a.s('type')}\nFee ৳${a.n('fee')} · ${a.s('paymentStatus')}${a.s('doctorNotes').isEmpty ? '' : '\nNotes: ${a.s('doctorNotes')}'}',
        trailing: StatusChip(a.s('status')),
        actions: [
          if (a.s('status') == 'booked' && a.s('type') == 'online') ...[
            ActionChip(avatar: const Icon(Icons.videocam, size: 18), label: const Text('Video'), onPressed: () => joinConsultation(c, a)),
            ActionChip(avatar: const Icon(Icons.call, size: 18), label: const Text('Audio'), onPressed: () => joinConsultation(c, a, audioOnly: true)),
          ],
          if (a.s('status') != 'cancelled') ActionChip(avatar: const Icon(Icons.chat, size: 18), label: const Text('Chat'), onPressed: () => c.push('/chat/${a.id}')),
          if (a.s('status') == 'booked' && a.s('paymentStatus') == 'unpaid')
            ActionChip(
              avatar: const Icon(Icons.payments, size: 18),
              label: const Text('Pay'),
              onPressed: () async {
                final v = await showFormSheet(c, 'Payment (৳${a.n('fee')})', [
                  FieldSpec('method', 'Method', kind: FK.choice, options: gateway.methods),
                  const FieldSpec('trxId', 'Transaction ID (for bKash/Nagad/Rocket)', required: false),
                ]);
                if (v == null || !c.mounted) return;
                if (gateway.requiresTransactionId(v['method'] as String) && (v['trxId'] ?? '').toString().isEmpty) {
                  snack(c, 'Transaction ID is required.');
                  return;
                }
                await act(c, () => fs.add('payments', {'kind': 'appointment', 'refId': a.id, 'patientId': fs.uid, 'amount': a.n('fee'), 'method': v['method'], 'trxId': v['trxId'] ?? '', 'status': 'submitted'}),
                    ok: 'Payment submitted. An admin will verify it.');
              },
            ),
          if (a.s('status') == 'booked')
            ActionChip(avatar: const Icon(Icons.cancel, size: 18), label: const Text('Cancel'), onPressed: () async {
              if (await confirm(c, 'Cancel this appointment?') && c.mounted) {
                await act(c, () => ref.read(appointmentRepositoryProvider).cancel(a), ok: 'Cancelled.');
              }
            }),
          if (a.s('status') == 'completed') ...[
            ActionChip(avatar: const Icon(Icons.description, size: 18), label: const Text('Prescription'), onPressed: () => c.push('/prescriptions')),
            ActionChip(avatar: const Icon(Icons.star, size: 18), label: const Text('Review'), onPressed: () => showDialog(context: c, builder: (_) => AlertDialog(content: ReviewsSection(targetId: a.s('doctorId'), targetType: 'doctor')))),
          ],
        ],
      ),
    );
  }
}
