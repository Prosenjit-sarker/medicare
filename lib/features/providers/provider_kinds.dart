import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/core/services/supabase_storage_service.dart';

class ProviderKind {
  const ProviderKind(this.key, this.col, this.role, this.title, this.fields, {this.liveKeys});
  final String key, col, role, title;
  final List<FieldSpec> fields;

  /// Keys that stay editable after verification (null = all).
  final Set<String>? liveKeys;
}

const _loc = [
  FieldSpec('district', 'District', kind: FK.choice, options: kDistricts),
  FieldSpec('area', 'Area / Thana'),
  FieldSpec('address', 'Address'),
];

final kProviderKinds = <String, ProviderKind>{
  'doctor': const ProviderKind(
    'doctor',
    'doctors',
    'doctor',
    'Doctor',
    [
      FieldSpec('name', 'Full name'),
      FieldSpec('specialty', 'Specialization'),
      FieldSpec('qualifications', 'Qualifications (e.g. MBBS, FCPS)'),
      FieldSpec('bmdc', 'BMDC registration number'),
      FieldSpec('experience', 'Experience (years)', kind: FK.number),
      FieldSpec('hospital', 'Hospital / chamber', required: false),
      FieldSpec('fee', 'Consultation fee (BDT)', kind: FK.number),
      FieldSpec('about', 'About', kind: FK.multiline, required: false),
    ],
    liveKeys: {'hospital', 'fee', 'about', 'experience'},
  ),
  'hospital': const ProviderKind('hospital', 'hospitals', 'hospital', 'Hospital', [
    FieldSpec('name', 'Hospital name'),
    ..._loc,
    FieldSpec('phone', 'Phone'),
    FieldSpec('emergencyPhone', 'Emergency phone'),
    FieldSpec('departments', 'Departments (comma separated)', kind: FK.multiline),
    FieldSpec('services', 'Services (comma separated)', kind: FK.multiline, required: false),
  ]),
  'pharmacy': const ProviderKind('pharmacy', 'pharmacies', 'pharmacy', 'Pharmacy', [
    FieldSpec('name', 'Pharmacy name'),
    ..._loc,
    FieldSpec('phone', 'Phone'),
    FieldSpec('licenseNo', 'Drug licence number'),
  ]),
  'diagnostic': const ProviderKind('diagnostic', 'diagnostic_centers', 'diagnostic', 'Diagnostic center', [
    FieldSpec('name', 'Center name'),
    ..._loc,
    FieldSpec('phone', 'Phone'),
    FieldSpec('licenseNo', 'Licence number'),
    FieldSpec('homeCollection', 'Home sample collection', kind: FK.flag),
  ]),
  'ambulance': const ProviderKind('ambulance', 'ambulance_providers', 'ambulance', 'Ambulance provider', [
    FieldSpec('name', 'Service name'),
    FieldSpec('district', 'District', kind: FK.choice, options: kDistricts),
    FieldSpec('area', 'Area / Thana'),
    FieldSpec('phone', 'Phone'),
    FieldSpec('vehicleType', 'Vehicle type', kind: FK.choice, options: ['Basic', 'ICU', 'Freezer']),
    FieldSpec('open24h', 'Open 24 hours', kind: FK.flag),
  ]),
};

