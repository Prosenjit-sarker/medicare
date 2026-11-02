import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';

class ArticlesPage extends ConsumerStatefulWidget {
  const ArticlesPage({super.key});

  @override
  ConsumerState<ArticlesPage> createState() => _State();
}

class _State extends ConsumerState<ArticlesPage> {
  String _t = '';
  String? _cat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'articles'))),
      body: Column(
        children: [
          searchBox((v) => setState(() => _t = v.toLowerCase()), hint: 'Search articles'),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final c in [
                  'General',
                  'Heart',
                  'Diabetes',
                  'Child health',
                  'Women health',
                  'Nutrition',
                  'Mental health',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _cat == c,
                      onSelected: (s) => setState(() => _cat = s ? c : null),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: DocList(
              q: q('health_articles', f1: 'status', v1: 'published', limit: 60),
              empty: 'No articles yet.',
              filter: (a) =>
                  (_cat == null || a.s('category') == _cat) &&
                  '${a.s('title')} ${a.s('body')}'.toLowerCase().contains(_t),
              builder: (c, a) => DocCard(
                title: a.s('title'),
                subtitle: '${a.s('category')} · Dr. ${a.s('authorName')}${a.b('featured') ? ' · Featured' : ''}',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ArticleDetailPage(a))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ArticleDetailPage extends StatelessWidget {
  const ArticleDetailPage(this.a, {super.key});
  final Doc a;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(a.s('category'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (a.s('imageUrl').isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(a.s('imageUrl'), errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
          const SizedBox(height: 12),
          Text(a.s('title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text('By Dr. ${a.s('authorName')} · professionally reviewed', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          Text(a.s('body'), style: const TextStyle(height: 1.5)),
          const SizedBox(height: 16),
          const Text('General information only. Talk to a doctor for medical advice.', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
