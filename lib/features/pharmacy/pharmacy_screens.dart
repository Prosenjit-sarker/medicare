import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicare_bd/core/core.dart';
import 'package:medicare_bd/core/services/supabase_storage_service.dart';
import 'package:medicare_bd/features/providers/provider_kinds.dart';

import 'cart.dart';

class PharmaciesPage extends ConsumerStatefulWidget {
  const PharmaciesPage({super.key});

  @override
  ConsumerState<PharmaciesPage> createState() => _State();
}

class _State extends ConsumerState<PharmaciesPage> {
  String _t = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'pharmacy')),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrdersPage()),
            ),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: ref.watch(cartProvider).count > 0,
              label: Text('${ref.watch(cartProvider).count}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartPage()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          searchBox(
            (v) => setState(() => _t = v.toLowerCase()),
            hint: 'Pharmacy, district, area',
          ),
          Expanded(
            child: DocList(
              q: q('pharmacies', f1: 'status', v1: 'verified', limit: 60),
              empty: 'No verified pharmacies yet.',
              filter: (p) => '${p.s('name')} ${p.s('district')} ${p.s('area')}'
                  .toLowerCase()
                  .contains(_t),
              builder: (c, p) => DocCard(
                title: p.s('name'),
                subtitle: '${p.s('area')}, ${p.s('district')}',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  c,
                  MaterialPageRoute(builder: (_) => PharmacyShopPage(p)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PharmacyShopPage extends ConsumerStatefulWidget {
  const PharmacyShopPage(this.pharmacy, {super.key});
  final Doc pharmacy;

  @override
  ConsumerState<PharmacyShopPage> createState() => _ShopState();
}

class _ShopState extends ConsumerState<PharmacyShopPage> {
  String _t = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pharmacy.s('name')),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartPage()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          searchBox(
            (v) => setState(() => _t = v.toLowerCase()),
            hint: 'Brand, generic name, category',
          ),
          Expanded(
            child: DocList(
              q: q(
                'medicines',
                f1: 'pharmacyId',
                v1: widget.pharmacy.id,
                limit: 150,
              ),
              empty: 'No medicines listed.',
              filter: (m) =>
                  '${m.s('name')} ${m.s('generic')} ${m.s('category')}'
                      .toLowerCase()
                      .contains(_t),
              builder: (c, m) => DocCard(
                leading: m.s('imageUrl').isEmpty
                    ? null
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          m.s('imageUrl'),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.square(
                            dimension: 56,
                            child: Icon(Icons.medication_outlined),
                          ),
                        ),
                      ),
                title: '${m.s('name')}${m.b('rx') ? '  (Rx)' : ''}',
                subtitle:
                    '${m.s('generic')} · ${m.s('manufacturer')} · ${m.s('category')}\n৳${m.n('price')} · ${m.n('stock') > 0 ? 'In stock' : 'Out of stock'}${m.b('rx') ? '\nPrescription required: pharmacist will review.' : ''}',
                trailing: IconButton(
                  icon: const Icon(Icons.add_shopping_cart),
                  onPressed: m.n('stock') > 0
                      ? () => ref.read(cartProvider.notifier).add(m)
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final fs = ref.read(fsProvider);
    final total = cart.lines.values.fold<num>(
      0,
      (s, l) => s + l.med.n('price') * l.qty,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: cart.lines.isEmpty
          ? const Center(child: Text('Your cart is empty.'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final l in cart.lines.values)
                  DocCard(
                    title: l.med.s('name'),
                    subtitle: '৳${l.med.n('price')} × ${l.qty}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => ref
                              .read(cartProvider.notifier)
                              .decrement(l.med.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () =>
                              ref.read(cartProvider.notifier).add(l.med),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Estimated total: ৳$total (the pharmacy confirms the final amount)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (cart.needsRx)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Your cart has prescription-only medicines. The pharmacist must review your prescription before confirming.',
                      style: TextStyle(color: Color(0xFF92400E)),
                    ),
                  ),
                FilledButton(
                  onPressed: () async {
                    final rx = await fs.db
                        .collection('prescriptions')
                        .where('patientId', isEqualTo: fs.uid)
                        .limit(5)
                        .get();
                    final latest = rx.docs.isEmpty ? null : rx.docs.first;
                    final summary = latest == null
                        ? ''
                        : 'Dr. ${latest['doctorName']}: ${(latest['medicines'] as List).map((m) => (m as Map)['name']).join(', ')}';
                    if (!context.mounted) return;
                    final v = await showFormSheet(context, 'Delivery details', [
                      const FieldSpec(
                        'address',
                        'Delivery address',
                        kind: FK.multiline,
                      ),
                      const FieldSpec('phone', 'Phone'),
                      if (cart.needsRx)
                        FieldSpec(
                          'rxSummary',
                          'Prescription details (doctor and medicines)',
                          kind: FK.multiline,
                          initial: summary,
                        ),
                    ]);
                    if (v == null || !context.mounted) return;
                    final ok = await act(
                      context,
                      () => fs.add('medicine_orders', {
                        'patientId': fs.uid,
                        'pharmacyId': cart.pharmacyId,
                        'items': [
                          for (final l in cart.lines.values)
                            {
                              'id': l.med.id,
                              'name': l.med.s('name'),
                              'qty': l.qty,
                              'rx': l.med.b('rx'),
                            },
                        ],
                        'rxRequired': cart.needsRx,
                        'rxSummary': v['rxSummary'] ?? '',
                        'address': v['address'],
                        'phone': v['phone'],
                        'status': 'placed',
                        'paymentStatus': 'cash_on_delivery',
                      }),
                      ok: 'Order placed.',
                    );
                    if (ok) ref.read(cartProvider.notifier).clear();
                  },
                  child: const Text('Place order (cash on delivery)'),
                ),
              ],
            ),
    );
  }
}

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'orders'))),
      body: DocList(
        q: q('medicine_orders', f1: 'patientId', v1: fs.uid),
        empty: 'No orders yet.',
        builder: (c, o) => DocCard(
          title: o
              .l('items')
              .map((i) => '${(i as Map)['name']} ×${i['qty']}')
              .join(', '),
          subtitle:
              'Total: ${o.n('total') == 0 ? 'pending confirmation' : '৳${o.n('total')}'} · ${o.s('paymentStatus')}',
          trailing: StatusChip(o.s('status')),
          actions: [
            if (o.s('status') == 'placed')
              ActionChip(
                label: const Text('Cancel'),
                onPressed: () => act(
                  c,
                  () => fs.update('medicine_orders', o.id, {
                    'status': 'cancelled',
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PharmacyDashboard extends ConsumerWidget {
  const PharmacyDashboard({super.key});

  static const _cats = [
    'Tablet',
    'Capsule',
    'Syrup',
    'Injection',
    'Ointment',
    'Drops',
    'Device',
    'Other',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fs = ref.read(fsProvider);
    final fields = [
      const FieldSpec('name', 'Brand name'),
      const FieldSpec('generic', 'Generic name'),
      const FieldSpec('manufacturer', 'Manufacturer'),
      const FieldSpec('category', 'Category', kind: FK.choice, options: _cats),
      const FieldSpec('price', 'Price (BDT)', kind: FK.number),
      const FieldSpec('stock', 'Stock quantity', kind: FK.number),
      const FieldSpec('rx', 'Prescription only', kind: FK.flag),
    ];
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pharmacy dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Catalog'),
              Tab(text: 'Orders'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ProviderProfileCard(kProviderKinds['pharmacy']!),
            Scaffold(
              floatingActionButton: FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text('Medicine'),
                onPressed: () async {
                  final v = await showFormSheet(
                    context,
                    'New medicine',
                    fields,
                  );
                  if (v == null || !context.mounted) return;
                  final selected = await _chooseCatalogImage(context);
                  if (!context.mounted) return;
                  Uint8List? bytes;
                  if (selected != null) {
                    bytes = await selected.readAsBytes();
                    if (!context.mounted) return;
                    if (bytes.length >
                        SupabaseStorageService.maxDoctorAvatarBytes) {
                      snack(context, 'Choose an image smaller than 5 MB.');
                      return;
                    }
                  }
                  final me = await fs.get('pharmacies', fs.uid);
                  if (!context.mounted) return;
                  await act(context, () async {
                    String? imagePath;
                    try {
                      final image = selected != null && bytes != null
                          ? await SupabaseStorageService.instance
                                .uploadCatalogImage(
                                  ownerUid: fs.uid,
                                  fileName: selected.name,
                                  bytes: bytes,
                                  contentType: SupabaseStorageService.instance
                                      .contentTypeFor(selected.name),
                                )
                          : null;
                      imagePath = image?.path;
                      await fs.add('medicines', {
                        ...v,
                        if (image != null) 'imageUrl': image.url,
                        if (image != null) 'imagePath': image.path,
                        'pharmacyId': fs.uid,
                        'pharmacyName': me?.s('name') ?? '',
                      });
                    } catch (_) {
                      if (imagePath != null) {
                        try {
                          await SupabaseStorageService.instance
                              .deleteCatalogImage(imagePath);
                        } catch (_) {}
                      }
                      rethrow;
                    }
                  }, ok: 'Added.');
                },
              ),
              body: DocList(
                q: q('medicines', f1: 'pharmacyId', v1: fs.uid, limit: 200),
                empty: 'Your catalog is empty.',
                builder: (c, m) => DocCard(
                  leading: m.s('imageUrl').isEmpty
                      ? null
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            m.s('imageUrl'),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.square(
                              dimension: 56,
                              child: Icon(Icons.medication_outlined),
                            ),
                          ),
                        ),
                  title: '${m.s('name')}${m.b('rx') ? ' (Rx)' : ''}',
                  subtitle:
                      '${m.s('generic')} · ৳${m.n('price')} · stock ${m.n('stock')}',
                  onTap: () async {
                    final v = await showFormSheet(
                      c,
                      'Edit medicine',
                      fields,
                      initial: m.d,
                    );
                    if (v == null || !c.mounted) return;
                    final selected = await _chooseCatalogImage(c);
                    if (!c.mounted) return;
                    Uint8List? bytes;
                    if (selected != null) {
                      bytes = await selected.readAsBytes();
                      if (!c.mounted) return;
                      if (bytes.length >
                          SupabaseStorageService.maxDoctorAvatarBytes) {
                        snack(c, 'Choose an image smaller than 5 MB.');
                        return;
                      }
                    }
                    await act(c, () async {
                      String? imagePath;
                      try {
                        final image = selected != null && bytes != null
                            ? await SupabaseStorageService.instance
                                  .uploadCatalogImage(
                                    ownerUid: fs.uid,
                                    fileName: selected.name,
                                    bytes: bytes,
                                    contentType: SupabaseStorageService.instance
                                        .contentTypeFor(selected.name),
                                  )
                            : null;
                        imagePath = image?.path;
                        await fs.update('medicines', m.id, {
                          ...v,
                          if (image != null) 'imageUrl': image.url,
                          if (image != null) 'imagePath': image.path,
                        });
                      } catch (_) {
                        if (imagePath != null) {
                          try {
                            await SupabaseStorageService.instance
                                .deleteCatalogImage(imagePath);
                          } catch (_) {}
                        }
                        rethrow;
                      }
                    }, ok: 'Saved.');
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => act(c, () => fs.delete('medicines', m.id)),
                  ),
                ),
              ),
            ),
            DocList(
              q: q('medicine_orders', f1: 'pharmacyId', v1: fs.uid, limit: 100),
              empty: 'No orders yet.',
              builder: (c, o) => DocCard(
                title: o
                    .l('items')
                    .map((i) => '${(i as Map)['name']} ×${i['qty']}')
                    .join(', '),
                subtitle:
                    '${o.s('address')} · ${o.s('phone')}${o.b('rxRequired') ? '\nRx review: ${o.s('rxSummary')}' : ''}\nTotal: ${o.n('total') == 0 ? 'not set' : '৳${o.n('total')}'}',
                trailing: StatusChip(o.s('status')),
                actions: [
                  if (o.s('status') == 'placed') ...[
                    ActionChip(
                      label: const Text('Confirm + set total'),
                      onPressed: () async {
                        final v = await showFormSheet(c, 'Final amount', const [
                          FieldSpec('total', 'Total (BDT)', kind: FK.number),
                        ]);
                        if (v != null && c.mounted) {
                          await act(
                            c,
                            () => fs.update('medicine_orders', o.id, {
                              'status': 'confirmed',
                              'total': v['total'],
                            }),
                          );
                        }
                      },
                    ),
                    ActionChip(
                      label: const Text('Reject'),
                      onPressed: () => act(
                        c,
                        () => fs.update('medicine_orders', o.id, {
                          'status': 'rejected',
                        }),
                      ),
                    ),
                  ],
                  if (o.s('status') == 'confirmed')
                    ActionChip(
                      label: const Text('Out for delivery'),
                      onPressed: () => act(
                        c,
                        () => fs.update('medicine_orders', o.id, {
                          'status': 'out_for_delivery',
                        }),
                      ),
                    ),
                  if (o.s('status') == 'out_for_delivery')
                    ActionChip(
                      label: const Text('Delivered'),
                      onPressed: () => act(
                        c,
                        () => fs.update('medicine_orders', o.id, {
                          'status': 'delivered',
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<PlatformFile?> _chooseCatalogImage(BuildContext context) async {
  final chooseImage = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add a product image?'),
      content: const Text('Choose an optional image, up to 5 MB.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Skip'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.image_outlined),
          label: const Text('Choose image'),
        ),
      ],
    ),
  );
  if (chooseImage != true) return null;
  final files = await FilePicker.pickFiles(type: FileType.image);
  return files.singleOrNull;
}
