import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';

class SlotTakenException implements Exception {}

class AppointmentRepository {
  AppointmentRepository(this._db);
  final FirebaseFirestore _db;

  static String slotId(String doctorId, String date, String slot) => '${doctorId}_${date}_${slot.replaceAll(':', '')}';

  static String _roomKey() {
    final r = Random.secure();
    return List.generate(8, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Transaction: the slot document is the lock. Rules also refuse overwriting an existing slot,
  /// so two patients can never hold the same doctor/date/time.
  Future<void> book({required String patientId, required String patientName, required Doc doctor, required String date, required String slot, required String type}) async {
    final sid = slotId(doctor.id, date, slot);
    final slotRef = _db.collection('appointment_slots').doc(sid);
    final apptRef = _db.collection('appointments').doc();
    await _db.runTransaction((tx) async {
      if ((await tx.get(slotRef)).exists) throw SlotTakenException();
      tx.set(slotRef, {'doctorId': doctor.id, 'date': date, 'slot': slot, 'appointmentId': apptRef.id});
      tx.set(apptRef, {
        'patientId': patientId, 'patientName': patientName,
        'doctorId': doctor.id, 'doctorName': doctor.s('name'), 'doctorSpecialty': doctor.s('specialty'), 'doctorBmdc': doctor.s('bmdc'),
        'fee': doctor.n('fee'), 'date': date, 'slot': slot, 'type': type,
        'status': 'booked', 'paymentStatus': 'unpaid', 'slotId': sid, 'roomKey': _roomKey(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Cancelling frees the slot again.
  Future<void> cancel(Doc appt) {
    final b = _db.batch();
    b.update(_db.collection('appointments').doc(appt.id), {'status': 'cancelled'});
    b.delete(_db.collection('appointment_slots').doc(appt.s('slotId')));
    return b.commit();
  }

  Future<void> complete(Doc appt, String notes) =>
      _db.collection('appointments').doc(appt.id).update({'status': 'completed', 'doctorNotes': notes});
}

final appointmentRepositoryProvider = Provider((_) => AppointmentRepository(FirebaseFirestore.instance));
