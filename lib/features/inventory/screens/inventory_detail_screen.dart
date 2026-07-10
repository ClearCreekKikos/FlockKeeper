// lib/features/inventory/screens/inventory_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/inventory_item_model.dart';
import '../../../data/models/inventory_usage_model.dart';
import '../../../shared/providers/providers.dart';
import '../providers/inventory_providers.dart';
import 'add_edit_inventory_screen.dart';

class InventoryDetailScreen extends ConsumerStatefulWidget {
  final int itemId;
  const InventoryDetailScreen({super.key, required this.itemId});

  @override
  ConsumerState<InventoryDetailScreen> createState() =>
      _InventoryDetailScreenState();
}

class _InventoryDetailScreenState
    extends ConsumerState<InventoryDetailScreen> {
  InventoryItem? _item;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    final repo = ref.read(inventoryRepositoryProvider);
    final item = await repo.getItemById(widget.itemId);
    if (mounted) setState(() { _item = item; _loading = false; });
  }

  Future<void> _adjustQuantity(double delta) async {
    final repo = ref.read(inventoryRepositoryProvider);
    await repo.adjustQuantity(widget.itemId, delta);
    ref.invalidate(inventoryUsageHistoryProvider(widget.itemId));
    ref.invalidate(inventoryItemsProvider);
    ref.invalidate(lowStockItemsProvider);
    await _loadItem();
  }

  Future<void> _showLogUsageDialog() async {
    final qtyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Usage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Quantity Used',
                suffixText: _item?.unit ?? '',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final qty = double.tryParse(qtyCtrl.text);
      if (qty != null && qty > 0) {
        final repo = ref.read(inventoryRepositoryProvider);
        await repo.logUsage(InventoryUsage(
          inventoryItemId: widget.itemId,
          quantityUsed: qty,
          usageDate: DateTime.now(),
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        ));
        ref.invalidate(inventoryUsageHistoryProvider(widget.itemId));
        ref.invalidate(inventoryItemsProvider);
        ref.invalidate(lowStockItemsProvider);
        await _loadItem();
      }
    }
  }

  Future<void> _showAddStockDialog() async {
    final qtyCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Stock'),
        content: TextField(
          controller: qtyCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Quantity to Add',
            suffixText: _item?.unit ?? '',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final qty = double.tryParse(qtyCtrl.text);
      if (qty != null && qty > 0) {
        await _adjustQuantity(qty);
      }
    }
  }

  Future<void> _deleteItem() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${_item?.name}"?\n\nThis will also delete all usage history for this item.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.deleteItem(widget.itemId);
      ref.invalidate(inventoryItemsProvider);
      ref.invalidate(lowStockItemsProvider);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Supply Detail')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final item = _item;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Supply Detail')),
        body: const Center(child: Text('Item not found.')),
      );
    }


    final usageAsync = ref.watch(inventoryUsageHistoryProvider(widget.itemId));
    final qtyColor = item.isOutOfStock
        ? Colors.red
        : item.isLowStock
            ? Colors.orange.shade700
            : Colors.green.shade700;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditInventoryScreen(existingItem: item),
                ),
              );
              await _loadItem();
              ref.invalidate(inventoryItemsProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: _deleteItem,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Quantity Card ──────────────────────────────────────────────
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '${item.currentQuantity % 1 == 0 ? item.currentQuantity.toInt() : item.currentQuantity}',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: qtyColor,
                    ),
                  ),
                  Text(
                    item.unit,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  if (!item.isActive)
                    _StatusBadge(label: 'INACTIVE / UNSTOCKED', color: Colors.grey)
                  else if (item.isOutOfStock)
                    _StatusBadge(label: 'OUT OF STOCK', color: Colors.red)
                  else if (item.isLowStock)
                    _StatusBadge(label: 'LOW STOCK', color: Colors.orange.shade700)
                  else
                    _StatusBadge(label: 'IN STOCK', color: Colors.green.shade700),
                  const SizedBox(height: 12),
                  Text(
                    'Min: ${item.minimumQuantity % 1 == 0 ? item.minimumQuantity.toInt() : item.minimumQuantity} ${item.unit}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 16),
                  // Quick adjust buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AdjustButton(label: '-1', onTap: () => _adjustQuantity(-1)),
                      const SizedBox(width: 8),
                      _AdjustButton(label: '+1', onTap: () => _adjustQuantity(1)),
                      const SizedBox(width: 8),
                      _AdjustButton(label: '+5', onTap: () => _adjustQuantity(5)),
                      const SizedBox(width: 8),
                      _AdjustButton(label: '+10', onTap: () => _adjustQuantity(10)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showLogUsageDialog,
                          icon: const Icon(Icons.remove_circle_outline, size: 18),
                          label: const Text('Log Usage'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _showAddStockDialog,
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Add Stock'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Info Card ─────────────────────────────────────────────────
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow('Category', InventoryItem.categoryLabel(item.category)),
                  _InfoRow('Cost per Unit', '\$${item.costPerUnit.toStringAsFixed(2)}'),
                  _InfoRow('Total Value', '\$${item.totalValue.toStringAsFixed(2)}'),
                  if (item.supplierName != null)
                    _InfoRow('Supplier', item.supplierName!),
                  if (item.expirationDate != null)
                    _InfoRow(
                      'Expires',
                      DateFormat.yMMMd().format(item.expirationDate!),
                      valueColor: item.isExpired
                          ? Colors.red
                          : item.isExpiringSoon()
                              ? Colors.orange.shade700
                              : null,
                    ),
                  if (item.barcode != null)
                    _InfoRow('Barcode', item.barcode!),
                  if (item.notes != null && item.notes!.isNotEmpty)
                    _InfoRow('Notes', item.notes!),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Active / In Stock'),
                    subtitle: const Text('Turn off to make this item inactive (unstocked), which hides it from alerts and active lists.'),
                    value: item.isActive,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (bool value) async {
                      final repo = ref.read(inventoryRepositoryProvider);
                      final updated = item.copyWith(isActive: value);
                      await repo.updateItem(updated);
                      ref.invalidate(inventoryItemsProvider);
                      ref.invalidate(lowStockItemsProvider);
                      ref.invalidate(expiringItemsProvider);
                      await _loadItem();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Usage History ─────────────────────────────────────────────
          Text(
            'Usage History',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          usageAsync.when(
            data: (usages) {
              if (usages.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No usage recorded yet.',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: usages.take(20).map((u) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.red.shade50,
                        child: Icon(Icons.remove, size: 16, color: Colors.red.shade700),
                      ),
                      title: Text(
                        '-${u.quantityUsed % 1 == 0 ? u.quantityUsed.toInt() : u.quantityUsed} ${item.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade700,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat.yMMMd().add_jm().format(u.usageDate),
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: u.notes != null
                          ? Tooltip(
                              message: u.notes!,
                              child: const Icon(Icons.notes, size: 16),
                            )
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ─────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AdjustButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
