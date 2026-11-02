import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/core/services/consultation_service.dart';
import 'package:medicare_bd/core/services/supabase_storage_service.dart';
import 'package:medicare_bd/features/appointments/appointment_repository.dart';
import 'package:medicare_bd/features/doctors/doctor_schedule.dart';
import 'package:medicare_bd/features/providers/provider_kinds.dart';
import 'package:url_launcher/url_launcher.dart';

import 'reviews_section.dart';

class DoctorDashboard extends ConsumerWidget {
  const DoctorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.read(fsProvider).uid;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Doctor dashboard'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Appointments'),
              Tab(text: 'Patients'),
              Tab(text: 'Shared records'),
              Tab(text: 'Articles'),
              Tab(text: 'Profile'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Appointments(uid),
            _Patients(uid),
            DocList(
              q: q('medical_records', f1: 'sharedWith', v1: uid, arr: true),
              empty: 'No records shared with you.',
              filter: (r) => !r.b('deleted'),
              builder: (c, r) => DocCard(
                title: r.s('title'),
                subtitle: '${r.s('type')} · ${r.s('date')}\n${r.s('notes')}',
                actions: [
                  if (r.s('attachmentPath').isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.attach_file, size: 18),
                      label: const Text('Open attachment'),
                      onPressed: () async {
                        try {
                          final url = await SupabaseStorageService.instance.createMedicalFileUrl(r.s('attachmentPath'));
                          if (c.mounted) await launchUrl(Uri.parse(url));
                        } catch (error) {
                          if (c.mounted) {
                            snack(c, 'Could not open file: $error');
                          }
                        }
                      },
                    ),
                ],
              ),
            ),
            _Articles(uid),
            _ProfileTab(uid),
          ],
        ),
      ),
    );
  }
}

class _Appointments extends ConsumerWidget {
  const _Appointments(this.uid);
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DocList(
      q: q('appointments', f1: 'doctorId', v1: uid, limit: 100),
      empty: 'No appointments yet.',
      builder: (c, a) => DocCard(
        title: a.s('patientName'),
        subtitle: '${a.s('date')} · ${a.s('slot')} · ${a.s('type')} · ${a.s('paymentStatus')}',
        trailing: StatusChip(a.s('status')),
        actions: [
          if (a.s('status') == 'booked' && a.s('type') == 'online')
            ActionChip(label: const Text('Start call'), onPressed: () => joinConsultation(c, a)),
          if (a.s('status') != 'cancelled')
            ActionChip(label: const Text('Chat'), onPressed: () => c.push('/chat/${a.id}')),
          if (a.s('status') == 'booked')
            ActionChip(
              label: const Text('Complete'),
              onPressed: () async {
                final v = await showFormSheet(c, 'Consultation notes', const [
                  FieldSpec('notes', 'Notes', kind: FK.multiline),
                ]);
                if (v != null && c.mounted) {
                  await act(
                    c,
                    () => ref.read(appointmentRepositoryProvider).complete(a, v['notes'] as String),
                    ok: 'Marked completed.',
                  );
                }
              },
            ),
          if (a.s('status') == 'completed')
            ActionChip(
              label: const Text('Prescribe'),
              onPressed: () => c.push('/prescribe', extra: a),
            ),
          if (a.s('status') == 'booked')
            ActionChip(
              label: const Text('Cancel'),
              onPressed: () async {
                if (await confirm(c, 'Cancel this appointment?') && c.mounted) {
                  await act(c, () => ref.read(appointmentRepositoryProvider).cancel(a), ok: 'Cancelled.');
                }
              },
            ),
        ],
      ),
    );
  }
}

/// Patients are derived from the doctor's own appointments, so a doctor only sees people they treat.
class _Patients extends ConsumerWidget {
  const _Patients(this.uid);
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(docsProvider(q('appointments', f1: 'doctorId', v1: uid, limit: 200))).valueOrNull ?? [];
    final byPatient = <String, List<Doc>>{};
    for (final a in all) {
      byPatient.putIfAbsent(a.s('patientId'), () => []).add(a);
    }
    if (byPatient.isEmpty) return const Center(child: Text('No patients yet.'));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final e in byPatient.entries)
          DocCard(
            title: e.value.first.s('patientName'),
            subtitle:
                '${e.value.length} visit(s) · last ${e.value.map((x) => x.s('date')).reduce((a, b) => a.compareTo(b) > 0 ? a : b)}',
          ),
      ],
    );
  }
}

