import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight document wrapper: id + data with typed getters.
class Doc {
  const Doc(this.id, this.d);
  final String id;
  final Map<String, dynamic> d;

  String s(String k) => '${d[k] ?? ''}';
  num n(String k) => (d[k] as num?) ?? 0;
  bool b(String k) => d[k] == true;
  List<dynamic> l(String k) => (d[k] as List?) ?? const [];
  DateTime? t(String k) => (d[k] as Timestamp?)?.toDate();
}

/// Query spec (a record, so it has value equality and works as a provider key).
typedef Q = ({String col, String? f1, Object? v1, String? f2, Object? v2, bool arr, int limit, String? order});

Q q(String col, {String? f1, Object? v1, String? f2, Object? v2, bool arr = false, int limit = 50, String? order}) =>
    (col: col, f1: f1, v1: v1, f2: f2, v2: v2, arr: arr, limit: limit, order: order);

class FirestoreService {
  FirestoreService(this.db, this.auth);
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  String get uid => auth.currentUser!.uid;
  static FieldValue get now => FieldValue.serverTimestamp();

  Stream<List<Doc>> watch(Q x) {
    Query<Map<String, dynamic>> query = db.collection(x.col);
    if (x.f1 != null) query = x.arr ? query.where(x.f1!, arrayContains: x.v1) : query.where(x.f1!, isEqualTo: x.v1);
    if (x.f2 != null) query = query.where(x.f2!, isEqualTo: x.v2);
    if (x.order != null) query = query.orderBy(x.order!, descending: true);
    return query.limit(x.limit).snapshots().map((s) => s.docs.map((e) => Doc(e.id, e.data())).toList());
  }

  Stream<Doc?> watchDoc(String col, String id) =>
      db.collection(col).doc(id).snapshots().map((s) => s.exists ? Doc(s.id, s.data()!) : null);

  Future<Doc?> get(String col, String id) async {
    final s = await db.collection(col).doc(id).get();
    return s.exists ? Doc(s.id, s.data()!) : null;
  }

  Future<String> add(String col, Map<String, dynamic> data) async {
    final r = db.collection(col).doc();
    await r.set({...data, 'createdAt': now});
    return r.id;
  }

  Future<void> set(String col, String id, Map<String, dynamic> data) =>
      db.collection(col).doc(id).set({...data, 'updatedAt': now}, SetOptions(merge: true));

  Future<void> update(String col, String id, Map<String, dynamic> data) =>
      db.collection(col).doc(id).update({...data, 'updatedAt': now});

  Future<void> delete(String col, String id) => db.collection(col).doc(id).delete();

  Future<int> count(String col) async => (await db.collection(col).count().get()).count ?? 0;

  /// Immutable audit entry for sensitive admin operations (written inside the same batch).
  Map<String, dynamic> audit(String action, String col, String id) =>
      {'actorId': uid, 'action': action, 'targetCollection': col, 'targetId': id, 'createdAt': now};
}

final fsProvider = Provider((_) => FirestoreService(FirebaseFirestore.instance, FirebaseAuth.instance));

final docsProvider = StreamProvider.autoDispose.family<List<Doc>, Q>((ref, x) => ref.watch(fsProvider).watch(x));

final docProvider = StreamProvider.autoDispose.family<Doc?, ({String col, String id})>(
  (ref, k) => ref.watch(fsProvider).watchDoc(k.col, k.id),
);
