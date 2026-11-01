import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/core/services/consultation_service.dart';
import 'package:medicare_bd/features/providers/provider_kinds.dart';

class AmbulancePage extends ConsumerStatefulWidget {
  const AmbulancePage({super.key});

  @override
  ConsumerState<AmbulancePage> createState() => _State();
}

class _State extends ConsumerState<AmbulancePage> {
  String _t = '';

  @override
  Widget build(BuildContext context) {
    final fs = ref.read(fsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: Text(tr(ref, 'ambulance')), bottom: const TabBar(tabs: [Tab(text: 'Providers'), Tab(text: 'My requests')])),
        body: TabBarView(children: [
          Column(children: [
            Card(color: const Color(0xFFFDECEC), margin: const EdgeInsets.all(12), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
              const Expanded(child: Text('This app is not an emergency dispatch service. In an emergency call directly.', style: TextStyle(fontSize: 13))),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C), minimumSize: const Size(80, 40)), onPressed: () => callNumber(context, '999'), child: const Text('999')),
            ]))),
            searchBox((v) => setState(() => _t = v.toLowerCase()), hint: 'District or area'),
            Expanded(
              child: DocList(
                q: q('ambulance_providers', f1: 'status', v1: 'verified', limit: 60),
                empty: 'No verified providers yet.',
                filter: (p) => '${p.s('name')} ${p.s('district')} ${p.s('area')}'.toLowerCase().contains(_t),
                builder: (c, p) => DocCard(
                  title: p.s('name'),
                  subtitle: '${p.s('vehicleType')} · ${p.s('area')}, ${p.s('district')}${p.b('open24h') ? ' · 24h' : ''}',
                  actions: [
                    ActionChip(avatar: const Icon(Icons.call, size: 18), label: const Text('Call'), onPressed: () => callNumber(c, p.s('phone'))),
                    ActionChip(avatar: const Icon(Icons.local_hospital, size: 18), label: const Text('Request'), onPressed: () async {
                      final v = await showFormSheet(c, 'Ambulance request', const [
                        FieldSpec('pickup', 'Pickup address', kind: FK.multiline),
                        FieldSpec('phone', 'Your phone'),
                        FieldSpec('note', 'Patient condition / destination', required: false),
                      ]);
                      if (v == null || !c.mounted) return;
                      await act(c, () => fs.add('ambulance_requests', {...v, 'patientId': fs.uid, 'providerId': p.id, 'providerName': p.s('name'), 'status': 'requested'}), ok: 'Request sent. Also call the provider to confirm.');
                    }),
                  ],
                ),
              ),
            ),
          ]),
          DocList(q: q('ambulance_requests', f1: 'patientId', v1: fs.uid), empty: 'No requests.', builder: (c, r) => DocCard(title: r.s('providerName'), subtitle: r.s('pickup'), trailing: StatusChip(r.s('status')))),
        ]),
      ),
    );
  }
}

class AmbulanceDashboard extends ConsumerWidget {
  const AmbulanceDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Ambulance dashboard'), bottom: const TabBar(tabs: [Tab(text: 'Profile'), Tab(text: 'Requests')])),
        body: TabBarView(children: [
          ProviderProfileCard(kProviderKinds['ambulance']!),
          DocList(
            q: q('ambulance_requests', f1: 'providerId', v1: fs.uid, limit: 100),
            empty: 'No requests.',
            builder: (c, r) => DocCard(
              title: r.s('pickup'),
              subtitle: '${r.s('phone')}\n${r.s('note')}',
              trailing: StatusChip(r.s('status')),
              actions: [
                for (final s in ['accepted', 'on_the_way', 'completed', 'declined']) ActionChip(label: Text(s.replaceAll('_', ' ')), onPressed: () => act(c, () => fs.update('ambulance_requests', r.id, {'status': s}))),
                ActionChip(avatar: const Icon(Icons.call, size: 18), label: const Text('Call'), onPressed: () => callNumber(c, r.s('phone'))),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