class _Articles extends ConsumerWidget {
  const _Articles(this.uid);
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.edit),
        label: const Text('Write article'),
        onPressed: () async {
          final v = await showFormSheet(context, 'New article (reviewed before publishing)', const [
            FieldSpec('title', 'Title'),
            FieldSpec(
              'category',
              'Category',
              kind: FK.choice,
              options: ['General', 'Heart', 'Diabetes', 'Child health', 'Women health', 'Nutrition', 'Mental health'],
            ),
            FieldSpec('body', 'Article', kind: FK.multiline),
          ]);
          if (v == null || !context.mounted) return;
          PlatformFile? image;
          try {
            image = await _chooseArticleImage(context);
          } catch (error) {
            if (context.mounted) {
              snack(context, 'Could not select image: $error');
            }
            return;
          }
          if (!context.mounted) return;
          Uint8List? imageBytes;
          if (image != null) {
            imageBytes = await image.readAsBytes();
            if (!context.mounted) return;
            if (imageBytes.length > SupabaseStorageService.maxDoctorAvatarBytes) {
              snack(context, 'Choose an image smaller than 5 MB.');
              return;
            }
          }
          final me = await fs.get('doctors', fs.uid);
          if (!context.mounted) return;
          await act(context, () async {
            String? imagePath;
            try {
              final uploaded = image != null && imageBytes != null
                  ? await SupabaseStorageService.instance.uploadCatalogImage(
                      ownerUid: uid,
                      fileName: image.name,
                      bytes: imageBytes,
                      contentType: SupabaseStorageService.instance.contentTypeFor(image.name),
                    )
                  : null;
              imagePath = uploaded?.path;
              await fs.add('health_articles', {
                ...v,
                if (uploaded != null) 'imageUrl': uploaded.url,
                if (uploaded != null) 'imagePath': uploaded.path,
                'authorId': uid,
                'authorName': me?.s('name') ?? '',
                'status': 'pending',
                'featured': false,
              });
            } catch (_) {
              if (imagePath != null) {
                try {
                  await SupabaseStorageService.instance.deleteCatalogImage(imagePath);
                } catch (_) {}
              }
              rethrow;
            }
          }, ok: 'Sent for review.');
        },
      ),
      body: DocList(
        q: q('health_articles', f1: 'authorId', v1: uid),
        empty: 'You have not written any articles.',
        builder: (c, a) => DocCard(title: a.s('title'), subtitle: a.s('category'), trailing: StatusChip(a.s('status'))),
      ),
    );
  }
}

