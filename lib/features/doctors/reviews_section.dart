import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';

/// Ratings for a doctor or hospital. One review per patient per target (document id).
class ReviewsSection extends ConsumerWidget {
  const ReviewsSection({super.key, required this.targetId, required this.targetType, this.canReview = true});
  final String targetId;
  final String targetType;
  final bool canReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    final list = ref.watch(docsProvider(q('reviews', f1: 'targetId', v1: targetId, limit: 50))).valueOrNull ?? [];
    final avg = list.isEmpty ? 0.0 : list.map((e) => e.n('rating')).reduce((a, b) => a + b) / list.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.star, color: Color(0xFFF59E0B)),
        Text(list.isEmpty ? ' No reviews yet' : ' ${avg.toStringAsFixed(1)} (${list.length})', style: const TextStyle(fontWeight: FontWeight.w700)),
        const Spacer(),
        if (canReview)
          TextButton(
            onPressed: () async {
              final v = await showFormSheet(context, 'Write a review', const [
                FieldSpec('rating', 'Rating', kind: FK.choice, options: ['5', '4', '3', '2', '1']),
                FieldSpec('comment', 'Comment', kind: FK.multiline, required: false),
              ]);
              if (v == null || !context.mounted) return;
              await act(context, () => fs.set('reviews', '${targetId}_${fs.uid}', {
                    'targetId': targetId, 'targetType': targetType, 'patientId': fs.uid,
                    'rating': int.parse(v['rating'] as String), 'comment': v['comment'] ?? '',
                  }), ok: 'Thanks for your review.');
            },
            child: const Text('Review'),
          ),
      ]),
      for (final r in list.take(5)) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('${'★' * r.n('rating').toInt()}  ${r.s('comment')}')),
    ]);
  }
}
