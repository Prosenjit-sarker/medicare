import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';

/// Digital medical records (metadata + notes). File uploads (PDF / X-ray / MRI) need Cloud Storage,
/// which requires the Blaze plan, so they are intentionally not included in the free build.
class RecordsPage extends ConsumerWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'records'))),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add record'),
        onPressed: () async {
          final v = await showFormSheet(context, 'New medical record', const [
            FieldSpec('title', 'Title'),
            FieldSpec('type', 'Type', kind: FK.choice, options: ['Blood test', 'X-ray', 'MRI / CT', 'Prescription', 'Discharge summary', 'Other']),
            FieldSpec('date', 'Date', kind: FK.date),
            FieldSpec('notes', 'Result / notes', kind: FK.multiline),
          ]);
          if (v == null || !context.mounted) return;
          await act(context, () => fs.add('medical_records', {...v, 'patientId': fs.uid, 'sharedWith': <String>[], 'deleted': false}), ok: 'Record saved.');
        },
      ),
      body: DocList(
        q: q('medical_records', f1: 'patientId', v1: fs.uid, limit: 100),
        empty: 'No records yet.',
        filter: (r) => !r.b('deleted'),
        builder: (c, r) => DocCard(
          title: r.s('title'),
          subtitle: '${r.s('type')} · ${r.s('date')}\n${r.s('notes')}\nShared with ${r.l('sharedWith').length} doctor(s)',
          actions: [
            ActionChip(avatar: const Icon(Icons.share, size: 18), label: const Text('Share with doctor'), onPressed: () => _share(c, ref, r)),
            ActionChip(avatar: const Icon(Icons.delete_outline, size: 18), label: const Text('Delete'), onPressed: () async {
              if (await confirm(c, 'Delete this record?') && c.mounted) await act(c, () => fs.update('medical_records', r.id, {'deleted': true}), ok: 'Deleted.');
            }),
          ],
        ),
      ),
    );
  }

  /// Consent: the patient explicitly picks doctors they have an appointment with.
  Future<void> _share(BuildContext c, WidgetRef ref, Doc r) async {
    final fs = ref.read(fsProvider);
    final appts = await fs.db.collection('appointments').where('patientId', isEqualTo: fs.uid).limit(100).get();
    final doctors = <String, String>{for (final a in appts.docs) a['doctorId'] as String: a['doctorName'] as String};
    if (!c.mounted) return;
    if (doctors.isEmpty) return snack(c, 'Book an appointment first, then you can share with that doctor.');
    final v = await showFormSheet(c, 'Share "${r.s('title')}"', [
      FieldSpec('doctors', 'Doctors who can view this record', kind: FK.multi, options: doctors.values.toList(), required: false, initial: [for (final id in r.l('sharedWith')) if (doctors[id] != null) doctors[id]!]),
    ]);
    if (v == null || !c.mounted) return;
    final names = Set<String>.from(v['doctors'] as List);
    final ids = [for (final e in doctors.entries) if (names.contains(e.value)) e.key];
    await act(c, () => fs.update('medical_records', r.id, {'sharedWith': ids}), ok: 'Sharing updated.');
  }
}
