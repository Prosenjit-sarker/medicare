import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/core/services/supabase_storage_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<Uint8List> buildPrescriptionPdf(Doc p) async {
  final meds = p.l('medicines').cast<Map>();
  final pdf = pw.Document();
  pdf.addPage(
    pw.MultiPage(
      build: (_) => [
        pw.Text('MediCare BD', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.Text('Digital Prescription'),
        pw.Divider(),
        pw.Text('Doctor: ${p.s('doctorName')}  (${p.s('doctorSpecialty')})'),
        pw.Text('Patient: ${p.s('patientName')}'),
        pw.Text('Date: ${p.t('createdAt')?.toIso8601String().substring(0, 10) ?? ''}'),
        pw.SizedBox(height: 10),
        pw.Text('Diagnosis: ${p.s('diagnosis')}'),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headers: ['Medicine', 'Dose', 'Frequency', 'Days', 'Instructions'],
          data: [
            for (final m in meds)
              [
                '${m['name']}',
                '${m['dose']}',
                '${m['frequency']}',
                '${m['durationDays']}',
                '${m['instructions'] ?? ''}',
              ],
          ],
        ),
        pw.SizedBox(height: 10),
        if (p.s('notes').isNotEmpty) pw.Text('Notes: ${p.s('notes')}'),
        if (p.s('followUp').isNotEmpty) pw.Text('Follow-up: ${p.s('followUp')}'),
        pw.SizedBox(height: 20),
        pw.Text(
          'This prescription is immutable. Amendments are issued as a new prescription.',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    ),
  );
  return pdf.save();
}

Future<void> _savePrescriptionPdf(Doc prescription, Uint8List bytes) async {
  final currentUid = FirebaseAuth.instance.currentUser!.uid;
  final otherPartyUid = currentUid == prescription.s('patientId')
      ? prescription.s('doctorId')
      : prescription.s('patientId');
  await SupabaseStorageService.instance.savePrescriptionPdf(
    ownerUid: currentUid,
    prescriptionId: prescription.id,
    otherPartyUid: otherPartyUid,
    bytes: bytes,
  );
}

Future<void> printPrescription(Doc p) async {
  final bytes = await buildPrescriptionPdf(p);
  await _savePrescriptionPdf(p, bytes);
  await Printing.layoutPdf(onLayout: (_) async => bytes);
}

Future<void> sharePrescription(Doc p) async {
  final bytes = await buildPrescriptionPdf(p);
  await _savePrescriptionPdf(p, bytes);
  await Printing.sharePdf(bytes: bytes, filename: 'prescription_${p.id}.pdf');
}
