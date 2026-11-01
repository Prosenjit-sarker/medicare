import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firestore_service.dart';

void _report(Object e, StackTrace s) {
  if (!kIsWeb) FirebaseCrashlytics.instance.recordError(e, s);
}

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

/// Runs a Firebase action with error handling, Crashlytics (non-fatal) and user feedback.
Future<bool> act(
  BuildContext c,
  Future<void> Function() fn, {
  String? ok,
}) async {
  try {
    await fn();
    if (ok != null && c.mounted) snack(c, ok);
    return true;
  } on FirebaseException catch (e, s) {
    final denied = e.code == 'permission-denied';
    if (!denied) _report(e, s);
    if (c.mounted) {
      snack(
        c,
        denied
            ? 'You are not allowed to do this.'
            : 'Action failed. Please try again.',
      );
    }
  } catch (e, s) {
    _report(e, s);
    if (c.mounted) snack(c, 'Action failed. Please try again.');
  }
  return false;
}

Future<bool> confirm(BuildContext c, String message) async =>
    await showDialog<bool>(
      context: c,
      builder: (_) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    ) ??
    false;

DateTime _ts(Doc d) =>
    d.t('createdAt') ?? DateTime.fromMillisecondsSinceEpoch(0);

/// Loading / error / empty / list states for any query.
class DocList extends ConsumerWidget {
  const DocList({
    super.key,
    required this.q,
    required this.builder,
    this.empty = 'Nothing here yet.',
    this.filter,
    this.shrink = false,
  });
  final Q q;
  final Widget Function(BuildContext, Doc) builder;
  final String empty;
  final bool Function(Doc)? filter;
  final bool shrink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(docsProvider(q))
        .when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (_, _) => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Could not load. Check your connection.'),
            ),
          ),
          data: (all) {
            final list = (filter == null ? all : all.where(filter!).toList())
              ..sort((a, b) => _ts(b).compareTo(_ts(a)));
            if (list.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(empty),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: shrink,
              physics: shrink ? const NeverScrollableScrollPhysics() : null,
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (c, i) => builder(c, list[i]),
            );
          },
        );
  }
}

class DocCard extends StatelessWidget {
  const DocCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.actions = const [],
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            leading: leading,
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: subtitle == null ? null : Text(subtitle!),
            trailing: trailing,
            onTap: onTap,
          ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 8, runSpacing: 4, children: actions),
              ),
            ),
        ],
      ),
    );
  }
}

class DoctorAvatar extends StatelessWidget {
  const DoctorAvatar({super.key, required this.imageUrl, this.size = 56});

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: url.isEmpty
            ? _placeholder(context)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(context),
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Icon(
      Icons.person_outline,
      size: size * .58,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final good = [
      'verified',
      'published',
      'delivered',
      'completed',
      'paid',
      'confirmed',
      'approved',
      'fulfilled',
    ].contains(status);
    final bad = ['rejected', 'cancelled', 'refunded'].contains(status);
    final c = good
        ? const Color(0xFF0F766E)
        : bad
        ? const Color(0xFFB91C1C)
        : const Color(0xFF92400E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

Widget searchBox(void Function(String) onChanged, {String hint = 'Search'}) =>
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: hint,
        ),
        onChanged: onChanged,
      ),
    );
