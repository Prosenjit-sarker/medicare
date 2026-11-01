import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/features/auth/presentation/auth_providers.dart';
import 'package:medicare_bd/features/providers/provider_kinds.dart';

class _Section {
  const _Section(this.label, this.icon, this.roles, this.build);
  final String label;
  final IconData icon;
  final List<String> roles; // empty = every staff role
  final Widget Function() build;
}

/// Admin panel (works on Android, iOS and Flutter Web). Each staff role only sees its own sections,
/// and Firestore rules enforce the same split on the server.
class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _State();
}

class _State extends ConsumerState<AdminPage> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(appUserProvider).valueOrNull?.role ?? '';
    final all = <_Section>[
      _Section('Overview', Icons.dashboard, const [], () => const _Overview()),
      _Section('Verification', Icons.verified_user, const ['verification_admin', 'admin', 'super_admin'], () => const _Verification()),
      _Section('Payments & refunds', Icons.payments, const ['finance_admin', 'admin', 'super_admin'], () => const _Payments()),
      _Section('Content', Icons.article, const ['content_admin', 'admin', 'super_admin'], () => const _Content()),
      _Section('Support', Icons.support_agent, const ['support_admin', 'admin', 'super_admin'], () => const _SupportQueue()),
      _Section('Monitor', Icons.monitor_heart, const ['admin', 'super_admin'], () => const _Monitor()),
      _Section('Users & roles', Icons.manage_accounts, const ['super_admin', 'admin'], () => const _Users()),
      _Section('Audit logs', Icons.history, const ['super_admin'], () => const _Audit()),
      _Section('Settings', Icons.settings, const ['super_admin'], () => const _Settings()),
    ];
    final sections = all.where((s) => s.roles.isEmpty || s.roles.contains(role)).toList();
    if (_i >= sections.length) _i = 0;
    final wide = MediaQuery.of(context).size.width >= 800;
    final body = sections[_i].build();
    return Scaffold(
      appBar: AppBar(title: Text('Admin · ${sections[_i].label}')),
      drawer: wide ? null : Drawer(child: ListView(children: [for (var k = 0; k < sections.length; k++) ListTile(leading: Icon(sections[k].icon), title: Text(sections[k].label), selected: k == _i, onTap: () { setState(() => _i = k); Navigator.pop(context); })])),
      body: wide
          ? Row(children: [
              NavigationRail(
                extended: true,
                selectedIndex: _i,
                onDestinationSelected: (k) => setState(() => _i = k),
                destinations: [for (final s in sections) NavigationRailDestination(icon: Icon(s.icon), label: Text(s.label))],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ])
          : body,
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    const cols = ['users', 'doctors', 'hospitals', 'pharmacies', 'diagnostic_centers', 'ambulance_providers', 'appointments', 'medicine_orders', 'test_bookings', 'blood_requests', 'payments'];
    return GridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: MediaQuery.of(context).size.width >= 800 ? 4 : 2,
      childAspectRatio: 1.8,
      children: [
        for (final c in cols)
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(c.replaceAll('_', ' '), style: const TextStyle(fontSize: 12)),
            FutureBuilder<int>(future: fs.count(c).catchError((_) => -1), builder: (_, s) => Text(!s.hasData ? '…' : (s.data! < 0 ? '–' : '${s.data}'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
          ]))),
      ],
    );
  }
}

class _Verification extends ConsumerWidget {
  const _Verification();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    Future<void> decide(Doc d, ProviderKind k, bool ok) {
      final b = fs.db.batch();
      b.update(fs.db.collection(k.col).doc(d.id), {'status': ok ? 'verified' : 'rejected'});
      if (ok) b.update(fs.db.collection('users').doc(d.id), {'role': k.role});
      b.set(fs.db.collection('audit_logs').doc(), fs.audit(ok ? 'verify' : 'reject', k.col, d.id));
      return b.commit();
    }

    return ListView(children: [
      for (final k in kProviderKinds.values) ...[
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), child: Text('${k.title}s awaiting verification', style: const TextStyle(fontWeight: FontWeight.w800))),
        DocList(
          q: q(k.col, f1: 'status', v1: 'pending'),
          shrink: true,
          empty: 'None pending.',
          builder: (c, d) => DocCard(
            title: d.s('name'),
            subtitle: [for (final f in k.fields) if (f.kind != FK.multiline && d.s(f.key).isNotEmpty) '${f.label}: ${d.s(f.key)}'].join('\n'),
            actions: [
              FilledButton(onPressed: () => act(c, () => decide(d, k, true), ok: 'Verified.'), child: const Text('Approve')),
              OutlinedButton(onPressed: () => act(c, () => decide(d, k, false), ok: 'Rejected.'), child: const Text('Reject')),
            ],
          ),
        ),
      ],
    ]);
  }
}

