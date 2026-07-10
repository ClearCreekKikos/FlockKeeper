// lib/features/inventory/screens/low_stock_alerts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/inventory_item_model.dart';
import '../../../shared/providers/providers.dart';
import '../providers/inventory_providers.dart';
import 'inventory_detail_screen.dart';

class LowStockAlertsScreen extends ConsumerWidget {
  const LowStockAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStockAsync = ref.watch(lowStockItemsProvider);
    final expiringAsync = ref.watch(expiringItemsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Alerts'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Low Stock'),
              Tab(text: 'Expiring'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ─── Low Stock Tab ───────────────────────────────────────────
            _buildItemList(
              context,
              ref,
              lowStockAsync,
              emptyMessage: 'All supplies are stocked! 🎉',
              badgeBuilder: (item) => _LowStockBadge(item: item),
            ),

            // ─── Expiring Tab ────────────────────────────────────────────
            _buildItemList(
              context,
              ref,
              expiringAsync,
              emptyMessage: 'No items expiring soon. ✅',
              badgeBuilder: (item) => _ExpiringBadge(item: item),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<InventoryItem>> asyncItems, {
    required String emptyMessage,
    required Widget Function(InventoryItem) badgeBuilder,
  }) {
    return asyncItems.when(
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                const SizedBox(height: 12),
                Text(emptyMessage, style: const TextStyle(fontSize: 16)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(lowStockItemsProvider);
            ref.invalidate(expiringItemsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: item.isOutOfStock
                        ? Colors.red.shade50
                        : Colors.orange.shade50,
                    child: Icon(
                      item.isOutOfStock
                          ? Icons.error_outline
                          : Icons.warning_amber_rounded,
                      color: item.isOutOfStock ? Colors.red : Colors.orange.shade700,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        InventoryItem.categoryLabel(item.category),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      badgeBuilder(item),
                    ],
                  ),
                  trailing: FilledButton.tonal(
                    onPressed: () async {
                      // Quick restock: add stock via dialog
                      final qtyCtrl = TextEditingController();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Restock ${item.name}'),
                          content: TextField(
                            controller: qtyCtrl,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Quantity to Add',
                              suffixText: item.unit,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Restock'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        final qty = double.tryParse(qtyCtrl.text);
                        if (qty != null && qty > 0) {
                          await ref
                              .read(inventoryRepositoryProvider)
                              .adjustQuantity(item.id!, qty);
                          ref.invalidate(inventoryItemsProvider);
                          ref.invalidate(lowStockItemsProvider);
                          ref.invalidate(expiringItemsProvider);
                        }
                      }
                    },
                    child: const Text('Restock', style: TextStyle(fontSize: 12)),
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InventoryDetailScreen(itemId: item.id!),
                      ),
                    );
                    ref.invalidate(inventoryItemsProvider);
                    ref.invalidate(lowStockItemsProvider);
                    ref.invalidate(expiringItemsProvider);
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _LowStockBadge extends StatelessWidget {
  final InventoryItem item;
  const _LowStockBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    final qty = item.currentQuantity;
    final min = item.minimumQuantity;
    final fmtQty = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
    final fmtMin = min % 1 == 0 ? min.toInt().toString() : min.toString();
    final color = item.isOutOfStock ? Colors.red : Colors.orange.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        item.isOutOfStock
            ? 'OUT OF STOCK (min $fmtMin ${item.unit})'
            : '$fmtQty / $fmtMin ${item.unit}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _ExpiringBadge extends StatelessWidget {
  final InventoryItem item;
  const _ExpiringBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.expirationDate == null) return const SizedBox.shrink();
    final daysLeft = item.expirationDate!.difference(DateTime.now()).inDays;
    final color = item.isExpired ? Colors.red : Colors.orange.shade700;
    final text = item.isExpired
        ? 'EXPIRED ${DateFormat.yMMMd().format(item.expirationDate!)}'
        : 'Expires in $daysLeft days (${DateFormat.yMMMd().format(item.expirationDate!)})';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
