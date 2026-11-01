import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/core/services/consultation_service.dart';
import 'package:medicare_bd/features/auth/presentation/auth_providers.dart';

/// Phone numbers are never public. A donor's number sits in a private sub-document and is
/// readable only by people the donor has explicitly granted (by accepting their request).
class BloodPage extends ConsumerWidget {
  const BloodPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: Text(tr(ref, 'blood')), bottom: const TabBar(tabs: [Tab(text: 'Need blood'), Tab(text: 'Donate'), Tab(text: 'Find donors')])),
        body: const TabBarView(children: [_NeedBlood(), _Donate(), _FindDonors()]),
      ),
    );
  }
}

class _NeedBlood extends ConsumerWidget {
  const _NeedBlood();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.bloodtype),
        label: const Text('New request'),
        onPressed: () async {
          final mine = await fs.db.collection('blood_requests').where('requesterId', isEqualTo: fs.uid).where('status', isEqualTo: 'open').get();
          if (!context.mounted) return;
          if (mine.docs.length >= 3) return snack(context, 'You already have 3 open requests (spam protection). Close one first.');
          final v = await showFormSheet(context, 'Blood request', const [
            FieldSpec('group', 'Blood group', kind: FK.choice, options: kBloodGroups),
            FieldSpec('district', 'District', kind: FK.choice, options: kDistricts),
            FieldSpec('area', 'Area / hospital'),
            FieldSpec('units', 'Bags needed', kind: FK.choice, options: ['1', '2', '3', '4', '5']),
            FieldSpec('urgent', 'Emergency', kind: FK.flag),
            FieldSpec('note', 'Note', required: false),
          ]);
          if (v == null || !context.mounted) return;
          await act(context, () => fs.add('blood_requests', {
                ...v, 'units': int.parse(v['units'] as String), 'requesterId': fs.uid, 'status': 'open',
                'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 48))),
              }), ok: 'Request posted. It expires in 48 hours.');
        },
      ),
      body: DocList(
        q: q('blood_requests', f1: 'requesterId', v1: fs.uid),
        empty: 'You have no blood requests.',
        builder: (c, r) => Card(
          child: ExpansionTile(
            title: Text('${r.s('group')} · ${r.n('units')} bag(s)${r.b('urgent') ? ' · URGENT' : ''}'),
            subtitle: Text('${r.s('area')}, ${r.s('district')}'),
            trailing: StatusChip(r.s('status')),
            children: [
              DocList(
                q: q('blood_requests/${r.id}/responses'),
                shrink: true,
                empty: 'No donors have responded yet.',
                builder: (c, d) => ListTile(
                  title: Text('${d.s('donorName')} can donate'),
                  trailing: TextButton(
                    child: const Text('Get contact'),
                    onPressed: () async {
                      try {
                        final p = await fs.get('blood_donors/${d.s('donorId')}/private', 'contact');
                        if (!c.mounted) return;
                        showDialog(context: c, builder: (_) => AlertDialog(title: Text(d.s('donorName')), content: Text(p?.s('phone') ?? 'No number'), actions: [if (p != null) TextButton(onPressed: () => callNumber(c, p.s('phone')), child: const Text('Call'))]));
                      } catch (_) {
                        if (c.mounted) snack(c, 'Contact not shared.');
                      }
                    },
                  ),
                ),
              ),
              if (r.s('status') == 'open') TextButton(onPressed: () => act(c, () => fs.update('blood_requests', r.id, {'status': 'fulfilled'})), child: const Text('Mark fulfilled')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Donate extends ConsumerWidget {
  const _Donate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    final me = ref.watch(docProvider((col: 'blood_donors', id: fs.uid)));
    return me.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Could not load.')),
      data: (d) {
        Future<void> edit() async {
          final v = await showFormSheet(context, 'Donor profile', [
            const FieldSpec('group', 'Blood group', kind: FK.choice, options: kBloodGroups),
            const FieldSpec('district', 'District', kind: FK.choice, options: kDistricts),
            const FieldSpec('area', 'Area'),
            const FieldSpec('available', 'Available to donate', kind: FK.flag),
            const FieldSpec('phone', 'Phone (shared only with people you accept)'),
          ], initial: {...?d?.d, 'available': d?.b('available') ?? true});
          if (v == null || !context.mounted) return;
          final name = ref.read(appUserProvider).valueOrNull?.name ?? 'Donor';
          final phone = v.remove('phone');
          await act(context, () async {
            await fs.set('blood_donors', fs.uid, {...v, 'name': name});
            await fs.set('blood_donors/${fs.uid}/private', 'contact', {'phone': phone});
          }, ok: 'Saved.');
        }

        if (d == null) {
          return Center(child: FilledButton(onPressed: edit, child: const Text('Register as blood donor')));
        }
        return Column(children: [
          Card(margin: const EdgeInsets.all(12), child: ListTile(title: Text('${d.s('group')} · ${d.s('area')}, ${d.s('district')}'), subtitle: Text(d.b('available') ? 'Available' : 'Not available'), trailing: TextButton(onPressed: edit, child: const Text('Edit')))),
          const Padding(padding: EdgeInsets.all(8), child: Text('Open requests matching your group and district', style: TextStyle(fontWeight: FontWeight.w800))),
          Expanded(
            child: DocList(
              q: q('blood_requests', f1: 'group', v1: d.s('group'), f2: 'status', v2: 'open'),
              empty: 'No matching requests right now.',
              filter: (r) => r.s('district') == d.s('district') && r.s('requesterId') != fs.uid && (r.t('expiresAt')?.isAfter(DateTime.now()) ?? false),
              builder: (c, r) => DocCard(
                title: '${r.n('units')} bag(s)${r.b('urgent') ? ' · URGENT' : ''}',
                subtitle: '${r.s('area')}\n${r.s('note')}',
                trailing: FilledButton(
                  onPressed: () => act(c, () async {
                    final b = fs.db.batch();
                    b.set(fs.db.collection('blood_requests/${r.id}/responses').doc(fs.uid), {'donorId': fs.uid, 'donorName': d.s('name'), 'createdAt': FirestoreService.now});
                    b.set(fs.db.collection('blood_donors/${fs.uid}/grants').doc(r.s('requesterId')), {'requestId': r.id, 'createdAt': FirestoreService.now});
                    await b.commit();
                  }, ok: 'Sent. The requester can now see your contact.'),
                  child: const Text('I can donate'),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class _FindDonors extends StatefulWidget {
  const _FindDonors();

  @override
  State<_FindDonors> createState() => _FindState();
}

class _FindState extends State<_FindDonors> {
  String _g = 'O+';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(height: 56, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [for (final g in kBloodGroups) Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(g), selected: _g == g, onSelected: (_) => setState(() => _g = g)))])),
      Expanded(
        child: DocList(
          q: q('blood_donors', f1: 'group', v1: _g, f2: 'available', v2: true, limit: 60),
          empty: 'No available donors for this group yet.',
          builder: (c, d) => DocCard(title: d.s('name').isEmpty ? 'Donor' : '${d.s('name').split(' ').first} ${d.s('name').split(' ').length > 1 ? '${d.s('name').split(' ').last[0]}.' : ''}', subtitle: '${d.s('area')}, ${d.s('district')}\nPost a request to contact donors.', trailing: Text(d.s('group'), style: const TextStyle(fontWeight: FontWeight.w800))),
        ),
      ),
    ]);
  }
}