class _Payments extends ConsumerWidget {
  const _Payments();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    Future<void> decide(Doc p, String status, String apptStatus) {
      final b = fs.db.batch();
      b.update(fs.db.collection('payments').doc(p.id), {'status': status});
      if (p.s('kind') == 'appointment') b.update(fs.db.collection('appointments').doc(p.s('refId')), {'paymentStatus': apptStatus});
      b.set(fs.db.collection('audit_logs').doc(), fs.audit('payment_$status', 'payments', p.id));
      return b.commit();
    }

    return DefaultTabController(
      length: 2,
      child: Column(children: [
        const TabBar(tabs: [Tab(text: 'To verify'), Tab(text: 'Verified (refunds)')]),
        Expanded(
          child: TabBarView(children: [
            DocList(
              q: q('payments', f1: 'status', v1: 'submitted'),
              empty: 'No payments waiting.',
              builder: (c, p) => DocCard(
                title: '৳${p.n('amount')} · ${p.s('method')}',
                subtitle: 'Transaction: ${p.s('trxId')}\nFor ${p.s('kind')} ${p.s('refId')}\nCheck it in your bKash/Nagad/Rocket merchant app first.',
                actions: [
                  FilledButton(onPressed: () => act(c, () => decide(p, 'verified', 'paid'), ok: 'Marked paid.'), child: const Text('Verify')),
                  OutlinedButton(onPressed: () => act(c, () => decide(p, 'rejected', 'unpaid')), child: const Text('Reject')),
                ],
              ),
            ),
            DocList(
              q: q('payments', f1: 'status', v1: 'verified'),
              empty: 'Nothing here.',
              builder: (c, p) => DocCard(
                title: '৳${p.n('amount')} · ${p.s('method')}',
                subtitle: 'Transaction: ${p.s('trxId')}',
                actions: [OutlinedButton(onPressed: () => act(c, () => decide(p, 'refunded', 'refunded'), ok: 'Marked refunded. Send the money back manually.'), child: const Text('Mark refunded'))],
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    Future<void> review(Doc a, bool ok, bool featured) {
      final b = fs.db.batch();
      b.update(fs.db.collection('health_articles').doc(a.id), {'status': ok ? 'published' : 'rejected', 'featured': featured});
      b.set(fs.db.collection('audit_logs').doc(), fs.audit(ok ? 'publish_article' : 'reject_article', 'health_articles', a.id));
      return b.commit();
    }

    return ListView(children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('Articles awaiting medical review', style: TextStyle(fontWeight: FontWeight.w800))),
      DocList(
        q: q('health_articles', f1: 'status', v1: 'pending'),
        shrink: true,
        empty: 'Nothing to review.',
        builder: (c, a) => DocCard(
          title: a.s('title'),
          subtitle: 'Dr. ${a.s('authorName')} · ${a.s('category')}\n${a.s('body')}',
          actions: [
            FilledButton(onPressed: () async {
              final v = await showFormSheet(c, 'Publish', const [FieldSpec('featured', 'Featured', kind: FK.flag)]);
              if (v != null && c.mounted) await act(c, () => review(a, true, v['featured'] == true), ok: 'Published.');
            }, child: const Text('Publish')),
            OutlinedButton(onPressed: () => act(c, () => review(a, false, false)), child: const Text('Reject')),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Expanded(child: Text('Announcements', style: TextStyle(fontWeight: FontWeight.w800))),
          FilledButton(onPressed: () async {
            final v = await showFormSheet(context, 'New announcement', const [FieldSpec('title', 'Title'), FieldSpec('body', 'Message', kind: FK.multiline)]);
            if (v != null && context.mounted) await act(context, () => fs.add('announcements', {...v, 'authorId': fs.uid}), ok: 'Posted.');
          }, child: const Text('New')),
        ]),
      ),
      DocList(q: q('announcements', limit: 20), shrink: true, builder: (c, a) => DocCard(title: a.s('title'), subtitle: a.s('body'), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => act(c, () => fs.delete('announcements', a.id))))),
    ]);
  }
}

class _SupportQueue extends ConsumerWidget {
  const _SupportQueue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    return DocList(
      q: q('support_tickets', f1: 'status', v1: 'open'),
      empty: 'No open tickets.',
      builder: (c, t) => DocCard(
        title: t.s('subject'),
        subtitle: t.s('message'),
        actions: [
          FilledButton(onPressed: () async {
            final v = await showFormSheet(c, 'Reply and close', const [FieldSpec('reply', 'Reply', kind: FK.multiline)]);
            if (v != null && c.mounted) await act(c, () => fs.update('support_tickets', t.id, {'reply': v['reply'], 'status': 'closed'}), ok: 'Closed.');
          }, child: const Text('Reply & close')),
        ],
      ),
    );
  }
}

class _Monitor extends ConsumerStatefulWidget {
  const _Monitor();

  @override
  ConsumerState<_Monitor> createState() => _MonitorState();
}

class _MonitorState extends ConsumerState<_Monitor> {
  String _col = 'appointments';
  static const _cols = ['appointments', 'prescriptions', 'medicine_orders', 'test_bookings', 'blood_requests', 'ambulance_requests', 'reviews', 'doctors', 'hospitals', 'pharmacies', 'diagnostic_centers', 'ambulance_providers'];

  String _summary(Doc d) => d.d.entries.where((e) => (e.value is String || e.value is num || e.value is bool) && e.key != 'roomKey' && '${e.value}'.length < 40).take(6).map((e) => '${e.key}: ${e.value}').join(' · ');

  @override
  Widget build(BuildContext context) {
    final fs = ref.read(fsProvider);
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: DropdownButtonFormField<String>(initialValue: _col, items: [for (final c in _cols) DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' ')))], onChanged: (v) => setState(() => _col = v!))),
      Expanded(
        child: DocList(
          key: ValueKey(_col),
          q: q(_col, limit: 100),
          builder: (c, d) => DocCard(
            title: d.s('name').isNotEmpty ? d.s('name') : (d.s('doctorName').isNotEmpty ? d.s('doctorName') : d.id),
            subtitle: _summary(d),
            trailing: _col == 'reviews' ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => act(c, () => fs.delete('reviews', d.id), ok: 'Review removed.')) : null,
          ),
        ),
      ),
    ]);
  }
}

