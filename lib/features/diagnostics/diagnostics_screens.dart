import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/core/services/consultation_service.dart';
import 'package:medicare_bd/features/providers/provider_kinds.dart';

class DiagnosticsPage extends ConsumerStatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  ConsumerState<DiagnosticsPage> createState() => _State();
}

class _State extends ConsumerState<DiagnosticsPage> {
  String _t = '';

  @override
  Widget build(BuildContext context) {
    final fs = ref.read(fsProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(ref, 'labs')),
          actions: [IconButton(icon: const Icon(Icons.history), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LabBookingsPage())))],
          bottom: const TabBar(tabs: [Tab(text: 'Tests'), Tab(text: 'Centers')]),
        ),
        body: TabBarView(children: [
          Column(children: [
            searchBox((v) => setState(() => _t = v.toLowerCase()), hint: 'Search tests'),
            Expanded(
              child: DocList(
                q: q('lab_tests', limit: 150),
                empty: 'No tests listed yet.',
                filter: (t) => '${t.s('name')} ${t.s('category')} ${t.s('centerName')}'.toLowerCase().contains(_t),
                builder: (c, t) => DocCard(
                  title: t.s('name'),
                  subtitle: '${t.s('centerName')} · ${t.s('category')}\n৳${t.n('price')}${t.s('preparation').isEmpty ? '' : '\nPreparation: ${t.s('preparation')}'}',
                  trailing: TextButton(
                    child: const Text('Book'),
                    onPressed: () async {
                      final v = await showFormSheet(c, 'Book ${t.s('name')}', const [
                        FieldSpec('date', 'Preferred date', kind: FK.date),
                        FieldSpec('homeCollection', 'Home sample collection', kind: FK.flag),
                        FieldSpec('address', 'Address (for home collection)', required: false),
                      ]);
                      if (v == null || !c.mounted) return;
                      await act(c, () => fs.add('test_bookings', {...v, 'patientId': fs.uid, 'testId': t.id, 'testName': t.s('name'), 'centerId': t.s('centerId'), 'centerName': t.s('centerName'), 'status': 'booked'}), ok: 'Booked.');
                    },
                  ),
                ),
              ),
            ),
          ]),
          DocList(
            q: q('diagnostic_centers', f1: 'status', v1: 'verified', limit: 60),
            empty: 'No verified centers yet.',
            builder: (c, d) => DocCard(
              title: d.s('name'),
              subtitle: '${d.s('area')}, ${d.s('district')}\n${d.b('homeCollection') ? 'Home collection available' : ''}',
              trailing: IconButton(icon: const Icon(Icons.call), onPressed: () => callNumber(c, d.s('phone'))),
            ),
          ),
        ]),
      ),
    );
  }
}

class LabBookingsPage extends ConsumerWidget {
  const LabBookingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'labbookings'))),
      body: DocList(
        q: q('test_bookings', f1: 'patientId', v1: fs.uid),
        empty: 'No bookings yet.',
        builder: (c, b) => DocCard(
          title: b.s('testName'),
          subtitle: '${b.s('centerName')} · ${b.s('date')}${b.b('homeCollection') ? ' · home collection' : ''}${b.s('reportSummary').isEmpty ? '' : '\nReport: ${b.s('reportSummary')}'}',
          trailing: StatusChip(b.s('status')),
          actions: [if (b.s('status') == 'booked') ActionChip(label: const Text('Cancel'), onPressed: () => act(c, () => fs.update('test_bookings', b.id, {'status': 'cancelled'})))],
        ),
      ),
    );
  }
}

class DiagnosticDashboard extends ConsumerWidget {
  const DiagnosticDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    const fields = [
      FieldSpec('name', 'Test name'),
      FieldSpec('category', 'Category', kind: FK.choice, options: ['Blood', 'Urine', 'Imaging', 'Cardiac', 'Hormone', 'Other']),
      FieldSpec('price', 'Price (BDT)', kind: FK.number),
      FieldSpec('preparation', 'Preparation instructions', kind: FK.multiline, required: false),
    ];
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('Diagnostic dashboard'), bottom: const TabBar(tabs: [Tab(text: 'Profile'), Tab(text: 'Tests'), Tab(text: 'Bookings')])),
        body: TabBarView(children: [
          ProviderProfileCard(kProviderKinds['diagnostic']!),
          Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Test'),
              onPressed: () async {
                final v = await showFormSheet(context, 'New test', fields);
                if (v == null || !context.mounted) return;
                final me = await fs.get('diagnostic_centers', fs.uid);
                if (!context.mounted) return;
                await act(context, () => fs.add('lab_tests', {...v, 'centerId': fs.uid, 'centerName': me?.s('name') ?? ''}), ok: 'Added.');
              },
            ),
            body: DocList(
              q: q('lab_tests', f1: 'centerId', v1: fs.uid, limit: 200),
              empty: 'No tests in your catalog.',
              builder: (c, t) => DocCard(
                title: t.s('name'),
                subtitle: '${t.s('category')} · ৳${t.n('price')}',
                onTap: () async {
                  final v = await showFormSheet(c, 'Edit test', fields, initial: t.d);
                  if (v != null && c.mounted) await act(c, () => fs.update('lab_tests', t.id, v));
                },
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => act(c, () => fs.delete('lab_tests', t.id))),
              ),
            ),
          ),
          DocList(
            q: q('test_bookings', f1: 'centerId', v1: fs.uid, limit: 100),
            empty: 'No bookings yet.',
            builder: (c, b) => DocCard(
              title: b.s('testName'),
              subtitle: '${b.s('date')}${b.b('homeCollection') ? ' · home: ${b.s('address')}' : ''}${b.s('reportSummary').isEmpty ? '' : '\nReport: ${b.s('reportSummary')}'}',
              trailing: StatusChip(b.s('status')),
              actions: [
                if (b.s('status') == 'booked') ActionChip(label: const Text('Sample collected'), onPressed: () => act(c, () => fs.update('test_bookings', b.id, {'status': 'sample_collected'}))),
                if (b.s('status') != 'completed' && b.s('status') != 'cancelled')
                  ActionChip(label: const Text('Publish report'), onPressed: () async {
                    final v = await showFormSheet(c, 'Report result', const [FieldSpec('reportSummary', 'Report (text)', kind: FK.multiline)]);
                    if (v != null && c.mounted) await act(c, () => fs.update('test_bookings', b.id, {'status': 'completed', 'reportSummary': v['reportSummary']}), ok: 'Report delivered to patient.');
                  }),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