Future<PlatformFile?> _chooseArticleImage(BuildContext context) async {
  final chooseImage = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add an article image?'),
      content: const Text('Choose an optional image, up to 5 MB.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Skip')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.image_outlined),
          label: const Text('Choose image'),
        ),
      ],
    ),
  );
  if (chooseImage != true) return null;
  final files = await FilePicker.pickFiles(type: FileType.image);
  return files.singleOrNull;
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab(this.uid);
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    final appts = ref.watch(docsProvider(q('appointments', f1: 'doctorId', v1: uid, limit: 300))).valueOrNull ?? [];
    final earned = appts.where((a) => a.s('paymentStatus') == 'paid').fold<num>(0, (s, a) => s + a.n('fee'));
    final done = appts.where((a) => a.s('status') == 'completed').length;
    return Column(
      children: [
        Expanded(child: ProviderProfileCard(kProviderKinds['doctor']!)),
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Earnings (verified payments): ৳$earned · $done completed',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ReviewsSection(targetId: uid, targetType: 'doctor', canReview: false),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final current = await fs.get('doctors', uid);
                        if (!context.mounted) return;
                        final settings = await showDialog<_AvailabilitySettings>(
                          context: context,
                          builder: (_) => _DoctorAvailabilityDialog(
                            initialSchedule: doctorWeeklySchedule(current ?? const Doc('', {})),
                            initialSlotMinutes: current?.n('slotMinutes').toInt() ?? 30,
                          ),
                        );
                        if (settings == null || !context.mounted) return;
                        final days = kWeekdays.where(settings.weeklySchedule.containsKey).toList();
                        if (days.isEmpty) {
                          snack(context, 'Select at least one working day.');
                          return;
                        }
                        final firstHours = settings.weeklySchedule[days.first]!;
                        await act(
                          context,
                          () => fs.update('doctors', uid, {
                            'weeklySchedule': settings.weeklySchedule,
                            'days': days,
                            'startTime': firstHours['startTime'],
                            'endTime': firstHours['endTime'],
                            'slotMinutes': settings.slotMinutes,
                          }),
                          ok: 'Schedule saved.',
                        );
                      },
                      child: const Text('Edit availability'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final hospitals = await fs.db
                            .collection('hospitals')
                            .where('status', isEqualTo: 'verified')
                            .limit(30)
                            .get();
                        if (!context.mounted) return;
                        final pick = await showDialog<QueryDocumentSnapshot<Map<String, dynamic>>>(
                          context: context,
                          builder: (_) => SimpleDialog(
                            title: const Text('Request affiliation'),
                            children: [
                              for (final h in hospitals.docs)
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(context, h),
                                  child: Text('${h['name']}'),
                                ),
                              if (hospitals.docs.isEmpty)
                                const Padding(padding: EdgeInsets.all(12), child: Text('No verified hospitals yet.')),
                            ],
                          ),
                        );
                        if (pick == null || !context.mounted) return;
                        final me = await fs.get('doctors', uid);
                        if (!context.mounted) return;
                        await act(
                          context,
                          () => fs.set('affiliation_requests', '${pick.id}_$uid', {
                            'doctorId': uid,
                            'doctorName': me?.s('name') ?? '',
                            'hospitalId': pick.id,
                            'hospitalName': pick['name'],
                            'status': 'pending',
                          }),
                          ok: 'Request sent.',
                        );
                      },
                      child: const Text('Request hospital affiliation'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

typedef _AvailabilitySettings = ({Map<String, Map<String, String>> weeklySchedule, int slotMinutes});

class _DoctorAvailabilityDialog extends StatefulWidget {
  const _DoctorAvailabilityDialog({required this.initialSchedule, required this.initialSlotMinutes});

  final Map<String, Map<String, String>> initialSchedule;
  final int initialSlotMinutes;

  @override
  State<_DoctorAvailabilityDialog> createState() => _DoctorAvailabilityDialogState();
}

class _DoctorAvailabilityDialogState extends State<_DoctorAvailabilityDialog> {
  late final Map<String, Map<String, String>> _schedule = {
    for (final entry in widget.initialSchedule.entries) entry.key: Map.of(entry.value),
  };
  late int _slotMinutes = [15, 20, 30, 45, 60].contains(widget.initialSlotMinutes) ? widget.initialSlotMinutes : 30;

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _storeTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(String day, String field) async {
    final current = _schedule[day]![field]!;
    final picked = await showTimePicker(context: context, initialTime: _parseTime(current));
    if (picked == null) return;
    setState(() => _schedule[day]![field] = _storeTime(picked));
  }

  void _save() {
    for (final entry in _schedule.entries) {
      if (entry.value['startTime']!.compareTo(entry.value['endTime']!) >= 0) {
        snack(context, 'End time must be after start time for ${entry.key}.');
        return;
      }
    }
    Navigator.pop(context, (weeklySchedule: _schedule, slotMinutes: _slotMinutes));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Weekly availability'),
      content: SizedBox(
        width: 420,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.65),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final day in kWeekdays) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(day),
                  value: _schedule.containsKey(day),
                  onChanged: (enabled) => setState(() {
                    if (enabled) {
                      _schedule[day] = {'startTime': '09:00', 'endTime': '13:00'};
                    } else {
                      _schedule.remove(day);
                    }
                  }),
                ),
                if (_schedule.containsKey(day))
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickTime(day, 'startTime'),
                          icon: const Icon(Icons.access_time, size: 18),
                          label: Text('From ${_parseTime(_schedule[day]!['startTime']!).format(context)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickTime(day, 'endTime'),
                          icon: const Icon(Icons.access_time, size: 18),
                          label: Text('To ${_parseTime(_schedule[day]!['endTime']!).format(context)}'),
                        ),
                      ),
                    ],
                  ),
                const Divider(height: 12),
              ],
              DropdownButtonFormField<int>(
                initialValue: _slotMinutes,
                decoration: const InputDecoration(labelText: 'Minutes per patient'),
                items: [
                  15,
                  20,
                  30,
                  45,
                  60,
                ].map((minutes) => DropdownMenuItem(value: minutes, child: Text('$minutes minutes'))).toList(),
                onChanged: (minutes) {
                  if (minutes != null) setState(() => _slotMinutes = minutes);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
