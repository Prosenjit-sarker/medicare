import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/core/services/consultation_service.dart';
import 'package:medicare_bd/features/doctors/reviews_section.dart';
import 'package:medicare_bd/features/providers/provider_kinds.dart';

/// Hospital search uses manually stored district / area / address (no maps in this version).
class HospitalsPage extends ConsumerStatefulWidget {
  const HospitalsPage({super.key});

  @override
  ConsumerState<HospitalsPage> createState() => _State();
}

class _State extends ConsumerState<HospitalsPage> {
  String _t = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'hospitals'))),
      body: Column(
        children: [
          searchBox((v) => setState(() => _t = v.toLowerCase()), hint: 'Name, district, area'),
          Expanded(
            child: DocList(
              q: q('hospitals', f1: 'status', v1: 'verified', limit: 60),
              empty: 'No verified hospitals yet.',
              filter: (h) => '${h.s('name')} ${h.s('district')} ${h.s('area')}'.toLowerCase().contains(_t),
              builder: (c, h) => DocCard(
                title: h.s('name'),
                subtitle: '${h.s('area')}, ${h.s('district')}\n${h.s('address')}',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => HospitalDetailPage(h))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HospitalDetailPage extends ConsumerWidget {
  const HospitalDetailPage(this.h, {super.key});
  final Doc h;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(h.s('name'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('${h.s('address')}, ${h.s('area')}, ${h.s('district')}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => callNumber(context, h.s('phone')),
                icon: const Icon(Icons.call),
                label: const Text('Call'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
                onPressed: () => callNumber(context, h.s('emergencyPhone')),
                icon: const Icon(Icons.emergency),
                label: const Text('Emergency'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Departments', style: TextStyle(fontWeight: FontWeight.w800)),
          Wrap(
            spacing: 6,
            children: [
              for (final d in h.s('departments').split(','))
                if (d.trim().isNotEmpty) Chip(label: Text(d.trim())),
            ],
          ),
          if (h.s('services').isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Services', style: TextStyle(fontWeight: FontWeight.w800)),
            Wrap(
              spacing: 6,
              children: [
                for (final d in h.s('services').split(','))
                  if (d.trim().isNotEmpty) Chip(label: Text(d.trim())),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Text('Affiliated doctors', style: TextStyle(fontWeight: FontWeight.w800)),
          DocList(
            q: q('affiliation_requests', f1: 'hospitalId', v1: h.id, f2: 'status', v2: 'approved'),
            shrink: true,
            empty: 'None listed.',
            builder: (c, a) => ListTile(dense: true, title: Text(a.s('doctorName'))),
          ),
          const SizedBox(height: 16),
          ReviewsSection(targetId: h.id, targetType: 'hospital'),
        ],
      ),
    );
  }
}

class HospitalDashboard extends ConsumerWidget {
  const HospitalDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hospital dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Doctors'),
              Tab(text: 'Reviews'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ProviderProfileCard(kProviderKinds['hospital']!),
            DocList(
              q: q('affiliation_requests', f1: 'hospitalId', v1: fs.uid),
              empty: 'No affiliation requests.',
              builder: (c, a) => DocCard(
                title: a.s('doctorName'),
                trailing: StatusChip(a.s('status')),
                actions: [
                  if (a.s('status') != 'approved')
                    ActionChip(
                      label: const Text('Approve'),
                      onPressed: () => act(c, () => fs.update('affiliation_requests', a.id, {'status': 'approved'})),
                    ),
                  if (a.s('status') != 'rejected')
                    ActionChip(
                      label: const Text('Reject'),
                      onPressed: () => act(c, () => fs.update('affiliation_requests', a.id, {'status': 'rejected'})),
                    ),
                ],
              ),
            ),
            ListView(
              padding: const EdgeInsets.all(12),
              children: [ReviewsSection(targetId: fs.uid, targetType: 'hospital', canReview: false)],
            ),
          ],
        ),
      ),
    );
  }
}
