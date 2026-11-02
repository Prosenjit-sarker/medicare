import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/features/auth/presentation/auth_providers.dart';
import 'package:medicare_bd/features/providers/provider_kinds.dart';

const _patientFields = [
  FieldSpec('dob', 'Date of birth', kind: FK.date),
  FieldSpec('gender', 'Gender', kind: FK.choice, options: ['Male', 'Female', 'Other']),
  FieldSpec('phone', 'Phone'),
  FieldSpec('bloodGroup', 'Blood group', kind: FK.choice, options: kBloodGroups),
  FieldSpec('address', 'Address'),
  FieldSpec('emergencyName', 'Emergency contact name'),
  FieldSpec('emergencyPhone', 'Emergency contact phone'),
  FieldSpec('allergies', 'Allergies', kind: FK.multiline, required: false),
  FieldSpec('conditions', 'Medical conditions', kind: FK.multiline, required: false),
  FieldSpec('history', 'Medical history', kind: FK.multiline, required: false),
];

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    final user = ref.watch(appUserProvider).valueOrNull;
    final prof = ref.watch(docProvider((col: 'patients', id: fs.uid))).valueOrNull;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            title: Text(user?.name ?? ''),
            subtitle: Text('${user?.email ?? ''}\nRole: ${user?.role ?? 'patient'}'),
            isThreeLine: true,
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Health profile'),
            subtitle: Text(
              prof == null ? 'Not completed' : '${prof.s('bloodGroup')} · ${prof.s('phone')} · private to you',
            ),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              final v = await showFormSheet(context, 'Health profile', _patientFields, initial: prof?.d ?? const {});
              if (v != null && context.mounted)
                await act(context, () => fs.set('patients', fs.uid, {...v, 'ownerId': fs.uid}), ok: 'Saved.');
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Text('Join as a provider', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        for (final k in kProviderKinds.values)
          ListTile(
            dense: true,
            leading: const Icon(Icons.badge_outlined),
            title: Text('Apply as ${k.title}'),
            onTap: () => context.push('/apply/${k.key}'),
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('বাংলা / English'),
          trailing: Switch(
            value: ref.watch(localeProvider) == 'bn',
            onChanged: (v) => ref.read(localeProvider.notifier).state = v ? 'bn' : 'en',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy & Data'),
          onTap: () => showDialog(
            context: context,
            builder: (_) => const AlertDialog(
              content: SingleChildScrollView(
                child: Text(
                  'Your health data is stored in your private account. Only you can read it. Doctors see a record only if you share it with them, and you can change that anytime.\n\n'
                  'Analytics and crash reports never include medical details, only anonymous events and your user id.\n\n'
                  'Retention: records are kept while your account is active. Delete your account and your data is removed by an administrator within 30 days.',
                ),
              ),
            ),
          ),
        ),
        if (user?.deactivated ?? false)
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Reactivate account'),
            onTap: () => act(context, () => fs.update('users', fs.uid, {'deactivated': false})),
          ),
        ListTile(
          leading: const Icon(Icons.pause_circle_outline),
          title: const Text('Deactivate account'),
          onTap: () async {
            if (await confirm(context, 'Deactivate your account? You can reactivate by signing in again.') &&
                context.mounted) {
              await act(context, () => fs.update('users', fs.uid, {'deactivated': true}));
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('Delete account'),
          onTap: () async {
            if (await confirm(context, 'Request permanent deletion of your account and data?') && context.mounted) {
              final ok = await act(context, () async {
                await fs.update('users', fs.uid, {'deletionRequested': true});
                await FirebaseAuth.instance.currentUser!.delete();
              });
              if (!ok && context.mounted) snack(context, 'If asked, sign in again and retry.');
            }
          },
        ),
        if (kDebugMode)
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Test Crashlytics crash (debug only)'),
            onTap: () => FirebaseCrashlytics.instance.crash(),
          ),
        const SizedBox(height: 8),
        FilledButton(onPressed: () => ref.read(authControllerProvider.notifier).logout(), child: const Text('Log out')),
      ],
    );
  }
}
