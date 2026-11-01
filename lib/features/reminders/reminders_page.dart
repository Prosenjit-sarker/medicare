import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';

const _slots = ['morning', 'afternoon', 'night'];

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    final today = todayKey();
    final reminders = ref.watch(docsProvider(q('medicine_reminders', f1: 'userId', v1: fs.uid, limit: 100))).valueOrNull ?? [];
    final logs = {for (final l in ref.watch(docsProvider(q('reminder_logs', f1: 'userId', v1: fs.uid, f2: 'date', v2: today, limit: 100))).valueOrNull ?? []) l.id: l.s('status')};
    final active = reminders.where((r) => r.s('endDate').isEmpty || r.s('endDate').compareTo(today) >= 0).toList();

    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'reminders'))),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_alarm),
        label: const Text('Add'),
        onPressed: () async {
          final v = await showFormSheet(context, 'New reminder', [
            const FieldSpec('name', 'Medicine name'),
            const FieldSpec('dose', 'Dose (e.g. 1 tablet)'),
            const FieldSpec('morning', 'Morning (8:00)', kind: FK.flag),
            const FieldSpec('afternoon', 'Afternoon (2:00 PM)', kind: FK.flag),
            const FieldSpec('night', 'Night (9:00 PM)', kind: FK.flag),
            FieldSpec('startDate', 'Start date', kind: FK.date, initial: today),
            const FieldSpec('endDate', 'End date', kind: FK.date, required: false),
            const FieldSpec('refillDate', 'Refill reminder date', kind: FK.date, required: false),
          ]);
          if (v == null || !context.mounted) return;
          if (!(v['morning'] == true || v['afternoon'] == true || v['night'] == true)) return snack(context, 'Pick at least one time.');
          await act(context, () => fs.add('medicine_reminders', {...v, 'userId': fs.uid, 'source': 'manual'}), ok: 'Reminder saved.');
        },
      ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        const Padding(padding: EdgeInsets.all(8), child: Text("Today", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        if (active.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('No active reminders.')),
        for (final r in active)
          for (final s in _slots.where((s) => r.b(s)))
            Builder(builder: (c) {
              final id = '${r.id}_${today}_$s';
              final st = logs[id];
              return DocCard(
                title: '${r.s('name')} · ${r.s('dose')}',
                subtitle: s,
                trailing: st == null ? null : StatusChip(st == 'taken' ? 'completed' : 'cancelled'),
                actions: [
                  ActionChip(label: const Text('Taken'), onPressed: () => act(c, () => fs.set('reminder_logs', id, {'userId': fs.uid, 'reminderId': r.id, 'name': r.s('name'), 'slot': s, 'date': today, 'status': 'taken'}))),
                  ActionChip(label: const Text('Skipped'), onPressed: () => act(c, () => fs.set('reminder_logs', id, {'userId': fs.uid, 'reminderId': r.id, 'name': r.s('name'), 'slot': s, 'date': today, 'status': 'skipped'}))),
                ],
              );
            }),
        const Padding(padding: EdgeInsets.all(8), child: Text('All reminders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        for (final r in reminders)
          DocCard(
            title: '${r.s('name')} · ${r.s('dose')}',
            subtitle: '${_slots.where((s) => r.b(s)).join(', ')}\n${r.s('startDate')} → ${r.s('endDate').isEmpty ? 'ongoing' : r.s('endDate')}${r.s('refillDate').isEmpty ? '' : '\nRefill on ${r.s('refillDate')}${r.s('refillDate').compareTo(dateKey(DateTime.now().add(const Duration(days: 3)))) <= 0 ? '  (soon)' : ''}'}',
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => act(context, () => fs.delete('medicine_reminders', r.id))),
          ),
        const SizedBox(height: 60),
        const Padding(padding: EdgeInsets.all(8), child: Text('Reminders are scheduled on this device and work offline. This app never suggests doses; follow your doctor.', style: TextStyle(fontSize: 12))),
      ]),
    );
  }
}
