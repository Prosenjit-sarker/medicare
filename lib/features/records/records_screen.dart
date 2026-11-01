import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/core/services/supabase_storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
        onPressed: () => _addRecord(context, ref),
      ),
      body: DocList(
        q: q('medical_records', f1: 'patientId', v1: fs.uid, limit: 100),
        empty: 'No records yet.',
        filter: (r) => !r.b('deleted'),
        builder: (c, r) => DocCard(
          title: r.s('title'),
          subtitle:
              '${r.s('type')} · ${r.s('date')}\n${r.s('notes')}'
              '${r.s('attachmentName').isEmpty ? '' : '\nAttachment: ${r.s('attachmentName')}'}'
              '\nShared with ${r.l('sharedWith').length} doctor(s)',
          actions: [
            if (r.s('attachmentPath').isNotEmpty)
              ActionChip(
                avatar: const Icon(Icons.attach_file, size: 18),
                label: const Text('Open attachment'),
                onPressed: () => _openAttachment(c, r.s('attachmentPath')),
              ),
            ActionChip(
              avatar: const Icon(Icons.share, size: 18),
              label: const Text('Share with doctor'),
              onPressed: () => _share(c, ref, r),
            ),
            ActionChip(
              avatar: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
              onPressed: () async {
                if (await confirm(c, 'Delete this record?') && c.mounted) {
                  await act(
                    c,
                    () => fs.update('medical_records', r.id, {'deleted': true}),
                    ok: 'Deleted.',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addRecord(BuildContext context, WidgetRef ref) async {
    final fs = ref.read(fsProvider);
    final values = await showFormSheet(context, 'New medical record', const [
      FieldSpec('title', 'Title'),
      FieldSpec(
        'type',
        'Type',
        kind: FK.choice,
        options: [
          'Blood test',
          'X-ray',
          'MRI / CT',
          'Prescription',
          'Discharge summary',
          'Other',
        ],
      ),
      FieldSpec('date', 'Date', kind: FK.date),
      FieldSpec('notes', 'Result / notes', kind: FK.multiline),
    ]);
    if (values == null || !context.mounted) return;

    final attach = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attach a file?'),
        content: const Text('You can add a PDF or image, up to 20 MB.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.attach_file),
            label: const Text('Choose file'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;

    PlatformFile? attachment;
    if (attach == true) {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );
      if (!context.mounted) return;
      attachment = result.singleOrNull;
    }

    Uint8List? bytes;
    if (attachment != null) {
      try {
        bytes = await attachment.readAsBytes();
      } catch (error) {
        if (context.mounted) {
          snack(context, 'Could not read the selected file: $error');
        }
        return;
      }
      if (!context.mounted) return;
      if (bytes.length > SupabaseStorageService.maxMedicalFileBytes) {
        snack(context, 'Choose a file smaller than 20 MB.');
        return;
      }
    }

    await act(context, () async {
      String? attachmentPath;
      if (attachment != null && bytes != null) {
        attachmentPath = await SupabaseStorageService.instance
            .uploadMedicalFile(
              ownerUid: fs.uid,
              fileName: attachment.name,
              bytes: bytes,
              contentType: SupabaseStorageService.instance.contentTypeFor(
                attachment.name,
              ),
            );
      }
      try {
        await fs.add('medical_records', {
          ...values,
          'patientId': fs.uid,
          'sharedWith': <String>[],
          'deleted': false,
          if (attachment != null) 'attachmentName': attachment.name,
          if (attachment != null) 'attachmentPath': attachmentPath,
          if (attachment != null)
            'attachmentType': SupabaseStorageService.instance.contentTypeFor(
              attachment.name,
            ),
        });
      } catch (_) {
        if (attachmentPath != null) {
          try {
            await SupabaseStorageService.instance.deleteMedicalFile(
              attachmentPath,
            );
          } catch (_) {}
        }
        rethrow;
      }
    }, ok: 'Record saved.');
  }

  Future<void> _openAttachment(BuildContext context, String path) async {
    try {
      final url = await SupabaseStorageService.instance.createMedicalFileUrl(
        path,
      );
      if (context.mounted) await launchUrl(Uri.parse(url));
    } catch (error) {
      if (context.mounted) snack(context, 'Could not open file: $error');
    }
  }

  /// Consent: the patient explicitly picks doctors they have an appointment with.
  Future<void> _share(BuildContext c, WidgetRef ref, Doc r) async {
    final fs = ref.read(fsProvider);
    final appts = await fs.db
        .collection('appointments')
        .where('patientId', isEqualTo: fs.uid)
        .limit(100)
        .get();
    final doctors = <String, String>{
      for (final a in appts.docs)
        a['doctorId'] as String: a['doctorName'] as String,
    };
    if (!c.mounted) return;
    if (doctors.isEmpty) {
      return snack(
        c,
        'Book an appointment first, then you can share with that doctor.',
      );
    }
    final v = await showFormSheet(c, 'Share "${r.s('title')}"', [
      FieldSpec(
        'doctors',
        'Doctors who can view this record',
        kind: FK.multi,
        options: doctors.values.toList(),
        required: false,
        initial: [
          for (final id in r.l('sharedWith'))
            if (doctors[id] != null) doctors[id]!,
        ],
      ),
    ]);
    if (v == null || !c.mounted) return;
    final names = Set<String>.from(v['doctors'] as List);
    final ids = [
      for (final e in doctors.entries)
        if (names.contains(e.value)) e.key,
    ];
    final oldIds = List<String>.from(r.l('sharedWith'));
    await act(c, () async {
      final path = r.s('attachmentPath');
      if (path.isNotEmpty) {
        await SupabaseStorageService.instance.setMedicalFileShares(path, ids);
      }
      try {
        await fs.update('medical_records', r.id, {'sharedWith': ids});
      } catch (_) {
        if (path.isNotEmpty) {
          await SupabaseStorageService.instance.setMedicalFileShares(
            path,
            oldIds,
          );
        }
        rethrow;
      }
    }, ok: 'Sharing updated.');
  }
}