class _Users extends ConsumerStatefulWidget {
  const _Users();

  @override
  ConsumerState<_Users> createState() => _UsersState();
}

class _UsersState extends ConsumerState<_Users> {
  String _t = '';

  @override
  Widget build(BuildContext context) {
    final fs = ref.read(fsProvider);
    final me = ref.watch(appUserProvider).valueOrNull;
    return Column(children: [
      searchBox((v) => setState(() => _t = v.toLowerCase()), hint: 'Name or email'),
      Expanded(
        child: DocList(
          q: q('users', limit: 100),
          filter: (u) => '${u.s('name')} ${u.s('email')}'.toLowerCase().contains(_t),
          builder: (c, u) => DocCard(
            title: u.s('name'),
            subtitle: '${u.s('email')}${u.b('deactivated') ? '\nDeactivated' : ''}${u.b('deletionRequested') ? '\nDeletion requested' : ''}',
            trailing: StatusChip(u.s('role') == 'patient' ? 'confirmed' : 'pending'),
            actions: [
              Text('Role: ${u.s('role')}'),
              if (me?.role == 'super_admin')
                ActionChip(label: const Text('Change role'), onPressed: () async {
                  final v = await showFormSheet(c, 'Role for ${u.s('name')}', const [FieldSpec('role', 'Role', kind: FK.choice, options: kAllRoles)], initial: {'role': u.s('role')});
                  if (v == null || !c.mounted) return;
                  await act(c, () async {
                    final b = fs.db.batch();
                    b.update(fs.db.collection('users').doc(u.id), {'role': v['role']});
                    b.set(fs.db.collection('audit_logs').doc(), {...fs.audit('role_change', 'users', u.id), 'newRole': v['role']});
                    await b.commit();
                  }, ok: 'Role updated.');
                }),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _Audit extends ConsumerWidget {
  const _Audit();

  @override
  Widget build(BuildContext context, WidgetRef ref) => DocList(
        q: q('audit_logs', limit: 100, order: 'createdAt'),
        empty: 'No audit entries.',
        builder: (c, a) => DocCard(title: a.s('action'), subtitle: '${a.s('targetCollection')}/${a.s('targetId')}\nby ${a.s('actorId')}${a.s('newRole').isEmpty ? '' : ' → ${a.s('newRole')}'}\n${a.t('createdAt') ?? ''}'),
      );
}

class _Settings extends ConsumerWidget {
  const _Settings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    final s = ref.watch(docProvider((col: 'app_settings', id: 'general'))).valueOrNull;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(title: const Text('Application settings'), subtitle: Text('Support phone: ${s?.s('supportPhone') ?? '-'}\nSupport email: ${s?.s('supportEmail') ?? '-'}\nMaintenance: ${s?.b('maintenance') ?? false}'), trailing: const Icon(Icons.edit), onTap: () async {
        final v = await showFormSheet(context, 'Settings', const [FieldSpec('supportPhone', 'Support phone'), FieldSpec('supportEmail', 'Support email'), FieldSpec('maintenance', 'Maintenance mode', kind: FK.flag)], initial: s?.d ?? const {});
        if (v != null && context.mounted) await act(context, () => fs.set('app_settings', 'general', v), ok: 'Saved.');
      })),
    ]);
  }
}
