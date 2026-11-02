import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medicare_bd/core/core.dart';

const kFrequencies = ['Once daily (morning)', 'Twice daily (morning, night)', 'Three times daily', 'Night only'];

/// Doctor creates a prescription for one of their appointments. Issued prescriptions are immutable.
class PrescriptionWritePage extends ConsumerStatefulWidget {
  const PrescriptionWritePage({super.key, required this.appt});
  final Doc appt;

  @override
  ConsumerState<PrescriptionWritePage> createState() => _State();
}

class _State extends ConsumerState<PrescriptionWritePage> {
  final _form = GlobalKey<FormState>();
  final _dx = TextEditingController();
  final _notes = TextEditingController();
  final _meds = <Map<String, dynamic>>[];
  String? _followUp;
  bool _busy = false;

  @override
  void dispose() {
    _dx.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addMed() async {
    final v = await showFormSheet(context, 'Add medicine', const [
      FieldSpec('name', 'Medicine name'),
      FieldSpec('dose', 'Dosage (e.g. 500 mg)'),
      FieldSpec('frequency', 'Frequency', kind: FK.choice, options: kFrequencies),
      FieldSpec('durationDays', 'Duration (days)', kind: FK.number),
      FieldSpec('instructions', 'Instructions', required: false),
    ]);
    if (v != null) setState(() => _meds.add(v));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_meds.isEmpty) return snack(context, 'Add at least one medicine.');
    final fs = ref.read(fsProvider);
    final a = widget.appt;
    final doctor = await fs.get('doctors', fs.uid);
    if (!mounted) return;
    setState(() => _busy = true);
    final ok = await act(context, () => fs.add('prescriptions', {
          'appointmentId': a.id, 'patientId': a.s('patientId'), 'patientName': a.s('patientName'),
          'doctorId': fs.uid, 'doctorName': a.s('doctorName'), 'doctorSpecialty': doctor?.s('specialty') ?? '', 'doctorBmdc': doctor?.s('bmdc') ?? '',
          'diagnosis': _dx.text.trim(), 'medicines': _meds, 'notes': _notes.text.trim(), 'followUp': _followUp ?? '',
        }), ok: 'Prescription issued.');
    if (mounted) {
      setState(() => _busy = false);
      if (ok) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Prescription · ${widget.appt.s('patientName')}')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          TextFormField(controller: _dx, decoration: const InputDecoration(labelText: 'Diagnosis'), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          for (var i = 0; i < _meds.length; i++)
            Card(child: ListTile(
              title: Text('${_meds[i]['name']} ${_meds[i]['dose']}'),
              subtitle: Text('${_meds[i]['frequency']} · ${_meds[i]['durationDays']} days ${_meds[i]['instructions'] ?? ''}'),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _meds.removeAt(i))),
            )),
          OutlinedButton.icon(onPressed: _meds.length >= 15 ? null : _addMed, icon: const Icon(Icons.add), label: const Text('Add medicine')),
          const SizedBox(height: 12),
          TextFormField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes (optional)')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text(_followUp == null ? 'Follow-up date (optional)' : 'Follow-up: $_followUp'),
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 7)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _followUp = dateKey(d));
            },
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'Issue prescription')),
          const SizedBox(height: 8),
          const Text('Once issued, a prescription cannot be edited. Issue a new one to amend.', style: TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}