/// Registration / edit card used by every provider type. Status starts as `pending`;
/// only an admin can change it (enforced by Firestore rules).
class ProviderProfileCard extends ConsumerWidget {
  const ProviderProfileCard(this.kind, {super.key});
  final ProviderKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    final doc = ref.watch(docProvider((col: kind.col, id: FirebaseAuth.instance.currentUser!.uid)));
    return doc.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Could not load profile.')),
      data: (d) {
        final verified = d?.s('status') == 'verified';
        final fields = (verified && kind.liveKeys != null)
            ? kind.fields.where((f) => kind.liveKeys!.contains(f.key)).toList()
            : kind.fields;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(kind.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                        if (d != null) StatusChip(d.s('status')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (d == null)
                      const Text('Not registered yet. Submit your details; an administrator will verify them.'),
                    if (d != null && !verified)
                      const Text('Waiting for verification. You cannot appear publicly until verified.'),
                    if (d != null)
                      for (final f in kind.fields.where((f) => f.kind != FK.multiline))
                        if (d.s(f.key).isNotEmpty)
                          Padding(padding: const EdgeInsets.only(top: 4), child: Text('${f.label}: ${d.s(f.key)}')),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () async {
                        final v = await showFormSheet(
                          context,
                          d == null ? 'Apply as ${kind.title}' : 'Edit profile',
                          fields,
                          initial: d?.d ?? const {},
                        );
                        if (v == null || !context.mounted) return;
                        await act(
                          context,
                          () => d == null
                              ? fs.set(kind.col, fs.uid, {...v, 'status': 'pending'})
                              : fs.update(kind.col, fs.uid, v),
                          ok: d == null ? 'Submitted for verification.' : 'Saved.',
                        );
                      },
                      child: Text(d == null ? 'Apply' : 'Edit'),
                    ),
                  ],
                ),
              ),
            ),
            if (kind.key == 'doctor' && verified)
              _DoctorPhotoUpload(uid: fs.uid, imageUrl: d?.s('imageUrl') ?? '', imagePath: d?.s('imagePath') ?? ''),
          ],
        );
      },
    );
  }
}

class _DoctorPhotoUpload extends ConsumerStatefulWidget {
  const _DoctorPhotoUpload({required this.uid, required this.imageUrl, required this.imagePath});

  final String uid;
  final String imageUrl;
  final String imagePath;

  @override
  ConsumerState<_DoctorPhotoUpload> createState() => _DoctorPhotoUploadState();
}

class _DoctorPhotoUploadState extends ConsumerState<_DoctorPhotoUpload> {
  bool _uploading = false;

  Future<void> _uploadPhoto() async {
    setState(() => _uploading = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (!mounted || image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 5 * 1024 * 1024) {
        snack(context, 'Choose an image smaller than 5 MB.');
        return;
      }

      final storage = SupabaseStorageService.instance;
      final imagePath = await storage.uploadDoctorAvatar(
        uid: widget.uid,
        fileName: image.name,
        bytes: bytes,
        contentType: _contentType(image),
      );
      final imageUrl = storage.doctorAvatarUrl(imagePath);
      await ref.read(fsProvider).update('doctors', widget.uid, {'imageUrl': imageUrl, 'imagePath': imagePath});
      if (widget.imagePath.isNotEmpty && widget.imagePath.startsWith('${widget.uid}/')) {
        try {
          await storage.deleteDoctorAvatar(widget.imagePath);
        } catch (_) {}
      }
      if (mounted) snack(context, 'Profile photo updated.');
    } catch (error) {
      if (mounted) {
        snack(context, 'Photo upload failed: $error');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _contentType(XFile image) {
    final mimeType = image.mimeType;
    if (mimeType == 'image/jpg' || mimeType == 'image/pjpeg') {
      return 'image/jpeg';
    }
    if (const {'image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'}.contains(mimeType)) {
      return mimeType!;
    }
    return SupabaseStorageService.instance.contentTypeFor(image.name);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            DoctorAvatar(imageUrl: widget.imageUrl, size: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Profile photo', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _uploadPhoto,
                    icon: _uploading
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_outlined),
                    label: Text(_uploading ? 'Uploading...' : 'Choose photo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ApplyPage extends StatelessWidget {
  const ApplyPage(this.kindKey, {super.key});
  final String kindKey;

  @override
  Widget build(BuildContext context) {
    final k = kProviderKinds[kindKey]!;
    return Scaffold(
      appBar: AppBar(title: Text(k.title)),
      body: ProviderProfileCard(k),
    );
  }
}
