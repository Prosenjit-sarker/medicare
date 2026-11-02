import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/core/services/reminder_service.dart';
import 'package:medicare_bd/features/appointments/appointments_screen.dart';
import 'package:medicare_bd/features/auth/presentation/auth_providers.dart';
import 'package:medicare_bd/features/profile/profile_screen.dart';
import 'package:medicare_bd/features/support/misc_screens.dart';

final _tabProvider = StateProvider<int>((_) => 0);

class _Tile {
  const _Tile(this.key, this.icon, this.route, {this.label});
  final String key;
  final IconData icon;
  final String route;
  final String? label;
}

const _patientTiles = [
  _Tile('doctors', Icons.medical_services_outlined, '/doctors'),
  _Tile('hospitals', Icons.local_hospital_outlined, '/hospitals'),
  _Tile('pharmacy', Icons.medication_outlined, '/pharmacies'),
  _Tile('labs', Icons.science_outlined, '/diagnostics'),
  _Tile('blood', Icons.bloodtype_outlined, '/blood'),
  _Tile('ambulance', Icons.emergency_outlined, '/ambulance'),
  _Tile('prescriptions', Icons.description_outlined, '/prescriptions'),
  _Tile('records', Icons.folder_shared_outlined, '/records'),
  _Tile('reminders', Icons.alarm, '/reminders'),
  _Tile('tracker', Icons.monitor_heart_outlined, '/tracker'),
  _Tile('articles', Icons.menu_book_outlined, '/articles'),
  _Tile('support', Icons.support_agent, '/support'),
];

const _roleTiles = {
  'doctor': _Tile('', Icons.badge, '/doctor', label: 'Doctor dashboard'),
  'hospital': _Tile('', Icons.apartment, '/hospital-dash', label: 'Hospital dashboard'),
  'pharmacy': _Tile('', Icons.storefront, '/pharmacy-dash', label: 'Pharmacy dashboard'),
  'diagnostic': _Tile('', Icons.biotech, '/diagnostic-dash', label: 'Diagnostic dashboard'),
  'ambulance': _Tile('', Icons.airport_shuttle, '/ambulance-dash', label: 'Ambulance dashboard'),
};

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(reminderSyncProvider);
    final tab = ref.watch(_tabProvider);
    final user = ref.watch(appUserProvider).valueOrNull;
    final fs = ref.read(fsProvider);

    final tiles = <(IconData, String, String)>[
      if (user != null && _roleTiles[user.role] != null)
        (_roleTiles[user.role]!.icon, _roleTiles[user.role]!.label!, _roleTiles[user.role]!.route),
      if (user?.isStaff ?? false) (Icons.admin_panel_settings, 'Admin panel', '/admin'),
      for (final t in _patientTiles) (t.icon, tr(ref, t.key), t.route),
    ];

    final pages = <Widget>[
      user?.deactivated ?? false
          ? Center(
              child: FilledButton(
                onPressed: () => act(context, () => fs.update('users', fs.uid, {'deactivated': false})),
                child: const Text('Account deactivated. Reactivate'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '${tr(ref, 'welcome')}, ${user?.name ?? ''}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => context.push('/sos'),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF3B7B7)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sos, color: Color(0xFFB91C1C)),
                        const SizedBox(width: 10),
                        Text(
                          tr(ref, 'sos'),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF9B1C1C)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    for (final t in tiles)
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push(t.$3),
                        child: Card(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(t.$1, color: const Color(0xFF0F766E), size: 30),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  t.$2,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Doctors',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push('/doctors'),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('See all'),
                    ),
                  ],
                ),
                DocList(
                  q: q('doctors', f1: 'status', v1: 'verified', limit: 3),
                  empty: 'No verified doctors available yet.',
                  shrink: true,
                  builder: (context, doctor) => DocCard(
                    leading: DoctorAvatar(imageUrl: doctor.s('imageUrl')),
                    title: doctor.s('name'),
                    subtitle:
                        '${doctor.s('specialty')} · ${doctor.s('qualifications')}\n'
                        '${doctor.s('hospital')} · ${doctor.n('experience')} yrs · '
                        'BMDC ${doctor.s('bmdc')}',
                    trailing: Text('৳${doctor.n('fee')}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    onTap: () => context.push('/book/${doctor.id}'),
                  ),
                ),
              ],
            ),
      const AppointmentsPage(),
      const NotificationsPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('MediCare BD')),
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => ref.read(_tabProvider.notifier).state = i,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: tr(ref, 'home')),
          NavigationDestination(icon: const Icon(Icons.event_outlined), label: tr(ref, 'visits')),
          NavigationDestination(icon: const Icon(Icons.notifications_outlined), label: tr(ref, 'alerts')),
          NavigationDestination(icon: const Icon(Icons.person_outline), label: tr(ref, 'profile')),
        ],
      ),
    );
  }
}
