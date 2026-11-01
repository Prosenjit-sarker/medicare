import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/core/services/analytics_service.dart';
import 'package:medicare_bd/features/auth/presentation/auth_providers.dart';
import 'package:medicare_bd/features/doctors/reviews_section.dart';

import 'appointment_repository.dart';

class BookingPage extends ConsumerStatefulWidget {
  const BookingPage({super.key, required this.doctorId});
  final String doctorId;

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String? _slot;
  String _type = 'online';
  bool _busy = false;

  Future<void> _pick() async {
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
    if (d != null) setState(() { _date = d; _slot = null; });
  }

  Future<void> _confirm(Doc doc) async {
    setState(() => _busy = true);
    try {
      await ref.read(appointmentRepositoryProvider).book(
            patientId: FirebaseAuth.instance.currentUser!.uid,
            patientName: ref.read(appUserProvider).valueOrNull?.name ?? '',
            doctor: doc, date: dateKey(_date), slot: _slot!, type: _type,
          );
      await ref.read(analyticsProvider).onAppointmentBooked();
      if (!mounted) return;
      snack(context, 'Appointment booked.');
      context.go('/');
    } on SlotTakenException {
      if (mounted) { setState(() => _slot = null); snack(context, 'That slot was just taken. Pick another.'); }
    } catch (_) {
      if (mounted) snack(context, 'Booking failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = ref.watch(docProvider((col: 'doctors', id: widget.doctorId)));
    final date = dateKey(_date);
    final taken = (ref.watch(docsProvider(q('appointment_slots', f1: 'doctorId', v1: widget.doctorId, f2: 'date', v2: date, limit: 100))).valueOrNull ?? []).map((e) => e.s('slot')).toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Book appointment')),
      body: doctor.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load doctor.')),
        data: (d) {
          if (d == null || d.s('status') != 'verified') return const Center(child: Text('Doctor not available.'));
          final days = d.l('days');
          final worksToday = days.isEmpty || days.contains(DateFormat('E', 'en').format(_date));
          final all = genSlots(d.s('startTime').isEmpty ? '09:00' : d.s('startTime'), d.s('endTime').isEmpty ? '13:00' : d.s('endTime'), d.n('slotMinutes') == 0 ? 30 : d.n('slotMinutes').toInt());
          final now = DateTime.now();
          final slots = all.where((s) => !(date == todayKey() && s.compareTo(DateFormat('HH:mm').format(now)) <= 0)).toList();
          return ListView(padding: const EdgeInsets.all(20), children: [
            Card(child: ListTile(title: Text(d.s('name')), subtitle: Text('${d.s('specialty')} · ${d.s('qualifications')}\nBMDC ${d.s('bmdc')} · ${d.n('experience')} yrs'), isThreeLine: true, trailing: Text('৳${d.n('fee')}', style: const TextStyle(fontWeight: FontWeight.w800)))),
            ReviewsSection(targetId: d.id, targetType: 'doctor', canReview: false),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'online', label: Text('Online')), ButtonSegment(value: 'offline', label: Text('In person'))],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.calendar_today), label: Text(DateFormat('EEE, d MMM yyyy').format(_date))),
            const SizedBox(height: 16),
            if (!worksToday) const Text('The doctor does not see patients on this day.') else if (slots.isEmpty) const Text('No slots left today.') else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in slots) ChoiceChip(label: Text(s), selected: _slot == s, onSelected: taken.contains(s) ? null : (_) => setState(() => _slot = s)),
              ]),
            const SizedBox(height: 24),
            FilledButton(onPressed: (_slot == null || _busy) ? null : () => _confirm(d), child: Text(_busy ? 'Booking...' : 'Confirm booking')),
            const SizedBox(height: 8),
            const Text('Pay after booking from the Visits tab (manual bKash/Nagad/Rocket verification).', style: TextStyle(fontSize: 12)),
          ]);
        },
      ),
    );
  }
}
