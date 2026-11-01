import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';

class CartLine {
  const CartLine(this.med, this.qty);
  final Doc med;
  final int qty;
}

class CartState {
  const CartState({this.pharmacyId, this.lines = const {}});
  final String? pharmacyId;
  final Map<String, CartLine> lines;
  int get count => lines.values.fold(0, (s, l) => s + l.qty);
  bool get needsRx => lines.values.any((l) => l.med.b('rx'));
}

/// One cart = one pharmacy. Adding from another pharmacy starts a new cart.
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void add(Doc med) {
    final base = (state.pharmacyId != null && state.pharmacyId != med.s('pharmacyId')) ? const CartState() : state;
    final lines = Map<String, CartLine>.of(base.lines);
    final cur = lines[med.id]?.qty ?? 0;
    if (cur >= 20) return;
    lines[med.id] = CartLine(med, cur + 1);
    state = CartState(pharmacyId: med.s('pharmacyId'), lines: lines);
  }

  void decrement(String id) {
    final lines = Map<String, CartLine>.of(state.lines);
    final cur = lines[id];
    if (cur == null) return;
    cur.qty <= 1 ? lines.remove(id) : lines[id] = CartLine(cur.med, cur.qty - 1);
    state = CartState(pharmacyId: lines.isEmpty ? null : state.pharmacyId, lines: lines);
  }

  void clear() => state = const CartState();
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
