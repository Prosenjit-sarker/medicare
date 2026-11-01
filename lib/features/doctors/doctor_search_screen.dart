import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medicare_bd/core/core.dart';

class DoctorSearchPage extends ConsumerStatefulWidget {
  const DoctorSearchPage({super.key});

  @override
  ConsumerState<DoctorSearchPage> createState() => _State();
}

class _State extends ConsumerState<DoctorSearchPage> {
  String _text = '';
  int _maxFee = 0;
  String? _day;
  int _minExp = 0;

  bool _match(Doc d) {
    final t = _text.toLowerCase().trim();
    final hay =
        '${d.s('name')} ${d.s('specialty')} ${d.s('qualifications')} ${d.s('hospital')}'
            .toLowerCase();
    if (t.isNotEmpty && !hay.contains(t)) {
      return false;
    }
    if (_maxFee > 0 && d.n('fee') > _maxFee) {
      return false;
    }
    if (_minExp > 0 && d.n('experience') < _minExp) {
      return false;
    }
    if (_day != null && d.l('days').isNotEmpty && !d.l('days').contains(_day)) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'doctors'))),
      body: Column(
        children: [
          searchBox(
            (v) => setState(() => _text = v),
            hint: 'Name, specialty, qualification, hospital',
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final f in [0, 500, 1000])
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 8),
                    child: ChoiceChip(
                      label: Text(f == 0 ? 'Any fee' : '≤ ৳$f'),
                      selected: _maxFee == f,
                      onSelected: (_) => setState(() => _maxFee = f),
                    ),
                  ),
                for (final e in [0, 5, 10])
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 8),
                    child: ChoiceChip(
                      label: Text(e == 0 ? 'Any experience' : '$e+ yrs'),
                      selected: _minExp == e,
                      onSelected: (_) => setState(() => _minExp = e),
                    ),
                  ),
                for (final d in kWeekdays)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 8),
                    child: ChoiceChip(
                      label: Text(d),
                      selected: _day == d,
                      onSelected: (s) => setState(() => _day = s ? d : null),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: DocList(
              q: q('doctors', f1: 'status', v1: 'verified', limit: 60),
              empty: 'No verified doctors found.',
              filter: _match,
              builder: (c, d) => DocCard(
                leading: DoctorAvatar(imageUrl: d.s('imageUrl')),
                title: d.s('name'),
                subtitle:
                    '${d.s('specialty')} · ${d.s('qualifications')}\n${d.s('hospital')} · ${d.n('experience')} yrs · BMDC ${d.s('bmdc')}',
                trailing: Text(
                  '৳${d.n('fee')}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: () => c.push('/book/${d.id}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
