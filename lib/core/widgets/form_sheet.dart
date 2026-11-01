import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum FK { text, number, multiline, choice, multi, flag, date }

class FieldSpec {
  const FieldSpec(this.key, this.label, {this.kind = FK.text, this.options = const [], this.required = true, this.initial});
  final String key;
  final String label;
  final FK kind;
  final List<String> options;
  final bool required;
  final Object? initial;
}

/// Validated form in a bottom sheet. Returns the values, or null if dismissed.
Future<Map<String, dynamic>?> showFormSheet(BuildContext context, String title, List<FieldSpec> fields, {Map<String, dynamic> initial = const {}}) =>
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FormSheet(title, fields, initial),
    );

class _FormSheet extends StatefulWidget {
  const _FormSheet(this.title, this.fields, this.initial);
  final String title;
  final List<FieldSpec> fields;
  final Map<String, dynamic> initial;

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  final _key = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{};
  final _v = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final init = widget.initial[f.key] ?? f.initial;
      switch (f.kind) {
        case FK.choice:
          _v[f.key] = f.options.contains(init?.toString()) ? init.toString() : null;
        case FK.multi:
          _v[f.key] = List<String>.from((init as List?) ?? const []);
        case FK.flag:
          _v[f.key] = init == true;
        default:
          _c[f.key] = TextEditingController(text: init?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_key.currentState!.validate()) return;
    final out = <String, dynamic>{};
    for (final f in widget.fields) {
      switch (f.kind) {
        case FK.choice:
          if (_v[f.key] != null) out[f.key] = _v[f.key];
        case FK.multi || FK.flag:
          out[f.key] = _v[f.key];
        case FK.number:
          final t = _c[f.key]!.text.trim();
          if (t.isNotEmpty) out[f.key] = num.parse(t);
        default:
          final t = _c[f.key]!.text.trim();
          if (t.isNotEmpty) out[f.key] = t;
      }
    }
    Navigator.pop(context, out);
  }

  Future<void> _pickDate(FieldSpec f) async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1920), lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (d != null) _c[f.key]!.text = DateFormat('yyyy-MM-dd').format(d);
  }

  Widget _field(FieldSpec f) {
    String? req(String? v) => f.required && (v ?? '').trim().isEmpty ? 'Required' : null;
    switch (f.kind) {
      case FK.choice:
        return DropdownButtonFormField<String>(
          initialValue: _v[f.key] as String?,
          isExpanded: true,
          decoration: InputDecoration(labelText: f.label),
          items: [for (final o in f.options) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (x) => setState(() => _v[f.key] = x),
          validator: (x) => f.required && x == null ? 'Required' : null,
        );
      case FK.multi:
        return FormField<List<String>>(
          initialValue: _v[f.key] as List<String>,
          validator: (x) => f.required && (x == null || x.isEmpty) ? 'Select at least one' : null,
          builder: (st) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            Wrap(spacing: 6, children: [
              for (final o in f.options)
                FilterChip(
                  label: Text(o),
                  selected: (st.value ?? []).contains(o),
                  onSelected: (on) {
                    final l = List<String>.from(st.value ?? []);
                    on ? l.add(o) : l.remove(o);
                    _v[f.key] = l;
                    st.didChange(l);
                  },
                ),
            ]),
            if (st.hasError) Text(st.errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ]),
        );
      case FK.flag:
        return SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(f.label), value: _v[f.key] as bool, onChanged: (x) => setState(() => _v[f.key] = x));
      case FK.date:
        return TextFormField(
          controller: _c[f.key],
          readOnly: true,
          decoration: InputDecoration(labelText: f.label, suffixIcon: const Icon(Icons.calendar_today)),
          onTap: () => _pickDate(f),
          validator: req,
        );
      case FK.number:
        return TextFormField(
          controller: _c[f.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: f.label),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return f.required ? 'Required' : null;
            return num.tryParse(t) == null ? 'Enter a number' : null;
          },
        );
      default:
        return TextFormField(
          controller: _c[f.key],
          maxLines: f.kind == FK.multiline ? 4 : 1,
          decoration: InputDecoration(labelText: f.label),
          validator: req,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.all(20), shrinkWrap: true, children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          for (final f in widget.fields) Padding(padding: const EdgeInsets.only(bottom: 12), child: _field(f)),
          FilledButton(onPressed: _submit, child: const Text('Save')),
        ]),
      ),
    );
  }
}
