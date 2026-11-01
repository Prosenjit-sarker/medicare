import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';

const _types = {
  'bp': 'Blood pressure (mmHg)', 'glucose': 'Blood glucose (mmol/L)', 'weight': 'Weight (kg)', 'height': 'Height (cm)',
  'hr': 'Heart rate (bpm)', 'temp': 'Temperature (°C)',
};

class TrackerPage extends ConsumerStatefulWidget {
  const TrackerPage({super.key});

  @override
  ConsumerState<TrackerPage> createState() => _State();
}

class _State extends ConsumerState<TrackerPage> {
  String _type = 'bp';

  @override
  Widget build(BuildContext context) {
    final fs = ref.read(fsProvider);
    final all = ref.watch(docsProvider(q('health_entries', f1: 'userId', v1: fs.uid, order: 'ts', limit: 300))).valueOrNull ?? [];
    final list = all.where((e) => e.s('type') == _type).toList();
    final values = list.reversed.map((e) => e.n('value').toDouble()).toList();
    num? latest(String t) {
      final m = all.where((e) => e.s('type') == t);
      return m.isEmpty ? null : m.first.n('value');
    }

    final b = bmi(latest('weight'), latest('height'));
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'tracker'))),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () async {
          final isBp = _type == 'bp';
          final v = await showFormSheet(context, _types[_type]!, [
            FieldSpec('value', isBp ? 'Systolic' : 'Value', kind: FK.number),
            if (isBp) const FieldSpec('value2', 'Diastolic', kind: FK.number),
            const FieldSpec('source', 'Source', kind: FK.choice, options: ['manual', 'device'], initial: 'manual'),
          ]);
          if (v == null || !context.mounted) return;
          await act(context, () => fs.db.collection('health_entries').add({...v, 'type': _type, 'userId': fs.uid, 'ts': FirestoreService.now}), ok: 'Saved.');
        },
      ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Wrap(spacing: 6, children: [for (final e in _types.entries) ChoiceChip(label: Text(e.value.split(' (').first), selected: _type == e.key, onSelected: (_) => setState(() => _type = e.key))]),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: SizedBox(height: 160, child: values.length < 2 ? const Center(child: Text('Add two or more readings to see a chart.')) : CustomPaint(size: Size.infinite, painter: _LinePainter(values))))),
        if (b != null) Card(child: ListTile(title: Text('BMI ${b.toStringAsFixed(1)}'), subtitle: const Text('Calculated from your latest weight and height. For tracking only, not a diagnosis.'))),
        for (final e in list.take(30))
          ListTile(
            title: Text(_type == 'bp' ? '${e.n('value')}/${e.n('value2')}' : '${e.n('value')}'),
            subtitle: Text('${e.t('ts')?.toString().substring(0, 16) ?? ''} · ${e.s('source')}'),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => act(context, () => fs.delete('health_entries', e.id))),
          ),
        const SizedBox(height: 70),
        const Text('Manual entries are marked "manual", device readings "device". Values are for personal tracking, not diagnosis.', style: TextStyle(fontSize: 12)),
      ]),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.v);
  final List<double> v;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = v.reduce((a, b) => a < b ? a : b), hi = v.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo) == 0 ? 1 : hi - lo;
    final path = Path();
    final dot = Paint()..color = const Color(0xFF0F766E);
    for (var i = 0; i < v.length; i++) {
      final p = Offset(size.width * i / (v.length - 1), size.height - (v[i] - lo) / span * (size.height - 16) - 8);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      canvas.drawCircle(p, 3, dot);
    }
    canvas.drawPath(path, Paint()..color = const Color(0xFF0B5CAD)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_LinePainter o) => o.v != v;
}
