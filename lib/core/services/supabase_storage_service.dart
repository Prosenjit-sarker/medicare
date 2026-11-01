import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  SupabaseStorageService._();

  static final instance = SupabaseStorageService._();

  static const doctorAvatarBucket = 'doctor-avatars';
  static const catalogImagesBucket = 'catalog-images';
  static const medicalFilesBucket = 'medical-files';
  static const maxDoctorAvatarBytes = 5 * 1024 * 1024;
  static const maxMedicalFileBytes = 20 * 1024 * 1024;

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> uploadDoctorAvatar({
    required String uid,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final extension = _extensionFor(contentType);
    final path =
        '$uid/profile-${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from(doctorAvatarBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return path;
  }

  String doctorAvatarUrl(String path) =>
      _client.storage.from(doctorAvatarBucket).getPublicUrl(path);

  Future<void> deleteDoctorAvatar(String path) async {
    await _client.storage.from(doctorAvatarBucket).remove([path]);
  }

  Future<({String path, String url})> uploadCatalogImage({
    required String ownerUid,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$ownerUid/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await _client.storage
        .from(catalogImagesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return (
      path: path,
      url: _client.storage.from(catalogImagesBucket).getPublicUrl(path),
    );
  }

  Future<void> deleteCatalogImage(String path) async {
    await _client.storage.from(catalogImagesBucket).remove([path]);
  }

  Future<String> uploadMedicalFile({
    required String ownerUid,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
    List<String> sharedWith = const [],
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$ownerUid/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final bucket = _client.storage.from(medicalFilesBucket);
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType),
    );
    try {
      await _client.from('health_file_access').insert({
        'object_path': path,
        'owner_uid': ownerUid,
        'shared_with': sharedWith,
      });
    } catch (_) {
      await bucket.remove([path]);
      rethrow;
    }
    return path;
  }

  Future<String> savePrescriptionPdf({
    required String ownerUid,
    required String prescriptionId,
    required String otherPartyUid,
    required Uint8List bytes,
  }) async {
    final path = '$ownerUid/prescriptions/$prescriptionId.pdf';
    await _client.storage
        .from(medicalFilesBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );
    await _client.from('health_file_access').upsert({
      'object_path': path,
      'owner_uid': ownerUid,
      'shared_with': [otherPartyUid],
    }, onConflict: 'object_path');
    return path;
  }

  Future<void> setMedicalFileShares(
    String path,
    List<String> sharedWith,
  ) async {
    await _client
        .from('health_file_access')
        .update({'shared_with': sharedWith})
        .eq('object_path', path);
  }

  Future<String> createMedicalFileUrl(String path) =>
      _client.storage.from(medicalFilesBucket).createSignedUrl(path, 900);

  Future<void> deleteMedicalFile(String path) async {
    await _client.from('health_file_access').delete().eq('object_path', path);
    await _client.storage.from(medicalFilesBucket).remove([path]);
  }

  String contentTypeFor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      _ => 'image/jpeg',
    };
  }

  String _extensionFor(String contentType) => switch (contentType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/heic' => 'heic',
    'image/heif' => 'heif',
    _ => 'jpg',
  };
}
