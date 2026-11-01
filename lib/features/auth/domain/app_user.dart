class AppUser {
  const AppUser({required this.uid, required this.name, required this.email, required this.role, this.deactivated = false});

  final String uid;
  final String name;
  final String email;
  final String role;
  final bool deactivated;

  bool get isStaff => const ['admin', 'super_admin', 'verification_admin', 'support_admin', 'finance_admin', 'content_admin'].contains(role);

  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
        uid: uid,
        name: (m['name'] ?? '') as String,
        email: (m['email'] ?? '') as String,
        role: (m['role'] ?? 'patient') as String,
        deactivated: m['deactivated'] == true,
      );
}
