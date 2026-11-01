import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/core/services/pdf_service.dart';


class PrescriptionsPage extends ConsumerWidget {
  const PrescriptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'prescriptions'))),
      body: DocList(
        q: q('prescriptions', f1: 'patientId', v1: fs.uid),
        empty: 'No prescriptions yet.',
        builder: (c, p) => DocCard(
          title: '${p.s('doctorName')} · ${p.s('diagnosis')}',
          subtitle: p.l('medicines').map((m) => '${(m as Map)['name']}').join(', '),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => PrescriptionDetailPage(p))),
        ),
      ),
    );
  }
}

class PrescriptionDetailPage extends ConsumerWidget {
  const PrescriptionDetailPage(this.p, {super.key});
  final Doc p;

  Map<String, dynamic> _reminder(String uid, Map m) {
    final f = '${m['frequency']}';
    final days = (m['durationDays'] as num?)?.toInt() ?? 7;
    return {
      'userId': uid, 'name': '${m['name']}', 'dose': '${m['dose']}', 'source': 'prescription', 'prescriptionId': p.id,
      'morning': !f.startsWith('Night'), 'afternoon': f.startsWith('Three'), 'night': f.startsWith('Twice') || f.startsWith('Three') || f.startsWith('Night'),
      'startDate': todayKey(), 'endDate': dateKey(DateTime.now().add(Duration(days: days))),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    final meds = p.l('medicines').cast<Map>();
    return Scaffold(
      appBar: AppBar(title: const Text('Prescription')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Dr. ${p.s('doctorName')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text('${p.s('doctorSpecialty')} · BMDC ${p.s('doctorBmdc')}'),
        const SizedBox(height: 8),
        Text('Patient: ${p.s('patientName')}'),
        Text('Diagnosis: ${p.s('diagnosis')}'),
        const SizedBox(height: 12),
        for (final m in meds) Card(child: ListTile(title: Text('${m['name']} ${m['dose']}'), subtitle: Text('${m['frequency']} · ${m['durationDays']} days\n${m['instructions'] ?? ''}'))),
        if (p.s('notes').isNotEmpty) Text('Notes: ${p.s('notes')}'),
        if (p.s('followUp').isNotEmpty) Text('Follow-up: ${p.s('followUp')}'),
        const SizedBox(height: 16),
        FilledButton.icon(icon: const Icon(Icons.picture_as_pdf), label: const Text('View / print PDF'), onPressed: () => act(context, () => printPrescription(p))),
        const SizedBox(height: 8),
        OutlinedButton.icon(icon: const Icon(Icons.share), label: const Text('Share PDF'), onPressed: () => act(context, () => sharePrescription(p))),
        if (p.s('patientId') == fs.uid) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.alarm_add),
            label: const Text('Add medicines to reminders'),
            onPressed: () => act(context, () async {
              final b = fs.db.batch();
              for (final m in meds) {
                b.set(fs.db.collection('medicine_reminders').doc(), {..._reminder(fs.uid, m), 'createdAt': FirestoreService.now});
              }
              await b.commit();
            }, ok: 'Reminders added.'),
          ),
        ],
      ]),
    );
  }
}
